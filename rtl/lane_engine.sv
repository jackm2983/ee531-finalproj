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
  assign price_s = $signed({16'b0, price_u});

  logic hold_out;
  logic [OUT_W-1:0] hold_out_data;
  assign out_valid = hold_out;
  assign out_data  = hold_out_data;

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
    begin
      abs32 = x[31] ? (~x + 1) : x;
    end
  endfunction

  function automatic logic is_overbought70(input logic [31:0] g, input logic [31:0] l);
    logic [34:0] three_g;
    logic [34:0] seven_l;
    begin
      if ((g + l) == 0) is_overbought70 = 1'b0;
      else begin
        three_g = {3'b0, (g << 1)} + {3'b0, g};
        seven_l = {3'b0, (l << 2)} + {3'b0, (l << 1)} + {3'b0, l};
        is_overbought70 = (three_g > seven_l);
      end
    end
  endfunction

  function automatic logic is_oversold30(input logic [31:0] g, input logic [31:0] l);
    logic [34:0] seven_g;
    logic [34:0] three_l;
    begin
      if ((g + l) == 0) is_oversold30 = 1'b0;
      else begin
        seven_g = {3'b0, (g << 2)} + {3'b0, (g << 1)} + {3'b0, g};
        three_l = {3'b0, (l << 1)} + {3'b0, l};
        is_oversold30 = (seven_g < three_l);
      end
    end
  endfunction

  // Stage 1: Delta and gain/loss calculation
  logic s1_valid;
  logic [7:0] s1_symbol;
  logic [SEQ_W-1:0] s1_seq;
  logic signed [31:0] s1_delta;
  logic [31:0] s1_gain, s1_loss;

  // Stage 2: EMA update (intermediate pipeline stage)
  logic s2_valid;
  logic [7:0] s2_symbol;
  logic [SEQ_W-1:0] s2_seq;
  logic signed [31:0] s2_ema_fast, s2_ema_slow;
  logic [31:0] s2_avg_gain, s2_avg_loss;
  logic s2_was_fast_gt_slow;

  // Stage 3: Overbought/oversold and crossover detection
  logic s3_valid;
  logic [7:0] s3_symbol;
  logic [SEQ_W-1:0] s3_seq;
  logic s3_overbought, s3_oversold;
  logic s3_fire_buy, s3_fire_sell;

  assign in_ready = ~s1_valid;

  always_ff @(posedge clk) begin
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

      s1_valid <= 1'b0;
      s1_symbol <= 8'd0;
      s1_seq <= '0;
      s1_delta <= 32'sd0;
      s1_gain <= 32'd0;
      s1_loss <= 32'd0;

      s2_valid <= 1'b0;
      s2_symbol <= 8'd0;
      s2_seq <= '0;
      s2_ema_fast <= 32'sd0;
      s2_ema_slow <= 32'sd0;
      s2_avg_gain <= 32'd0;
      s2_avg_loss <= 32'd0;
      s2_was_fast_gt_slow <= 1'b0;

      s3_valid <= 1'b0;
      s3_symbol <= 8'd0;
      s3_seq <= '0;
      s3_overbought <= 1'b0;
      s3_oversold <= 1'b0;
      s3_fire_buy <= 1'b0;
      s3_fire_sell <= 1'b0;
    end else begin
      if (hold_out && out_ready)
        hold_out <= 1'b0;

      // Input -> Stage 1
      if (in_valid && in_ready) begin
        logic signed [31:0] delta;
        logic [31:0] gain, loss;

        delta = price_s - prev_price;

        if (delta > 0) begin
          gain = delta[31:0];
          loss = 32'd0;
        end else begin
          gain = 32'd0;
          loss = abs32(delta);
        end

        prev_price <= price_s;

        s1_valid <= 1'b1;
        s1_symbol <= symbol;
        s1_seq <= seq_u;
        s1_delta <= delta;
        s1_gain <= gain;
        s1_loss <= loss;
      end



      // Stage 1 -> Stage 2
      if (s1_valid) begin
        logic signed [31:0] next_ema_fast, next_ema_slow;
        logic [31:0] next_avg_gain, next_avg_loss;
        logic signed [32:0] tmp_gain, tmp_loss;

        if (ema_fast == 0) next_ema_fast = prev_price;
        else               next_ema_fast = ema_update(ema_fast, prev_price, K_FAST);

        if (ema_slow == 0) next_ema_slow = prev_price;
        else               next_ema_slow = ema_update(ema_slow, prev_price, K_SLOW);

        tmp_gain = $signed({1'b0, avg_gain}) +
                   (($signed({1'b0, s1_gain}) - $signed({1'b0, avg_gain})) >>> K_RSI);
        tmp_loss = $signed({1'b0, avg_loss}) +
                   (($signed({1'b0, s1_loss}) - $signed({1'b0, avg_loss})) >>> K_RSI);
        next_avg_gain = tmp_gain[31:0];
        next_avg_loss = tmp_loss[31:0];

        ema_fast   <= next_ema_fast;
        ema_slow   <= next_ema_slow;
        avg_gain   <= next_avg_gain;
        avg_loss   <= next_avg_loss;

        s2_valid <= 1'b1;
        s1_valid <= 1'b0;
        s2_symbol <= s1_symbol;
        s2_seq <= s1_seq;
        s2_ema_fast <= next_ema_fast;
        s2_ema_slow <= next_ema_slow;
        s2_avg_gain <= next_avg_gain;
        s2_avg_loss <= next_avg_loss;
        s2_was_fast_gt_slow <= was_fast_gt_slow;
      end

      // Stage 2 -> Stage 3
      if (s2_valid) begin
        logic now_fast_gt_slow;
        logic cross_up, cross_dn;
        logic overbought, oversold;
        logic cooldown_zero;

        now_fast_gt_slow = (s2_ema_fast > s2_ema_slow);
        cross_up = ( now_fast_gt_slow && !s2_was_fast_gt_slow);
        cross_dn = (!now_fast_gt_slow &&  s2_was_fast_gt_slow);

        overbought = is_overbought70(s2_avg_gain, s2_avg_loss);
        oversold   = is_oversold30(s2_avg_gain, s2_avg_loss);

        cooldown_zero = (cooldown == 0);

        was_fast_gt_slow <= now_fast_gt_slow;

        if (cooldown != 0)
          cooldown <= cooldown - 1'b1;

        s3_valid <= 1'b1;
        s2_valid <= 1'b0;
        s3_symbol <= s2_symbol;
        s3_seq <= s2_seq;
        s3_overbought <= overbought;
        s3_oversold <= oversold;
        s3_fire_buy  <= cross_up && !overbought && cooldown_zero;
        s3_fire_sell <= cross_dn && !oversold   && cooldown_zero;
      end

      // Stage 3 -> Output
      if (s3_valid) begin
        logic out_buf_free;
        out_buf_free = (~hold_out) || out_ready;

        if ((s3_fire_buy || s3_fire_sell) && !out_buf_free) begin
        end else begin
          if (s3_fire_buy || s3_fire_sell) begin
            hold_out <= 1'b1;
            hold_out_data <= {s3_symbol, s3_fire_buy, s3_seq, 8'(s3_overbought), 8'(s3_oversold)};
            cooldown <= COOLDOWN_INIT;
          end
          s3_valid <= 1'b0;
        end
      end

    end
  end

endmodule