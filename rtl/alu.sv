//'timescale 1ns/1ps
////////////////////////
// Jack Marshall
// EE531 
// 8bit ALU
////////////////////////

module alu(
    input logic clk, 
    input logic rst,
    input logic [7:0] input_data,
    input logic [4:0] opcode,
    
    output logic [7:0] output_upper, // for 16 bit read
    output logic [7:0] output_lower,
    output logic sign_bit

);

logic signed [7:0] A0;
logic signed [7:0] B0;

logic signed [15:0] mult_result;

// opcodes
localparam OP_ADD      = 5'b00000;
localparam OP_SUB      = 5'b00001;
localparam OP_MULT     = 5'b00010;
localparam OP_AND      = 5'b00011;
localparam OP_OR       = 5'b00100;
localparam OP_XOR      = 5'b00101;
localparam OP_NOT      = 5'b00110;
localparam OP_LSL      = 5'b00111;
localparam OP_LSR      = 5'b01000;
localparam OP_ASR      = 5'b01001;
localparam OP_ROL      = 5'b01010;  // rotate left
localparam OP_ROR      = 5'b01011;  // rotate right
localparam OP_LOAD_A   = 5'b01100;
localparam OP_LOAD_B   = 5'b01101;
localparam OP_READ_A   = 5'b01110;
localparam OP_READ_B   = 5'b01111;
localparam OP_READ_AB  = 5'b10000;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        A0 <= 8'd0;
        B0 <= 8'd0;
    end else begin
        case (opcode)
            OP_ADD: begin
                A0 <= A0 + B0;
            end

            OP_SUB: begin
                A0 <= A0 - B0;
            end

            OP_MULT: begin
                mult_result = A0 * B0;
                A0 <= mult_result[15:8];
                B0 <= mult_result[7:0];
            end

            OP_AND: begin
                A0 <= A0 & B0;
            end

            OP_OR: begin
                A0 <= A0 | B0;
            end

            OP_XOR: begin
                A0 <= A0 ^ B0;
            end

            OP_NOT: begin
                A0 <= ~A0;
            end

            OP_LSL: begin
                A0 <= A0 << B0[2:0];
            end

            OP_LSR: begin
                A0 <= A0 >> B0[2:0];
            end

            OP_ASR: begin
                A0 <= A0 >>> B0[2:0];
            end

            OP_ROL: begin
                A0 <= (A0 << B0[2:0]) | (A0 >> (8 - B0[2:0]));
            end

            OP_ROR: begin
                A0 <= (A0 >> B0[2:0]) | (A0 << (8 - B0[2:0]));
            end

            OP_LOAD_A: begin
                A0 <= input_data;
            end

            OP_LOAD_B: begin
                B0 <= input_data;
            end
        
            default: begin
                // do nothing for read operations and handle them in combinational logic.
            end
        endcase
    end
end



always_comb begin
    output_upper = 8'd0;
    output_lower = 8'd0;
    sign_bit = 1'b0;

    case(opcode) 
        OP_READ_A: begin
            output_lower = A0;
            sign_bit = A0[7];
        end

        OP_READ_B: begin
            output_lower = B0;
            sign_bit = B0[7];
        end

        OP_READ_AB: begin
            output_upper = A0;
            output_lower = B0;
            sign_bit = A0[7];
        end

        default: begin
            output_upper = 8'd0;
            output_lower = 8'd0;
            sign_bit = 1'b0;
        end
    endcase
end


endmodule