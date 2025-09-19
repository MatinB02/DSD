`timescale 1ns/1ps

// ============================================================
// Testbench @ 10 MHz
// ============================================================
module tb_sram_controller_10mhz;

    // ---------------- Clock / reset ----------------
    reg clk = 0;
    localparam real Tclk_ns = 100.0; // 10 MHz => 100 ns period
    always #(Tclk_ns/2.0) clk = ~clk;

    reg rst;

    // ---------------- System side ------------------
    reg         memRead, memWrite;
    reg  [8:0]  addrTarget;
    reg  [31:0] dataIn;
    wire [31:0] dataOut;
    wire        ready;

    // ---------------- SRAM bus ---------------------
    wire [8:0]  s_addr;
    wire [15:0] s_data;
    wire        s_CE, s_OE, s_WE, s_UB, s_LB;

    // ---------------- Instantiate controller -------
    sram_controller #(
        .FREQ_MHZ  (10),
        .tREAD_NS  (10),
        .tWRITE_NS (8)
    ) dut (
        .clk(clk),
        .rst(rst),
        .memRead(memRead),
        .memWrite(memWrite),
        .addrTarget(addrTarget),
        .dataIn(dataIn),
        .dataOut(dataOut),
        .ready(ready),
        .addr(s_addr),
        .data(s_data),
        .CE(s_CE),
        .OE(s_OE),
        .WE(s_WE),
        .UB(s_UB),
        .LB(s_LB)
    );

    // ---------------- Accurate SRAM model ----------
    sram mem (
        .addr(s_addr),
        .data(s_data),
        .CE(s_CE),
        .OE(s_OE),
        .WE(s_WE),
        .UB(s_UB),
        .LB(s_LB)
    );

    // ---------------- TB storage / helpers ---------
    integer i;
    reg [31:0] vec [0:9];
    reg [31:0] rd;

    task automatic write32(input [8:0] a, input [31:0] din);
        begin
            // wait until controller is idle
            @(posedge clk);
            while (!ready) @(posedge clk);

            addrTarget <= a;
            dataIn     <= din;
            memWrite   <= 1'b1;
            memRead    <= 1'b0;

            @(posedge clk); // sampled in IDLE
            memWrite   <= 1'b0;

            // wait for completion
            while (!ready) @(posedge clk);
        end
    endtask

    task automatic read32(input [8:0] a, output [31:0] dout);
        begin
            // Make sure we're idle first
            @(posedge clk);
            while (!ready) @(posedge clk);

            // Kick the read
            addrTarget <= a;
            memRead    <= 1'b1;
            memWrite   <= 1'b0;

            @(posedge clk);         // command is sampled
            memRead    <= 1'b0;

            // Wait for the controller to finish and re-assert ready
            @(posedge ready);       // ready goes 0->1 at the end of the read

            // (robust) sample on the next clk edge to be past all NBAs
            @(posedge clk);
            dout = dataOut;
        end
    endtask

    initial begin
        $timeformat(-9,0," ns",10);
        $dumpfile("tb_10mhz.vcd");
        $dumpvars(0, tb_sram_controller_10mhz);

        // init
        rst       = 1;
        memRead   = 0;
        memWrite  = 0;
        addrTarget= 0;
        dataIn    = 0;

        repeat (3) @(posedge clk);
        rst = 0;

        // 1) generate 10 random 32-bit numbers
        for (i = 0; i < 10; i = i + 1) begin
            vec[i] = $random;
        end

        // 2) write them to 10 different "blocks" (addresses 0,2,4,...,18)
        $display("\n[10MHz] --- WRITING 10 random 32-bit values ---");
        for (i = 0; i < 10; i = i + 1) begin
            write32(i*2, vec[i]);
            $display("[10MHz] Wrote @addr=%0d/%0d -> 0x%08X", i*2, i*2+1, vec[i]);
        end

        // 3) read them back
        $display("\n[10MHz] --- READING back and comparing ---");
        for (i = 0; i < 10; i = i + 1) begin
            read32(i*2, rd);
            if (rd !== vec[i]) begin
                $display("[10MHz]  MISMATCH @addr=%0d/%0d: got=0x%08X expected=0x%08X",
                          i*2, i*2+1, rd, vec[i]);
            end else begin
                $display("[10MHz]  MATCH    @addr=%0d/%0d: 0x%08X",
                          i*2, i*2+1, rd);
            end
        end

        $display("\n[10MHz] done.");
        // Let waves settle a bit
        repeat (10) @(posedge clk);
        $finish;
    end
endmodule



`timescale 1ns/1ps

// ============================================================
// Testbench @ 200 MHz
// ============================================================
module tb_sram_controller_200mhz;

    // ---------------- Clock / reset ----------------
    reg clk = 0;
    localparam real Tclk_ns = 5.0; // 200 MHz => 5 ns period
    always #(Tclk_ns/2.0) clk = ~clk;

    reg rst;

    // ---------------- System side ------------------
    reg         memRead, memWrite;
    reg  [8:0]  addrTarget;
    reg  [31:0] dataIn;
    wire [31:0] dataOut;
    wire        ready;

    // ---------------- SRAM bus ---------------------
    wire [8:0]  s_addr;
    wire [15:0] s_data;
    wire        s_CE, s_OE, s_WE, s_UB, s_LB;

    // ---------------- Instantiate controller -------
    sram_controller #(
        .FREQ_MHZ  (200),
        .tREAD_NS  (10),
        .tWRITE_NS (8)
    ) dut (
        .clk(clk),
        .rst(rst),
        .memRead(memRead),
        .memWrite(memWrite),
        .addrTarget(addrTarget),
        .dataIn(dataIn),
        .dataOut(dataOut),
        .ready(ready),
        .addr(s_addr),
        .data(s_data),
        .CE(s_CE), .OE(s_OE), .WE(s_WE), .UB(s_UB), .LB(s_LB)
    );

    // ---------------- Accurate SRAM model ----------
    sram mem (
        .addr(s_addr),
        .data(s_data),
        .CE(s_CE),
        .OE(s_OE),
        .WE(s_WE),
        .UB(s_UB),
        .LB(s_LB)
    );

    // ---------------- TB storage / helpers ---------
    integer i;
    reg [31:0] vec [0:9];
    reg [31:0] rd;

    task automatic write32(input [8:0] a, input [31:0] din);
        begin
            @(posedge clk);
            while (!ready) @(posedge clk);

            addrTarget <= a;
            dataIn     <= din;
            memWrite   <= 1'b1;
            memRead    <= 1'b0;

            @(posedge clk);          // command sampled
            memWrite   <= 1'b0;

            while (!ready) @(posedge clk);
        end
    endtask

    task automatic read32(input [8:0] a, output [31:0] dout);
        begin
            @(posedge clk);
            while (!ready) @(posedge clk);

            addrTarget <= a;
            memRead    <= 1'b1;
            memWrite   <= 1'b0;

            @(posedge clk);          // command sampled
            memRead    <= 1'b0;

            @(posedge ready);        // finished
            @(posedge clk);          // ensure NBAs are visible
            dout = dataOut;
        end
    endtask

    initial begin
        $timeformat(-9,0," ns",10);

        // ---------- VCD ----------
        $dumpfile("tb_200mhz.vcd");
        $dumpvars(0, tb_sram_controller_200mhz);

        // init
        rst        = 1;
        memRead    = 0;
        memWrite   = 0;
        addrTarget = 0;
        dataIn     = 0;

        repeat (3) @(posedge clk);
        rst = 0;

        // 1) generate 10 random 32-bit numbers
        for (i = 0; i < 10; i = i + 1)
            vec[i] = $random;

        // 2) write them to 10 different "blocks" (addresses 0,2,4,...,18)
        $display("\n[200MHz] --- WRITING 10 random 32-bit values ---");
        for (i = 0; i < 10; i = i + 1) begin
            write32(i*2, vec[i]);
            $display("[200MHz] Wrote @addr=%0d/%0d -> 0x%08X", i*2, i*2+1, vec[i]);
        end

        // 3) read them back
        $display("\n[200MHz] --- READING back and comparing ---");
        for (i = 0; i < 10; i = i + 1) begin
            read32(i*2, rd);
            if (rd !== vec[i])
                $display("[200MHz]  MISMATCH @addr=%0d/%0d: got=0x%08X expected=0x%08X",
                         i*2, i*2+1, rd, vec[i]);
            else
                $display("[200MHz]  MATCH    @addr=%0d/%0d: 0x%08X",
                         i*2, i*2+1, rd);
        end

        $display("\n[200MHz] done.");
        repeat (10) @(posedge clk);
        $finish;
    end

endmodule
