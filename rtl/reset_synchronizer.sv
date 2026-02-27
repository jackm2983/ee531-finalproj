// reset_synchronizer.sv
module reset_synchronizer (
  input  logic clk,
  input  logic async_rst_n,     // Asynchronous reset input
  output logic sync_rst_n       // Synchronized reset output
);

  // Two-stage synchronizer (adds 2 clock cycles of delay)
  logic ff1, ff2;

  // Stage 1: Async reset captures on first clock edge
  always_ff @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n)
      ff1 <= 1'b0;
    else
      ff1 <= 1'b1;
  end

  // Stage 2: Ensures metastability resolution before propagation
  always_ff @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n)
      ff2 <= 1'b0;
    else
      ff2 <= ff1;
  end

  // Output is synchronized reset (active low)
  assign sync_rst_n = ff2;

endmodule
