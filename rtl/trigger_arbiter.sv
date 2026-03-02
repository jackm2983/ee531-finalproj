// trigger_arbiter.sv
// round robin arbiter to ensure that one lane does not hog all the buys

module trigger_arbiter #(
  parameter int LANES = 4,
  parameter int OUT_W = 8+1+24+16
)(
  input  logic clk,                  // added clk for tracking priority
  input  logic rst_n,                // added reset
  input  logic [LANES-1:0] in_valid,
  output logic [LANES-1:0] in_ready,
  input  logic [LANES-1:0][OUT_W-1:0] in_data,

  output logic out_valid,
  input  logic out_ready,
  output logic [OUT_W-1:0] out_data
);

  localparam int SEL_W = $clog2(LANES);
  logic [SEL_W-1:0] last_winner;
  logic [SEL_W-1:0] sel;
  logic found;

  // determine winner based on last_winner
  always_comb begin
    found = 1'b0;
    sel   = '0;

    // check lanes starting from (last_winner + 1)
    for (int i = 1; i <= LANES; i++) begin
      int idx = (last_winner + i) % LANES;
      if (!found && in_valid[idx]) begin
        found = 1'b1;
        sel   = idx[SEL_W-1:0];
      end
    end

    out_valid = found;
    out_data  = found ? in_data[sel] : '0;

    // backpressure logic
    for (int i = 0; i < LANES; i++) in_ready[i] = 1'b0;
    if (found) in_ready[sel] = out_ready;
  end

  // update priority pointer after successful handshake
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      last_winner <= '0;
    end else if (out_valid && out_ready) begin
      last_winner <= sel;
    end
  end

endmodule