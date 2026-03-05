// WRAPPER_trade_engine.sv
module WRAPPER_trade_engine #(
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

  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic [63:0] s_axis_tdata,

  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic [8+1+SEQ_W+16-1:0] m_axis_tdata
);

  logic p_valid, p_ready;
  logic [7:0] p_symbol;
  logic [PRICE_W-1:0] p_price;
  logic [SIZE_W-1:0]  p_size;
  logic [SEQ_W-1:0]   p_seq;

  // unused axis signals
  logic s_axis_tlast;   // optional framing
  logic [7:0]  s_axis_tuser; // optional metadata
  assign s_axis_tlast  = 1'b0;    
  assign s_axis_tuser  = 8'h00; 


  tick_parser #(.PRICE_W(PRICE_W), .SIZE_W(SIZE_W), .SEQ_W(SEQ_W)) u_parser (
    .clk(clk), .rst_n(rst_n),
    .in_valid(s_axis_tvalid),
    .in_ready(s_axis_tready),
    .in_data(s_axis_tdata),
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
    .out_valid(m_axis_tvalid),
    .out_ready(m_axis_tready),
    .out_data(m_axis_tdata)
  );

endmodule