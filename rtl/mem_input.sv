// mem_input_inst.sv
// Memory input module - reads stock data from memory and sends over AXI Stream

module mem_input (
    input  logic        clk,
    input  logic        rst_n,

    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic [63:0] m_axis_tdata
);
 
    // Stock data memory (1024 entries of 64-bit data)
    logic [63:0] mem [0:1023];
    logic [9:0]  read_addr;
    logic        read_done;

    // Load memory from hex file
    initial begin
        $readmemh("memory.hex", mem);
    end

    // Data format (from LSB to MSB):
    // [63:56] = symbol (8-bit)
    // [55:40] = price (16-bit)
    // [39:24] = size (16-bit)
    // [23:0]  = sequence (24-bit)

    // Read logic
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            read_addr <= 10'h0;
            m_axis_tvalid <= 1'b0;
            read_done <= 1'b0;
        end else begin
            if (m_axis_tready) begin
                if (~read_done) begin
                    m_axis_tvalid <= 1'b1;
                    read_addr <= read_addr + 1'b1;
                    if (read_addr == 10'h3FF) begin  // Last address (1023)
                        read_done <= 1'b1;
                    end
                end else begin
                    m_axis_tvalid <= 1'b0;
                end
            end
        end
    end

    // Output data
    assign m_axis_tdata = mem[read_addr];

endmodule
