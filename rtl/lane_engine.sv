// lane_engine.sv
module lane_engine #(
  parameter int PRICE_W = 16,
  parameter int SIZE_W  = 16,
  parameter int SEQ_W   = 24,

  parameter int K_FAST = 3,
  parameter int K_SLOW = 5,
  parameter int K_RSI  = 4,

  parameter int COOLDOWN_TICKS = 16
)(
  input  logic clk,
  input  logic rst_n,

  input  logic in_valid,
  output logic in_ready,
  input  logic [8+PRICE_W+SIZE_W+SEQ_W-1:0] in_data,

  output logic out_valid,
  input  logic out_ready,
  output logic [8+1+SEQ_W+16-1:0] out_data
);

  localparam int OUT_W = 8 + 1 + SEQ_W + 16;

  logic [7:0] symbol;
  logic [PRICE_W-1:0] price_u;
  logic [SIZE_W-1:0]  size_u;
  logic [SEQ_W-1:0]   seq_u;
  assign {symbol, price_u, size_u, seq_u} = in_data;

  logic signed [31:0] price_s;
  assign price_s = $signed({{(32-PRICE_W){1'b0}}, price_u});

  logic hold_out;
  logic [OUT_W-1:0] hold_out_data;
  assign out_valid = hold_out;
  assign out_data  = hold_out_data;

  assign in_ready = (~hold_out) || out_ready;

  logic signed [31:0] prev_price;
  logic signed [31:0] ema_fast, ema_slow;
  logic [31:0] avg_gain, avg_loss;
  logic was_fast_gt_slow;

  localparam int CD_W = (COOLDOWN_TICKS < 2) ? 1 : $clog2(COOLDOWN_TICKS+1);
  logic [CD_W-1:0] cooldown;
  localparam logic [CD_W-1:0] COOLDOWN_INIT = CD_W'(COOLDOWN_TICKS);

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
    logic signed [31:0] y;
    begin
      y = (x < 0) ? -x : x;
      abs32 = y[31:0];
    end
  endfunction

  function automatic logic is_overbought70(input logic [31:0] g, input logic [31:0] l);
    logic [47:0] lhs, rhs;
    begin
      if ((g + l) == 0) is_overbought70 = 1'b0;
      else begin
        lhs = g * 48'd30;
        rhs = l * 48'd70;
        is_overbought70 = (lhs > rhs);
      end
    end
  endfunction

  function automatic logic is_oversold30(input logic [31:0] g, input logic [31:0] l);
    logic [47:0] lhs, rhs;
    begin
      if ((g + l) == 0) is_oversold30 = 1'b0;
      else begin
        lhs = g * 48'd70;
        rhs = l * 48'd30;
        is_oversold30 = (lhs < rhs);
      end
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_price <= 32'sd0;
      ema_fast   <= 32'sd0;
      ema_slow   <= 32'sd0;
      avg_gain   <= 32'd0;
      avg_loss   <= 32'd0;
      was_fast_gt_slow <= 1'b0;
      cooldown   <= '0;

      hold_out <= 1'b0;
      hold_out_data <= '0;
    end else begin
      if (hold_out && out_ready)
        hold_out <= 1'b0;

      if (in_valid && in_ready) begin
        logic signed [31:0] delta;
        logic [31:0] gain, loss;

        logic signed [31:0] next_ema_fast, next_ema_slow;
        logic [31:0] next_avg_gain, next_avg_loss;

        logic now_fast_gt_slow;
        logic cross_up, cross_dn;
        logic overbought, oversold;
        logic fire_buy, fire_sell;

        logic signed [32:0] tmp_gain, tmp_loss;

        delta = price_s - prev_price;

        if (delta > 0) begin
          gain = delta[31:0];
          loss = 32'd0;
        end else begin
          gain = 32'd0;
          loss = abs32(delta);
        end

        if (ema_fast == 0) next_ema_fast = price_s;
        else               next_ema_fast = ema_update(ema_fast, price_s, K_FAST);

        if (ema_slow == 0) next_ema_slow = price_s;
        else               next_ema_slow = ema_update(ema_slow, price_s, K_SLOW);

        tmp_gain = $signed({1'b0, avg_gain}) +
                   (($signed({1'b0, gain}) - $signed({1'b0, avg_gain})) >>> K_RSI);
        tmp_loss = $signed({1'b0, avg_loss}) +
                   (($signed({1'b0, loss}) - $signed({1'b0, avg_loss})) >>> K_RSI);
        next_avg_gain = tmp_gain[31:0];
        next_avg_loss = tmp_loss[31:0];

        now_fast_gt_slow = (next_ema_fast > next_ema_slow);
        cross_up = ( now_fast_gt_slow && !was_fast_gt_slow);
        cross_dn = (!now_fast_gt_slow &&  was_fast_gt_slow);

        overbought = is_overbought70(next_avg_gain, next_avg_loss);
        oversold   = is_oversold30(next_avg_gain, next_avg_loss);

        if (cooldown != 0)
          cooldown <= cooldown - 1'b1;

        fire_buy  = cross_up && !overbought && (cooldown == 0);
        fire_sell = cross_dn && !oversold   && (cooldown == 0);

        if (fire_buy || fire_sell) begin
          hold_out <= 1'b1;
          hold_out_data <= {symbol, fire_buy, seq_u, 8'(overbought), 8'(oversold)};
          cooldown <= COOLDOWN_INIT;
        end

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