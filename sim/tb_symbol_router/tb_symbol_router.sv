// tb_symbol_router.sv

`timescale 1ns/1ps

module tb_symbol_router;

  // ===== Parameters (match DUT) =====
  parameter int LANES   = 4;
  parameter int PRICE_W = 16;
  parameter int SIZE_W  = 16;
  parameter int SEQ_W   = 24;

  localparam int PAY_W  = 8 + PRICE_W + SIZE_W + SEQ_W;

  // ===== Clock / Reset =====
  logic clk;
  logic rst_n;

  // ===== DUT inputs =====
  logic in_valid;
  logic in_ready;
  logic [7:0] in_symbol;
  logic [PRICE_W-1:0] in_price;
  logic [SIZE_W-1:0]  in_size;
  logic [SEQ_W-1:0]   in_seq;

  // ===== DUT outputs =====
  logic [LANES-1:0] lane_valid;
  logic [LANES-1:0] lane_ready;
  logic [LANES-1:0][PAY_W-1:0] lane_data;

  // ===== Instantiate DUT =====
  symbol_router #(
    .LANES(LANES),
    .PRICE_W(PRICE_W),
    .SIZE_W(SIZE_W),
    .SEQ_W(SEQ_W)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .in_symbol(in_symbol),
    .in_price(in_price),
    .in_size(in_size),
    .in_seq(in_seq),
    .lane_valid(lane_valid),
    .lane_ready(lane_ready),
    .lane_data(lane_data)
  );

    initial begin 
        $dumpfile("tb_symbol_router.vcd");  
        $dumpvars(0, tb_symbol_router); 
    end

  // ===== Clock generation (10ns period) =====
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ===== Always ready (simplest) =====
  integer k;
  initial begin
    for (k = 0; k < LANES; k = k + 1)
      lane_ready[k] = 1'b1;
  end

  // ===== Print when any lane outputs a tick =====
  integer i;
  always @(posedge clk) begin
    if (rst_n) begin
      for (i = 0; i < LANES; i = i + 1) begin
        if (lane_valid[i] && lane_ready[i]) begin
          // lane_data format: {symbol, price, size, seq}
          $display("T=%0t  LANE=%0d  sym=%0h  price=%0d  size=%0d  seq=%0d",
                   $time,
                   i,
                   lane_data[i][PAY_W-1 -: 8],                 // symbol
                   lane_data[i][PAY_W-9 -: PRICE_W],           // price
                   lane_data[i][PAY_W-9-PRICE_W -: SIZE_W],    // size
                   lane_data[i][SEQ_W-1:0]                     // seq (lowest bits)
          );
        end
      end
    end
  end

  // ===== Stimulus =====
  initial begin
    // init
    rst_n     = 1'b0;
    in_valid  = 1'b0;
    in_symbol = '0;
    in_price  = '0;
    in_size   = '0;
    in_seq    = '0;

    // reset
    #20;
    rst_n = 1'b1;

    // ---- Tick 1 ---- (symbol 0x01 -> lane_idx = 1 for LANES=4)
    #10;
    in_symbol = 8'h01;
    in_price  = 16'd1000;
    in_size   = 16'd10;
    in_seq    = 24'd1;
    in_valid  = 1'b1;

    #10;
    in_valid = 1'b0;

    // ---- Tick 2 ---- (symbol 0x02 -> lane_idx = 2)
    #20;
    in_symbol = 8'h02;
    in_price  = 16'd2000;
    in_size   = 16'd20;
    in_seq    = 24'd2;
    in_valid  = 1'b1;

    #10;
    in_valid = 1'b0;

    // ---- Tick 3 ---- (symbol 0x07 -> lane_idx = 3 because 0x07[1:0]=3)
    #20;
    in_symbol = 8'h07;
    in_price  = 16'd3000;
    in_size   = 16'd30;
    in_seq    = 24'd3;
    in_valid  = 1'b1;

    #10;
    in_valid = 1'b0;

    // ---- Tick 4 ---- (symbol 0x04 -> lane_idx = 0 because 0x04[1:0]=0)
    #20;
    in_symbol = 8'h04;
    in_price  = 16'd4000;
    in_size   = 16'd40;
    in_seq    = 24'd4;
    in_valid  = 1'b1;

    #10;
    in_valid = 1'b0;

    // let outputs drain
    #100;
    $finish;
  end

endmodule
