`timescale 1ns/1ps

module tb_sram;
    reg  [8:0] addr;
    wire [15:0] data;
    reg           CE, OE, WE, UB, LB;
    reg  [15:0] data_out;
    wire [15:0] data_in;
    reg           drive_data;

    // Bidirectional data bus handling
    assign data = drive_data ? data_out : 16'hzzzz;
    assign data_in = data;

    // DUT
    sram uut (
        .addr(addr),
        .data(data),
        .CE(CE),
        .OE(OE),
        .WE(WE),
        .UB(UB),
        .LB(LB)
    );

    integer i;
    reg [15:0] ref_mem [0:29]; // for checking correctness

    // Task: Write full word to memory
    task write_word(input [8:0] a, input [15:0] d);
        begin
            addr       = a;
            data_out   = d;
            drive_data = 1;
            CE         = 0;
            OE         = 0;
            WE         = 0;  // Write
            UB         = 0;
            LB         = 0;
            #20;            // > tWC = 10ns + margin
            WE         = 1;
            drive_data = 0;
            #5;
        end
    endtask

    // Task: Read full word from memory
    task read_word(input [8:0] a);
        begin
            addr       = a;
            drive_data = 0;
            CE         = 0;
            OE         = 0;
            WE         = 1; // Read
            UB         = 0;
            LB         = 0;
            #20;             // > tRC = 10ns + margin
            $display("Read @%3d = 0x%04X", a, data_in);
        end
    endtask
    
    // Task: Read while staying in standby (CE must already be 1)
    // It does NOT change CE/OE/WE, it just samples the bus.
    task read_word_standby(input [8:0] a);
        begin
            addr       = a;
            drive_data = 0;   // never drive during a read
            // keep CE = 1 (standby), WE/OE as they currently are
            #20;              // just wait a little to sample
            $display("Read (standby) @%0d = %0h", a, data_in);
            if (data_in === 16'hzzzz)
                $display("   Correct: bus is Hi-Z in standby");
            else
                $display("   Error: expected Hi-Z (zzzz), got %0h", data_in);
        end
    endtask


    initial begin
        // VCD dumping setup
        // $dumpfile("sram_waveform.vcd"); // Specify the VCD file name
        // $dumpvars(0, tb_sram); // Dump all signals in the tb_sram module.
                               // 0 means dump all levels of hierarchy.
        // Init control signals
        addr       = 0;
        data_out   = 0;
        drive_data = 0;
        CE = 1;
        OE = 1;
        WE = 1;
        UB = 1;
        LB = 1;

        $display("\n--- Writing lower byte = addr to addresses 0-9 ---");
        for (i = 0; i < 10; i = i + 1) begin
            ref_mem[i] = {8'h00, i[7:0]};
            write_word(i, ref_mem[i]);
        end

        $display("\n--- Writing upper byte = $clog2(addr) to addresses 10-19 ---");
        for (i = 10; i < 20; i = i + 1) begin
            ref_mem[i] = {$clog2(i), 8'h00};
            write_word(i, ref_mem[i]);
        end

        $display("\n--- Writing random 16-bit values to addresses 20-29 ---");
        for (i = 20; i < 30; i = i + 1) begin
            ref_mem[i] = $random;
            write_word(i, ref_mem[i]);
        end

        $display("\n--- Reading addresses 0-29 and comparing ---");
        for (i = 0; i < 30; i = i + 1) begin
            read_word(i);
            if (data_in !== ref_mem[i])
                $display("   MISMATCH at addr %d: expected 0x%04X, got 0x%04X", i, ref_mem[i], data_in);
            else
                $display("  MATCH");
        end
  
  
        $display("\n--- Entering standby (CE = 1), trying write to address 0 ---");
        CE         = 1;  // standby
        OE         = 0;  // doesn't matter; CE=1 should dominate
        UB         = 0;
        LB         = 0;      
        WE         = 0;
        drive_data = 1;
        addr       = 0;
        data_out   = 16'hDEAD;
        #20;
        WE         = 1;  // back to read
        drive_data = 0;

        $display("\n--- Trying to read @0 in standby mode (expect zzzz) ---");
        CE         = 1;
        WE         = 1;
        OE         = 0;
        read_word_standby(0);

        $display("\n--- Leaving standby (CE = 0) and reading @0 again (expect original 0x%04h) ---", ref_mem[0]);
        CE = 0;
        OE = 0;
        WE = 1;
        read_word(0);

        $display("Expected original value: 0x%04h", ref_mem[0]);
        if (data_in === ref_mem[0])
            $display("   Correct: standby write was ignored (memory kept original value)");
        else
            $display("   Error: memory changed despite standby!");


        #5; // Small delay before finishing
        $display("\n--- Testbench complete ---");
        // $finish; // $finish is now uncommented to terminate the simulation
    end

endmodule