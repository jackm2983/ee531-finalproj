// WRAPPER_trader_engine.sv
module WRAPPER_trader_engine #(
  parameter int LANES   = 4,
  parameter int PRICE_W = 16,
  parameter int SIZE_W  = 16,
  parameter int SEQ_W   = 24,

  parameter int K_FAST = 3,
  parameter int K_SLOW = 5,
  parameter int K_RSI  = 4,
  parameter int COOLDOWN_TICKS = 16
)(
  input  logic        clk,
  input  logic        rst_n,

  input  logic        tick_in_valid,
  output logic        tick_in_ready,
  input  logic [63:0] tick_in_data,

  output logic        trig_out_valid,
  input  logic        trig_out_ready,
  output logic [8+1+SEQ_W+16-1:0] trig_out_data
);

  logic p_valid, p_ready;
  logic [7:0] p_symbol;
  logic [PRICE_W-1:0] p_price;
  logic [SIZE_W-1:0]  p_size;
  logic [SEQ_W-1:0]   p_seq;

  tick_parser #(.PRICE_W(PRICE_W), .SIZE_W(SIZE_W), .SEQ_W(SEQ_W)) u_parser (
    .clk(clk), .rst_n(rst_n),
    .in_valid(tick_in_valid),
    .in_ready(tick_in_ready),
    .in_data(tick_in_data),
    .out_valid(p_valid),
    .out_ready(p_ready),
    .out_symbol(p_symbol),
    .out_price(p_price),
    .out_size(p_size),
    .out_seq(p_seq)
  );

  localparam int PAY_W = 8 + PRICE_W + SIZE_W + SEQ_W;
  logic [LANES-1:0] lane_tick_valid, lane_tick_ready;
  logic [LANES-1:0][PAY_W-1:0] lane_tick_data;

  symbol_router #(.LANES(LANES), .PRICE_W(PRICE_W), .SIZE_W(SIZE_W), .SEQ_W(SEQ_W)) u_router (
    .clk(clk), .rst_n(rst_n),
    .in_valid(p_valid),
    .in_ready(p_ready),
    .in_symbol(p_symbol),
    .in_price(p_price),
    .in_size(p_size),
    .in_seq(p_seq),
    .lane_valid(lane_tick_valid),
    .lane_ready(lane_tick_ready),
    .lane_data(lane_tick_data)
  );

  localparam int TRIG_W = 8 + 1 + SEQ_W + 16;
  logic [LANES-1:0] lane_trig_valid, lane_trig_ready;
  logic [LANES-1:0][TRIG_W-1:0] lane_trig_data;

  genvar g;
  generate
    for (g=0; g<LANES; g++) begin : GEN_LANES
      lane_engine #(
        .PRICE_W(PRICE_W), .SIZE_W(SIZE_W), .SEQ_W(SEQ_W),
        .K_FAST(K_FAST), .K_SLOW(K_SLOW), .K_RSI(K_RSI),
        .COOLDOWN_TICKS(COOLDOWN_TICKS)
      ) u_lane (
        .clk(clk), .rst_n(rst_n),
        .in_valid(lane_tick_valid[g]),
        .in_ready(lane_tick_ready[g]),
        .in_data(lane_tick_data[g]),
        .out_valid(lane_trig_valid[g]),
        .out_ready(lane_trig_ready[g]),
        .out_data(lane_trig_data[g])
      );
    end
  endgenerate

  trigger_arbiter #(.LANES(LANES), .OUT_W(TRIG_W)) u_arb (
    .in_valid(lane_trig_valid),
    .in_ready(lane_trig_ready),
    .in_data(lane_trig_data),
    .out_valid(trig_out_valid),
    .out_ready(trig_out_ready),
    .out_data(trig_out_data)
  );

endmodule