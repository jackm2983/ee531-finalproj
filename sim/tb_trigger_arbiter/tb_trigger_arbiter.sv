// tb_trigger_arbiter.sv
`timescale 1ns/1ps

module tb_trigger_arbiter;

  parameter int LANES = 4;
  localparam int OUT_W = 8+1+24+16;

  logic clk;
  logic rst_n;

  logic [LANES-1:0] in_valid;
  logic [LANES-1:0] in_ready;
  logic [LANES-1:0][OUT_W-1:0] in_data;

  logic out_valid;
  logic out_ready;
  logic [OUT_W-1:0] out_data;

  trigger_arbiter #(
    .LANES(LANES),
    .OUT_W(OUT_W)
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

  initial begin
    $dumpfile("tb_trigger_arbiter.vcd");
    $dumpvars(0, tb_trigger_arbiter);
  end

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    in_valid = '0;
    in_data = '0;
    out_ready = 1'b1;
    #20;
    rst_n = 1'b1;
  end

  // make_payload takes exactly 8-bit lane id to avoid truncation warnings
  function automatic logic [OUT_W-1:0] make_payload(input logic [7:0] lane);
    logic [OUT_W-1:0] p;
    begin
      p = '0;
      p[7:0] = lane;
      return p;
    end
  endfunction

  initial begin
    @(posedge rst_n);
    @(posedge clk);

    $display("--- test 1: single lane 0 asserts valid repeatedly ---");
    in_valid = '0;
    in_valid[0] = 1'b1;
    in_data[0] = make_payload(8'd0);
    repeat (3) begin
      wait_for_handshake();
      @(posedge clk);
    end
    in_valid = '0;
    @(posedge clk);

    $display("--- test 2: all lanes valid simultaneously ---");
    for (int i = 0; i < LANES; i++) begin
      in_data[i] = make_payload(8'(i));
      in_valid[i] = 1'b1;
    end
    for (int i = 0; i < LANES; i++) begin
      wait_for_handshake();
      @(posedge clk);
    end
    in_valid = '0;
    @(posedge clk);

    $display("--- test 3: two bursts to show rotation ---");
    for (int b = 0; b < 2; b++) begin
      for (int i = 0; i < LANES; i++) begin
        in_data[i] = make_payload(8'(i + b*4));
        in_valid[i] = 1'b1;
      end
      for (int i = 0; i < LANES; i++) begin
        wait_for_handshake();
        @(posedge clk);
      end
      in_valid = '0;
      @(posedge clk);
    end

    $display("all stimulus completed.");
    #20;
    $finish;
  end

  // wait_for_handshake prints lane id decoded from low 8 bits of out_data.
  task automatic wait_for_handshake();
    begin
      @(posedge clk);
      while (!out_valid) @(posedge clk);
      @(posedge clk);
      if (out_valid && out_ready) begin
        logic [7:0] lane_id;
        // explicitly widen 8-bit slice to unsigned before assigning to int to avoid warnings
        lane_id = out_data[7:0];
        $display("time %0t: handshake -> out_data[7:0]=%0d", $time, lane_id);
      end else begin
        $display("time %0t: out_valid asserted but no handshake", $time);
      end
    end
  endtask

endmodule