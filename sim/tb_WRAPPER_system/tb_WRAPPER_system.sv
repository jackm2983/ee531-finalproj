
module tb_WRAPPER_system;

    logic clk;
    logic rst_n;

    initial begin 
        $dumpfile("tb_WRAPPER_system.vcd");  
        $dumpvars(0, tb_WRAPPER_system); 
    end

    initial clk = 0;
    always #5 clk = ~clk;

    WRAPPER_system dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        int seq = 0;
        rst_n = 0;

        repeat (5) @(posedge clk);
        rst_n = 1;

        repeat (100) @(posedge clk);
        $finish;
    end

    initial begin
        #1000000;
        $fatal("timeout");
    end

endmodule