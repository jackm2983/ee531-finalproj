module symbol_router #(
  parameter int LANES   = 4,
  parameter int PRICE_W = 16,
  parameter int SIZE_W  = 16,
  parameter int SEQ_W   = 24
)(
  input  logic clk,
  input  logic rst_n,

  input  logic in_valid,
  output logic in_ready,
  input  logic [7:0] in_symbol,
  input  logic [PRICE_W-1:0] in_price,
  input  logic [SIZE_W-1:0]  in_size,
  input  logic [SEQ_W-1:0]   in_seq,

  output logic [LANES-1:0] lane_valid,
  input  logic [LANES-1:0] lane_ready,
  output logic [LANES-1:0][(8+PRICE_W+SIZE_W+SEQ_W)-1:0] lane_data
);

  localparam int PAY_W = 8 + PRICE_W + SIZE_W + SEQ_W;

  localparam int LANE_BITS = (LANES<=2)?1:(LANES<=4)?2:(LANES<=8)?3:(LANES<=16)?4:5;

  logic [PAY_W-1:0] payload;
  logic [LANE_BITS-1:0] lane_idx;

  assign payload  = {in_symbol, in_price, in_size, in_seq};
  assign lane_idx = in_symbol[LANE_BITS-1:0];

  logic [LANES-1:0] fifo_in_valid, fifo_in_ready;

  integer i;
  always_comb begin
    for (i=0; i<LANES; i++) fifo_in_valid[i] = 1'b0;
    fifo_in_valid[lane_idx] = in_valid;
  end

  assign in_ready = fifo_in_ready[lane_idx];

  genvar g;
  generate
    for (g=0; g<LANES; g++) begin : GEN_LANE_FIFOS
      simple_fifo #(.W(PAY_W)) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .in_valid(fifo_in_valid[g]),
        .in_ready(fifo_in_ready[g]),
        .in_data(payload),
        .out_valid(lane_valid[g]),
        .out_ready(lane_ready[g]),
        .out_data(lane_data[g])
      );
    end
  endgenerate

endmodule