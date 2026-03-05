module tb_mem_input;

    logic        clk;
    logic        rst_n;
    logic        m_axis_tvalid;
    logic        m_axis_tready;
    logic [63:0] m_axis_tdata;

    // DUT instantiation
    mem_input dut (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata)
    );

    // Waveform dumping
    initial begin
        $dumpfile("tb_mem_input.vcd");
        $dumpvars(0, tb_mem_input);
    end

    // Clock generation (10 ns period = 100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        int count = 0;
        
        // Reset
        rst_n = 0;
        m_axis_tready = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: Downstream always ready (continuous read)
        $display("[%0t] Test 1: Continuous read", $time);
        m_axis_tready = 1;
        
        repeat (100) @(posedge clk) begin
            if (m_axis_tvalid) begin
                count++;
                $display("[%0t] Data #%0d: 0x%016h (symbol=%c, price=0x%04h, size=0x%04h, seq=0x%06h)",
                    $time, count, m_axis_tdata,
                    m_axis_tdata[63:56],
                    m_axis_tdata[55:40],
                    m_axis_tdata[39:24],
                    m_axis_tdata[23:0]
                );
                
                // Stop after reading some data
                if (count >= 10) break;
            end
        end

        // Test 2: Ready signal back-pressure
        $display("[%0t] Test 2: Back-pressure test", $time);
        m_axis_tready = 0;
        repeat (10) @(posedge clk);
        m_axis_tready = 1;
        @(posedge clk);
        
        $display("[%0t] Back-pressure released, reading more data", $time);
        repeat (20) @(posedge clk) begin
            if (m_axis_tvalid) begin
                $display("[%0t] Data: 0x%016h", $time, m_axis_tdata);
            end
            if (!m_axis_tvalid) break;
        end

        $display("[%0t] Test complete", $time);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000;
        $fatal("Timeout!");
    end

endmodule
