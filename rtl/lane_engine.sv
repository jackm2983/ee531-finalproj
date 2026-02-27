module lane_engine #(
  parameter int PRICE_W = 16,
  parameter int SIZE_W  = 16,
  parameter int SEQ_W   = 24,

  parameter int K_FAST = 3,        // alpha = 1/8
  parameter int K_SLOW = 5,        // alpha = 1/32
  parameter int K_RSI  = 4,        // smoothing

  parameter int COOLDOWN_TICKS = 16
)(
  input  logic clk,
  input  logic rst_n,

  // Input stream
  input  logic in_valid,
  output logic in_ready,
  input  logic [8+PRICE_W+SIZE_W+SEQ_W-1:0] in_data,

  // Output trigger stream
  output logic out_valid,
  input  logic out_ready,
  output logic [8+1+SEQ_W+16-1:0] out_data
);

  localparam int IN_W   = 8+PRICE_W+SIZE_W+SEQ_W;
  localparam int OUT_W  = 8+1+SEQ_W+16;

  // Unpack incoming payload
  logic [7:0] symbol;
  logic [PRICE_W-1:0] price_u;
  logic [SIZE_W-1:0]  size_u;
  logic [SEQ_W-1:0]   seq_u;
  assign {symbol, price_u, size_u, seq_u} = in_data;

  // Internal signed price (extend)
  logic signed [31:0] price_s;
  assign price_s = $signed({1'b0, price_u});

  // Output register slice (1-deep)
  logic hold_out;
  logic [OUT_W-1:0] hold_out_data;

  assign out_valid = hold_out;
  assign out_data  = hold_out_data;

  // We can accept a new tick if we are not currently holding an output,
  // OR if downstream will take our held output this cycle.
  // This ensures we never overwrite an output trigger.
  assign in_ready = (~hold_out) || out_ready;

  // === Per-lane state ===
  logic signed [31:0] prev_price;
  logic signed [31:0] ema_fast, ema_slow;
  logic [31:0] avg_gain, avg_loss;
  logic was_fast_gt_slow;

  localparam int CD_W = (COOLDOWN_TICKS < 2) ? 1 : $clog2(COOLDOWN_TICKS+1);
  logic [CD_W-1:0] cooldown;

  // Helpers
  function automatic logic signed [31:0] ema_update(
    input logic signed [31:0] ema,
    input logic signed [31:0] p,
    input int K
  );
    logic signed [31:0] diff;
    begin
      diff = p - ema;
      ema_update = ema + (diff >>> K);
    end
  endfunction

  function automatic logic [31:0] abs32(input logic signed [31:0] x);
    abs32 = x[31] ? logic'(-x) : logic'(x);
  endfunction

  // RSI flags without division:
  // RSI > 70  <=> g*30 > l*70
  // RSI < 30  <=> g*70 < l*30
  function automatic logic is_overbought70(input logic [31:0] g, input logic [31:0] l);
    logic [47:0] lhs, rhs;
    begin
      if ((g + l) == 0) is_overbought70 = 1'b0;
      else begin
        lhs = g * 30;
        rhs = l * 70;
        is_overbought70 = (lhs > rhs);
      end
    end
  endfunction

  function automatic logic is_oversold30(input logic [31:0] g, input logic [31:0] l);
    logic [47:0] lhs, rhs;
    begin
      if ((g + l) == 0) is_oversold30 = 1'b0;
      else begin
        lhs = g * 70;
        rhs = l * 30;
        is_oversold30 = (lhs < rhs);
      end
    end
  endfunction

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_price <= 0;
      ema_fast   <= 0;
      ema_slow   <= 0;
      avg_gain   <= 0;
      avg_loss   <= 0;
      was_fast_gt_slow <= 1'b0;
      cooldown   <= '0;

      hold_out <= 1'b0;
      hold_out_data <= '0;
    end else begin
      // consume output if downstream ready
      if (hold_out && out_ready)
        hold_out <= 1'b0;

      // accept tick when handshake succeeds
      if (in_valid && in_ready) begin
        logic signed [31:0] delta;
        logic [31:0] gain, loss;

        logic signed [31:0] next_ema_fast, next_ema_slow;
        logic [31:0] next_avg_gain, next_avg_loss;

        logic now_fast_gt_slow;
        logic cross_up, cross_dn;
        logic overbought, oversold;

        // compute delta/gain/loss
        delta = price_s - prev_price;
        if (delta > 0) begin
          gain = logic'(delta);
          loss = 0;
        end else begin
          gain = 0;
          loss = abs32(delta);
        end

        // init EMAs on first tick (ema==0 is a simple heuristic)
        if (ema_fast == 0) next_ema_fast = price_s;
        else               next_ema_fast = ema_update(ema_fast, price_s, K_FAST);

        if (ema_slow == 0) next_ema_slow = price_s;
        else               next_ema_slow = ema_update(ema_slow, price_s, K_SLOW);

        // smoother update (EMA-like)
        next_avg_gain = avg_gain + (($signed({1'b0,gain}) - $signed({1'b0,avg_gain})) >>> K_RSI);
        next_avg_loss = avg_loss + (($signed({1'b0,loss}) - $signed({1'b0,avg_loss})) >>> K_RSI);

        // crossover detection based on updated EMAs (more correct than using old ones)
        now_fast_gt_slow = (next_ema_fast > next_ema_slow);
        cross_up = ( now_fast_gt_slow && !was_fast_gt_slow);
        cross_dn = (!now_fast_gt_slow &&  was_fast_gt_slow);

        // RSI flags based on updated smoothers
        overbought = is_overbought70(next_avg_gain, next_avg_loss);
        oversold   = is_oversold30(next_avg_gain, next_avg_loss);

        // cooldown decrement each accepted tick
        if (cooldown != 0)
          cooldown <= cooldown - 1'b1;

        // decision gating
        logic fire_buy, fire_sell;
        fire_buy  = cross_up && !overbought && (cooldown == 0);
        fire_sell = cross_dn && !oversold   && (cooldown == 0);

        // If a trade fires, produce one output trigger (stored in hold_out)
        // Note: in_ready prevents overwriting when hold_out is stuck and out_ready=0.
        if (fire_buy || fire_sell) begin
          hold_out <= 1'b1;
          hold_out_data <= { symbol, fire_buy /*side*/, seq_u,
                             8'(overbought), 8'(oversold) };
          cooldown <= COOLDOWN_TICKS[CD_W-1:0];
        end

        // commit state
        prev_price <= price_s;
        ema_fast   <= next_ema_fast;
        ema_slow   <= next_ema_slow;
        avg_gain   <= next_avg_gain;
        avg_loss   <= next_avg_loss;
        was_fast_gt_slow <= now_fast_gt_slow;
      end
    end
  end

endmodule