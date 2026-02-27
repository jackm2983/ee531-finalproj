`timescale 1ns/1ps

module simple_fifo_tb;
  parameter int W = 64;

  logic         clk, rst_n;
  logic         in_valid, in_ready;
  logic [W-1:0] in_data;
  logic         out_valid, out_ready;
  logic [W-1:0] out_data;

  simple_fifo #(.W(W)) dut (.*);

  initial begin 
        $dumpfile("tb_simple_fifo.vcd");  
        $dumpvars(0, tb_simple_fifo); 
  end

  initial clk = 0;
  always #5 clk = ~clk;

  int pass_cnt, fail_cnt;

  // reference model
  logic [W-1:0] ref_q[$];

  task automatic do_reset();
    rst_n     = 0;
    in_valid  = 0;
    in_data   = '0;
    out_ready = 0;
    ref_q     = {};
    repeat(2) @(posedge clk);
    #1; rst_n = 1;
  endtask

  task automatic check(input string lbl, logic [W-1:0] got, exp);
    if (got === exp) begin
      $display("PASS [%s] 0x%0h", lbl, got);
      pass_cnt++;
    end else begin
      $display("FAIL [%s] got=0x%0h exp=0x%0h", lbl, got, exp);
      fail_cnt++;
    end
  endtask

  task automatic check_bool(input string lbl, logic got, exp);
    if (got === exp) begin
      $display("PASS [%s] %0b", lbl, got);
      pass_cnt++;
    end else begin
      $display("FAIL [%s] got=%0b exp=%0b", lbl, got, exp);
      fail_cnt++;
    end
  endtask

  // drive one clock with chosen push/pop intent, update ref model
  task automatic drive(input logic do_push, do_pop,
                       input logic [W-1:0] push_data,
                       output logic did_push, did_pop,
                       output logic [W-1:0] popped_data);
    in_valid  = do_push;
    in_data   = push_data;
    out_ready = do_pop;

    @(posedge clk);
    // sample at clock edge before skew
    did_push    = in_valid  && in_ready;
    did_pop     = out_valid && out_ready;
    popped_data = out_data;
    #1;

    // update ref model
    if (did_push && did_pop) begin
      void'(ref_q.pop_front());
      ref_q.push_back(push_data);
    end else if (did_push) begin
      ref_q.push_back(push_data);
    end else if (did_pop) begin
      void'(ref_q.pop_front());
    end

    in_valid  = 0;
    out_ready = 0;
  endtask

  logic did_push, did_pop;
  logic [W-1:0] popped;

  task automatic check_state(input string ctx);
    check_bool($sformatf("%s out_valid", ctx), out_valid, ref_q.size() > 0);
    check_bool($sformatf("%s in_ready",  ctx), in_ready,  ref_q.size() < 2);
    if (out_valid && ref_q.size() > 0)
      check($sformatf("%s out_data", ctx), out_data, ref_q[0]);
  endtask

  initial begin
    pass_cnt = 0; fail_cnt = 0;

    // --- reset ---
    do_reset();
    check_state("reset");

    // --- push to empty ---
    drive(1, 0, 64'hAAAA_0001, did_push, did_pop, popped);
    check_state("push1");

    // --- push to fill ---
    drive(1, 0, 64'hBBBB_0002, did_push, did_pop, popped);
    check_state("push2_full");
    check_bool("full in_ready=0", in_ready, 0);

    // --- push blocked when full ---
    drive(1, 0, 64'hDEAD_DEAD, did_push, did_pop, popped);
    check_bool("push blocked did_push=0", did_push, 0);
    check_state("push_blocked");

    // --- pop from full ---
    drive(0, 1, '0, did_push, did_pop, popped);
    check("pop1 data", popped, 64'hAAAA_0001);
    check_state("after_pop1");

    // --- pop last entry ---
    drive(0, 1, '0, did_push, did_pop, popped);
    check("pop2 data", popped, 64'hBBBB_0002);
    check_state("empty");
    check_bool("empty out_valid=0", out_valid, 0);

    // --- pop from empty should not fire ---
    drive(0, 1, '0, did_push, did_pop, popped);
    check_bool("pop empty did_pop=0", did_pop, 0);
    check_state("pop_empty");

    // --- simultaneous push+pop, one entry ---
    drive(1, 0, 64'hCCCC_0003, did_push, did_pop, popped);
    drive(1, 1, 64'hDDDD_0004, did_push, did_pop, popped);
    check("simul 1entry pop data", popped, 64'hCCCC_0003);
    check_state("simul_1entry");

    // --- simultaneous push+pop, full ---
    drive(1, 0, 64'hEEEE_0005, did_push, did_pop, popped); // fill it
    drive(1, 1, 64'hFFFF_0006, did_push, did_pop, popped);
    check("simul full pop data", popped, 64'hDDDD_0004);
    check_state("simul_full");

    // --- drain remaining ---
    drive(0, 1, '0, did_push, did_pop, popped);
    drive(0, 1, '0, did_push, did_pop, popped);
    check_state("drained");

    // --- stress: 16 pushes with backpressure ---
    begin
      logic [W-1:0] d;
      for (int i = 0; i < 16; i++) begin
        d = 64'hF000_0000 + W'(i);
        drive(1, 0, d, did_push, did_pop, popped);
        if (ref_q.size() == 2) begin
          drive(0, 1, '0, did_push, did_pop, popped);
          drive(0, 1, '0, did_push, did_pop, popped);
        end
      end
      while (ref_q.size() > 0)
        drive(0, 1, '0, did_push, did_pop, popped);
      check_state("stress_done");
    end

    // --- mid-op reset ---
    drive(1, 0, 64'hDEAD_BEEF, did_push, did_pop, popped);
    #1; rst_n = 0;
    @(posedge clk); #1;
    rst_n = 1;
    ref_q = {};
    @(posedge clk); #1;
    check_state("mid_reset");

    $display("\n--- %0d passed, %0d failed ---", pass_cnt, fail_cnt);
    if (fail_cnt == 0) $display("ALL TESTS PASSED");
    $finish;
  end

  initial begin
    #50000; $display("TIMEOUT"); $finish;
  end

endmodule