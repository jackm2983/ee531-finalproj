// tb_tick_parser.sv
`timescale 1ns/1ps

module tb_tick_parser;

  // params match defaults
  localparam PRICE_W = 16;
  localparam SIZE_W  = 16;
  localparam SEQ_W   = 24;

  logic        clk, rst_n;
  logic        in_valid, in_ready;
  logic [63:0] in_data;
  logic        out_valid, out_ready;
  logic [7:0]  out_symbol;
  logic [PRICE_W-1:0] out_price;
  logic [SIZE_W-1:0]  out_size;
  logic [SEQ_W-1:0]   out_seq;

  int pass_count = 0;
  int fail_count = 0;

  tick_parser #(
    .PRICE_W(PRICE_W),
    .SIZE_W(SIZE_W),
    .SEQ_W(SEQ_W)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(in_valid), .in_ready(in_ready), .in_data(in_data),
    .out_valid(out_valid), .out_ready(out_ready),
    .out_symbol(out_symbol), .out_price(out_price),
    .out_size(out_size), .out_seq(out_seq)
  );

  initial begin 
        $dumpfile("tb_tick_parser.vcd");  
        $dumpvars(0, tb_tick_parser); 
  end

  // 10ns clock
  initial clk = 0;
  always #5 clk = ~clk;

  // check helper task
  task automatic check(
    input string    label,
    input logic [7:0]  exp_sym,
    input logic [15:0] exp_price,
    input logic [15:0] exp_size,
    input logic [23:0] exp_seq
  );
    if (out_symbol === exp_sym && out_price === exp_price &&
        out_size === exp_size && out_seq === exp_seq) begin
      $display("PASS [%s] sym=%02X price=%0d size=%0d seq=%0d",
               label, out_symbol, out_price, out_size, out_seq);
      pass_count++;
    end else begin
      $display("FAIL [%s]", label);
      $display("  expected: sym=%02X price=%0d size=%0d seq=%0d",
               exp_sym, exp_price, exp_size, exp_seq);
      $display("  got:      sym=%02X price=%0d size=%0d seq=%0d",
               out_symbol, out_price, out_size, out_seq);
      fail_count++;
    end
  endtask

  // wait for out_valid
  task automatic wait_output;
    int timeout = 20;
    while (!out_valid && timeout > 0) begin
      @(posedge clk); #1;
      timeout--;
    end
    if (timeout == 0) begin
      $display("FAIL timeout waiting for out_valid");
      fail_count++;
    end
  endtask

  // send one packet
  task automatic send_packet(input logic [63:0] pkt);
    in_data  = pkt;
    in_valid = 1;
    @(posedge clk); #1;
    while (!in_ready) begin
      @(posedge clk); #1;
    end
    in_valid = 0;
  endtask

  initial begin
    // init
    in_valid = 0; in_data = 0; out_ready = 1;
    rst_n = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    rst_n = 1;
    @(posedge clk); #1;

    // check reset state
    if (!out_valid) begin
      $display("PASS [reset] out_valid low after reset");
      pass_count++;
    end else begin
      $display("FAIL [reset] out_valid should be low after reset");
      fail_count++;
    end

    // --- test 1: basic single packet ---
    // pkt: sym=0xAB price=1000 size=50 seq=9999
    send_packet({8'hAB, 16'd1000, 16'd50, 24'd9999});
    wait_output;
    check("basic packet", 8'hAB, 16'd1000, 16'd50, 24'd9999);
    out_ready = 1;
    @(posedge clk); #1;

    // --- test 2: back-to-back packets, out_ready=1 ---
    send_packet({8'h01, 16'd200, 16'd10, 24'd1});
    wait_output;
    check("back-to-back pkt1", 8'h01, 16'd200, 16'd10, 24'd1);
    send_packet({8'h02, 16'd300, 16'd20, 24'd2});
    wait_output;
    check("back-to-back pkt2", 8'h02, 16'd300, 16'd20, 24'd2);
    @(posedge clk); #1;

    // --- test 3: backpressure - send while out_ready=1, then stall consumer ---
    // first fill the output register
    send_packet({8'hFF, 16'd500, 16'd99, 24'd777});
    wait_output;
    // now stall consumer and verify state holds
    out_ready = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (out_valid) begin
      $display("PASS [backpressure] out_valid held with out_ready=0");
      pass_count++;
    end else begin
      $display("FAIL [backpressure] expected out_valid=1");
      fail_count++;
    end
    if (!in_ready) begin
      $display("PASS [backpressure] in_ready=0 when output stalled");
      pass_count++;
    end else begin
      $display("FAIL [backpressure] in_ready should be 0 when stalled");
      fail_count++;
    end
    // drain
    out_ready = 1;
    @(posedge clk); #1;
    check("backpressure drain", 8'hFF, 16'd500, 16'd99, 24'd777);
    @(posedge clk); #1;

    // --- test 4: all-zero packet ---
    send_packet(64'h0);
    wait_output;
    check("all-zero packet", 8'h00, 16'd0, 16'd0, 24'd0);
    @(posedge clk); #1;

    // --- test 5: all-ones packet ---
    send_packet(64'hFFFFFFFFFFFFFFFF);
    wait_output;
    check("all-ones packet", 8'hFF, 16'hFFFF, 16'hFFFF, 24'hFFFFFF);
    @(posedge clk); #1;

    // --- summary ---
    $display("-----------------------------");
    $display("results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("SOME TESTS FAILED");
    $display("-----------------------------");

    $finish;
  end

  // safety timeout
  initial begin
    #5000;
    $display("FAIL: simulation timeout");
    $finish;
  end

endmodule