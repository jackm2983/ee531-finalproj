module trigger_arbiter #(
  parameter int LANES  = 4,
  parameter int OUT_W  = 8+1+24+16
)(
  input  logic clk,
  input  logic rst_n,

  input  logic [LANES-1:0] in_valid,
  output logic [LANES-1:0] in_ready,
  input  logic [LANES-1:0][OUT_W-1:0] in_data,

  output logic out_valid,
  input  logic out_ready,
  output logic [OUT_W-1:0] out_data
);

  integer i;
  logic found;
  logic [$clog2(LANES)-1:0] sel;

  always_comb begin
    found = 1'b0;
    sel   = '0;

    for (i=0; i<LANES; i++) begin
      if (!found && in_valid[i]) begin
        found = 1'b1;
        sel   = i[$clog2(LANES)-1:0];
      end
    end

    out_valid = found;
    out_data  = found ? in_data[sel] : '0;

    for (i=0; i<LANES; i++) in_ready[i] = 1'b0;
    if (found) in_ready[sel] = out_ready;
  end

endmodule