`timescale 1ns/1ps

module tb_lane_engine;

  localparam int PRICE_W = 16;
  localparam int SIZE_W  = 16;
  localparam int SEQ_W   = 24;
  localparam int IN_W    = 8 + PRICE_W + SIZE_W + SEQ_W;
  localparam int OUT_W   = 8 + 1 + SEQ_W + 16;

  logic clk;
  logic rst_n;

  logic in_valid;
  logic in_ready;
  logic [IN_W-1:0] in_data;

  logic out_valid;
  logic out_ready;
  logic [OUT_W-1:0] out_data;

  lane_engine #(
    .PRICE_W(PRICE_W),
    .SIZE_W (SIZE_W),
    .SEQ_W  (SEQ_W)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (in_valid),
    .in_ready (in_ready),
    .in_data  (in_data),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_data (out_data)
  );

  initial begin 
        $dumpfile("tb_lane_engine.vcd");  
        $dumpvars(0, tb_lane_engine); 
  end

  // clock
  initial clk = 0;
  always #5 clk = ~clk;

  // simple send task
  task send_tick(
    input [7:0] symbol,
    input [PRICE_W-1:0] price,
    input [SIZE_W-1:0]  size,
    input [SEQ_W-1:0]   seq
  );
    begin
      @(posedge clk);
      in_valid = 1'b1;
      in_data  = {symbol, price, size, seq};
      wait (in_ready);
      @(posedge clk);
      in_valid = 1'b0;
    end
  endtask

  initial begin
    rst_n     = 0;
    in_valid  = 0;
    in_data   = '0;
    out_ready = 1;

    repeat (5) @(posedge clk);
    rst_n = 1;

    // force strong downtrend
    for (int i = 0; i < 20; i++) begin
      send_tick(8'h01, 16'(200 - i*5), 16'd10, 24'(i));
    end

    // then strong uptrend to force fast EMA crossover
    for (int i = 0; i < 30; i++) begin
      send_tick(8'h01, 16'(100 + i*8), 16'd10, 24'(20+i));
    end

    repeat (50) @(posedge clk);
    $finish;
  end

initial begin
  #100000;
  $fatal("timeout");
end

endmodule