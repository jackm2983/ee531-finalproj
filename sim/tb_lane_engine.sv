`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2026 01:23:15 AM
// Design Name: 
// Module Name: tb_lane_engine
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps

module tb_lane_engine;

  // === Match lane_engine parameters ===
  parameter int PRICE_W = 16;
  parameter int SIZE_W  = 16;
  parameter int SEQ_W   = 24;

  parameter int K_FAST = 3;
  parameter int K_SLOW = 5;
  parameter int K_RSI  = 4;

  parameter int COOLDOWN_TICKS = 4; // smaller so it's easier to see behavior

  localparam int IN_W  = 8 + PRICE_W + SIZE_W + SEQ_W;
  localparam int OUT_W = 8 + 1 + SEQ_W + 16;

  // === Signals ===
  logic clk;
  logic rst_n;

  logic in_valid;
  logic in_ready;
  logic [IN_W-1:0] in_data;

  logic out_valid;
  logic out_ready;
  logic [OUT_W-1:0] out_data;

  // === Instantiate DUT ===
  lane_engine #(
    .PRICE_W(PRICE_W),
    .SIZE_W(SIZE_W),
    .SEQ_W(SEQ_W),
    .K_FAST(K_FAST),
    .K_SLOW(K_SLOW),
    .K_RSI(K_RSI),
    .COOLDOWN_TICKS(COOLDOWN_TICKS)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .in_data(in_data),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_data(out_data)
  );

  // === Clock 10ns period ===
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // === Print trigger when it transfers ===
  always @(posedge clk) begin
    if (rst_n && out_valid && out_ready) begin
      // out_data = {symbol, side, seq, debug[15:0]}
      $display("T=%0t TRIG sym=%0h side=%0d seq=%0d debug=0x%0h",
               $time,
               out_data[OUT_W-1 -: 8],      // symbol
               out_data[OUT_W-9],           // side bit (1=BUY)
               out_data[SEQ_W+16-1 -: SEQ_W], // seq (middle)
               out_data[15:0]);             // debug
    end
  end

  initial begin
    // init
    rst_n = 0;
    in_valid = 0;
    in_data  = '0;
    out_ready = 1;

    // reset
    #20;
    rst_n = 1;

    // We will send ticks for symbol 0x02.
    // in_data format: {symbol, price, size, seq}
    //
    // Price pattern: big drop then gradual rise to encourage EMA crossover.
    // seq increments each tick.

    // Tick 1: price=1000
    #10;
    if (in_ready) begin
      in_data  = {8'h02, 16'd1000, 16'd1, 24'd1};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Tick 2: price=200 (big loss)
    #20;
    if (in_ready) begin
      in_data  = {8'h02, 16'd200, 16'd1, 24'd2};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Tick 3: price=400
    #20;
    if (in_ready) begin
      in_data  = {8'h02, 16'd400, 16'd1, 24'd3};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Tick 4: price=800
    #20;
    if (in_ready) begin
      in_data  = {8'h02, 16'd800, 16'd1, 24'd4};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Tick 5: price=1200
    #20;
    if (in_ready) begin
      in_data  = {8'h02, 16'd1200, 16'd1, 24'd5};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Tick 6: price=1600
    #20;
    if (in_ready) begin
      in_data  = {8'h02, 16'd1600, 16'd1, 24'd6};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Tick 7: price=2200 (push upward)
    #20;
    if (in_ready) begin
      in_data  = {8'h02, 16'd2200, 16'd1, 24'd7};
      in_valid = 1;
    end
    #10; in_valid = 0;

    // Optional: stall output for a bit (to see hold behavior)
    // If a trigger happens around here, it will be held.
    #20;
    out_ready = 0;
    #40;
    out_ready = 1;

    // Let simulation run
    #200;
    $display("DONE");
    $finish;
  end

endmodule
