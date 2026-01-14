`timescale 1ns/1ps

module tb_mux4to1;

    parameter WIDTH = 8;
    
    logic [WIDTH-1:0] in0, in1, in2, in3;
    logic [1:0] sel;
    logic [WIDTH-1:0] out;
    
    // Instantiate DUT
    mux4to1 #(.WIDTH(WIDTH)) dut (
        .in0(in0),
        .in1(in1),
        .in2(in2),
        .in3(in3),
        .sel(sel),
        .out(out)
    );
    
    // Test procedure
    initial begin
        $display("Starting MUX 4:1 Test");
        $display("Time\tsel\tin0\tin1\tin2\tin3\tout");
        
        // Initialize inputs
        in0 = 8'hAA;
        in1 = 8'hBB;
        in2 = 8'hCC;
        in3 = 8'hDD;
        
        // Test all select combinations
        for (int i = 0; i < 4; i++) begin
            sel = i[1:0];
            #10;
            $display("%0t\t%b\t%h\t%h\t%h\t%h\t%h", 
                     $time, sel, in0, in1, in2, in3, out);
            
            // Check correctness
            case (sel)
                2'b00: assert(out == in0) else $error("Mismatch for sel=00");
                2'b01: assert(out == in1) else $error("Mismatch for sel=01");
                2'b10: assert(out == in2) else $error("Mismatch for sel=10");
                2'b11: assert(out == in3) else $error("Mismatch for sel=11");
            endcase
        end
        
        // Test with different input values
        in0 = 8'h11; in1 = 8'h22; in2 = 8'h33; in3 = 8'h44;
        #10;
        
        for (int i = 0; i < 4; i++) begin
            sel = i[1:0];
            #10;
            $display("%0t\t%b\t%h\t%h\t%h\t%h\t%h", 
                     $time, sel, in0, in1, in2, in3, out);
        end
        
        $display("Test Complete");
        $finish;
    end
    
    initial begin 
        $dumpfile("tb_mux4to1.vcd");  
        $dumpvars(0, tb_mux4to1); 
    end

endmodule