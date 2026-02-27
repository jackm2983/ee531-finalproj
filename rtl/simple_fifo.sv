module simple_fifo #(
  parameter int W = 64
) (
  input  logic         clk,
  input  logic         rst_n,

  input  logic         in_valid,
  output logic         in_ready,
  input  logic [W-1:0] in_data,

  output logic         out_valid,
  input  logic         out_ready,
  output logic [W-1:0] out_data
);

  logic [W-1:0] mem0, mem1;
  logic v0, v1;

  assign out_valid = v0;
  assign out_data  = mem0;

  // not full
  assign in_ready = ~v1;

  wire push = in_valid && in_ready;
  wire pop  = out_valid && out_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v0 <= 1'b0; v1 <= 1'b0;
      mem0 <= '0; mem1 <= '0;
    end else begin
      unique case ({push, pop})
        2'b10: begin // push only
          if (!v0) begin mem0 <= in_data; v0 <= 1'b1; end
          else      begin mem1 <= in_data; v1 <= 1'b1; end
        end
        2'b01: begin // pop only
          if (v1) begin mem0 <= mem1; v0 <= 1'b1; v1 <= 1'b0; end
          else    begin v0 <= 1'b0; end
        end
        2'b11: begin // push and pop
          if (v1) begin
            mem0 <= mem1; v0 <= 1'b1;
            mem1 <= in_data; v1 <= 1'b1;
          end else begin
            mem0 <= in_data; v0 <= 1'b1;
            v1 <= 1'b0;
          end
        end
        default: ; // nothing
      endcase
    end
  end

endmodule