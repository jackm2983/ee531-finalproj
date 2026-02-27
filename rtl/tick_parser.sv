module tick_parser #(
  parameter int PRICE_W = 16,
  parameter int SIZE_W  = 16,
  parameter int SEQ_W   = 24
)(
  input  logic        clk,
  input  logic        rst_n,

  input  logic        in_valid,
  output logic        in_ready,
  input  logic [63:0] in_data,

  output logic        out_valid,
  input  logic        out_ready,
  output logic [7:0]  out_symbol,
  output logic [PRICE_W-1:0] out_price,
  output logic [SIZE_W-1:0]  out_size,
  output logic [SEQ_W-1:0]   out_seq
);

  logic hold_valid;

  // 1-deep register slice
  assign in_ready  = (~hold_valid) || out_ready;
  assign out_valid = hold_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hold_valid <= 1'b0;
      out_symbol <= '0;
      out_price  <= '0;
      out_size   <= '0;
      out_seq    <= '0;
    end else begin
      if (out_valid && out_ready)
        hold_valid <= 1'b0;

      if (in_valid && in_ready) begin
        hold_valid <= 1'b1;
        out_symbol <= in_data[63:56];
        out_price  <= in_data[55:40];
        out_size   <= in_data[39:24];
        out_seq    <= in_data[23:0];
      end
    end
  end

endmodule