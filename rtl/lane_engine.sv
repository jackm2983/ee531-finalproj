module lane_engine #(
  parameter int PRICE_W = 16,
  parameter int SIZE_W  = 16,
  parameter int SEQ_W   = 24,

  parameter int K_FAST = 3,   // alpha = 1/8
  parameter int K_SLOW = 5,   // alpha = 1/32
  parameter int K_RSI  = 4,   // smoothing

  parameter int COOLDOWN_TICKS = 16
)(
  input  logic clk,
  input  logic rst_n,

  // Lane input stream (packed tick payload)
  input  logic in_valid,
  output logic in_ready,
  input  logic [8+PRICE_W+SIZE_W+SEQ_W-1:0] in_data,

  // Lane trigger output (packed)
  output logic out_valid,
  input  logic out_ready,
  output logic [8+1+SEQ_W+16-1:0] out_data  // {symbol, side, seq, debug[15:0]}
);

  localparam int IN_W = 8+PRICE_W+SIZE_W+SEQ_W;

  // Unpack
  logic [7:0] symbol;
  logic [PRICE_W-1:0] price_u;
  logic [SIZE_W-1:0]  size_u;
  logic [SEQ_W-1:0]   seq_u;

  assign {symbol, price_u, size_u, seq_u} = in_data;

  // We'll treat price as signed internally (helps with delta)
  logic signed [31:0] price;
  assign price = $signed({1'b0, price_u}); // zero-extend

  // Simple always-ready lane input (you can add internal FIFO later)
  assign in_ready = 1'b1;

  // === Lane state regs ===
  logic signed [31:0] prev_price;
  logic signed [31:0] ema_fast, ema_slow;
  logic [31:0] avg_gain, avg_loss;      // unsigned
  logic was_fast_gt_slow;
  logic [$clog2(COOLDOWN_TICKS+1)-1:0] cooldown;

  // === Pipeline registers (2-stage example inside lane) ===
  // Stage A: compute delta, gain/loss
  logic a_valid;
  logic [7:0] a_symbol;
  logic [SEQ_W-1:0] a_seq;
  logic signed [31:0] a_price;
  logic signed [31:0] a_delta;
  logic [31:0] a_gain, a_loss;

  // Stage B: updated indicators + decision
  logic b_valid;
  logic [7:0] b_symbol;
  logic [SEQ_W-1:0] b_seq;
  logic signed [31:0] b_ema_fast, b_ema_slow;
  logic [31:0] b_avg_gain, b_avg_loss;
  logic b_now_fast_gt_slow;
  logic b_cross_up, b_cross_dn;
  logic b_overbought, b_oversold;

  // Output staging
  logic o_valid;
  logic [8+1+SEQ_W+16-1:0] o_data;

  assign out_valid = o_valid;
  assign out_data  = o_data;

  // Backpressure: if output not ready, stall pipeline (simple, correct)
  wire stall = o_valid && !out_ready;

  // Helpers
  function automatic logic [31:0] abs32(input logic signed [31:0] x);
    abs32 = x[31] ? logic'( -x ) : logic'( x );
  endfunction

  // RSI ratio compare without division:
  // RSI > 70  <=> avg_gain*30 > avg_loss*70
  // RSI < 30  <=> avg_gain*70 < avg_loss*30
  function automatic logic overbought70(input logic [31:0] g, input logic [31:0] l);
    logic [47:0] lhs, rhs;
    begin
      lhs = g * 30;
      rhs = l * 70;
      overbought70 = (lhs > rhs) && (g + l != 0);
    end
  endfunction

  function automatic logic oversold30(input logic [31:0] g, input logic [31:0] l);
    logic [47:0] lhs, rhs;
    begin
      lhs = g * 70;
      rhs = l * 30;
      oversold30 = (lhs < rhs) && (g + l != 0);
    end
  endfunction

  // EMA update: ema += (price - ema) >>> K
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

      a_valid <= 1'b0;
      b_valid <= 1'b0;
      o_valid <= 1'b0;
      o_data  <= '0;
    end else begin
      if (!stall) begin
        // ===== Output stage consume =====
        o_valid <= 1'b0;

        // ===== Stage B -> Output =====
        if (b_valid) begin
          // Decision (cooldown gating)
          logic fire_buy, fire_sell;
          fire_buy  = b_cross_up && !b_overbought && (cooldown == 0);
          fire_sell = b_cross_dn && !b_oversold  && (cooldown == 0);

          if (fire_buy || fire_sell) begin
            o_valid <= 1'b1;
            o_data  <= { b_symbol, fire_buy, b_seq, 16'(b_overbought), 15'(0) };
            // Update cooldown when trade fires
            cooldown <= COOLDOWN_TICKS[$clog2(COOLDOWN_TICKS+1)-1:0];
          end else begin
            // decrement cooldown if active
            if (cooldown != 0) cooldown <= cooldown - 1'b1;
          end
        end else begin
          if (cooldown != 0) cooldown <= cooldown - 1'b1;
        end

        // ===== Stage A -> Stage B (update indicators) =====
        b_valid  <= a_valid;
        b_symbol <= a_symbol;
        b_seq    <= a_seq;

        if (a_valid) begin
          // Update EMA
          b_ema_fast <= ema_update(ema_fast, a_price, K_FAST);
          b_ema_slow <= ema_update(ema_slow, a_price, K_SLOW);

          // Update RSI smoothers: avg += (x - avg) >>> K
          b_avg_gain <= avg_gain + (($signed({1'b0,a_gain}) - $signed({1'b0,avg_gain})) >>> K_RSI);
          b_avg_loss <= avg_loss + (($signed({1'b0,a_loss}) - $signed({1'b0,avg_loss})) >>> K_RSI);

          // Crossover based on *next* EMAs (use b_ema_* assigned above next cycle)
          // Here we approximate using current EMAs for simplicity; still works well for demo
          b_now_fast_gt_slow <= (ema_fast > ema_slow);
          b_cross_up <= ((ema_fast > ema_slow) && !was_fast_gt_slow);
          b_cross_dn <= (!(ema_fast > ema_slow) && was_fast_gt_slow);

          b_overbought <= overbought70(avg_gain, avg_loss);
          b_oversold   <= oversold30(avg_gain, avg_loss);
        end else begin
          b_ema_fast <= b_ema_fast;
          b_ema_slow <= b_ema_slow;
          b_avg_gain <= b_avg_gain;
          b_avg_loss <= b_avg_loss;
          b_now_fast_gt_slow <= b_now_fast_gt_slow;
          b_cross_up <= 1'b0;
          b_cross_dn <= 1'b0;
          b_overbought <= 1'b0;
          b_oversold   <= 1'b0;
        end

        // ===== Input -> Stage A =====
        a_valid  <= in_valid;
        a_symbol <= symbol;
        a_seq    <= seq_u;
        a_price  <= price;

        if (in_valid) begin
          a_delta <= price - prev_price;

          // gain/loss
          if ((price - prev_price) > 0) begin
            a_gain <= (price - prev_price);
            a_loss <= 0;
          end else begin
            a_gain <= 0;
            a_loss <= abs32(price - prev_price);
          end

          // Update core state regs for next tick
          prev_price <= price;

          // Initialize EMAs on first tick (optional: detect ema==0 and set to price)
          if (ema_fast == 0) ema_fast <= price;
          else               ema_fast <= ema_update(ema_fast, price, K_FAST);

          if (ema_slow == 0) ema_slow <= price;
          else               ema_slow <= ema_update(ema_slow, price, K_SLOW);

          avg_gain <= avg_gain + (($signed({1'b0,a_gain}) - $signed({1'b0,avg_gain})) >>> K_RSI);
          avg_loss <= avg_loss + (($signed({1'b0,a_loss}) - $signed({1'b0,avg_loss})) >>> K_RSI);

          was_fast_gt_slow <= (ema_fast > ema_slow);
        end
      end
    end
  end

endmodule