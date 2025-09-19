`timescale 1ns/1ps

module sram (
    input  [8:0]  addr,       // 9-bit address for 512 locations
    inout  [15:0] data,       // 16-bit bidirectional data bus
    input         CE,         // Chip Enable (active low)
    input         OE,         // Output Enable (active low)
    input         WE,         // Write Enable (active low)
    input         UB,         // Upper Byte control (active low)
    input         LB          // Lower Byte control (active low)
);

    // -------------------- Timing numbers for the -10 part (ns) --------------------
    // Read path
    localparam integer tRC    = 10;
    localparam integer tAA    = 10;
    localparam integer tOHA   = 2;
    localparam integer tACE   = 10;
    localparam integer tDOE   = 4;
    localparam integer tHZOE  = 4;
    localparam integer tLZOE  = 0;
    localparam integer tHZCE  = 4;
    localparam integer tLZCE  = 3;
    localparam integer tBA    = 4;
    localparam integer tHZB   = 3;
    localparam integer tLZB   = 0;

    // Write path
    localparam integer tWC    = 10;
    localparam integer tSCE   = 8;
    localparam integer tAW    = 8;
    localparam integer tHA    = 0;
    localparam integer tPWB   = 8;
    localparam integer tPWE1  = 8;   // OE high
    localparam integer tPWE2  = 10;  // OE low
    localparam integer tSD    = 6;
    localparam integer tHD    = 0;
    localparam integer tHZWE  = 5;
    localparam integer tLZWE  = 2;

    // Effective behavioral delays
    localparam integer tREAD  = (tAA  > tACE) ? tAA  : tACE; // 10 ns
    localparam integer tWRITE = ( (tSCE > tAW ? tSCE : tAW) > tPWB )
                                ? (tSCE > tAW ? tSCE : tAW) : tPWB; // 8 ns

    // ------------------------------------------------------------------------------

    // Memory array: 512 locations, each 16 bits
    reg [15:0] mem [0:511];
    reg [15:0] data_output;

    // Invert active-low inputs to active-high internally
    wire CEx = ~CE, OEx = ~OE, WEx = ~WE, UBx = ~UB, LBx = ~LB;

    // Delayed gating network to model enable/disable (drive/Hi‑Z) timing *per control*
    wire ce_drv, oe_drv, we_drv, ub_drv, lb_drv;
    assign #(tLZCE, tHZCE) ce_drv = CEx;
    assign #(tLZOE, tHZOE) oe_drv = OEx;
    assign #(tLZWE, tHZWE) we_drv = WEx;
    assign #(tLZB,  tHZB ) ub_drv = UBx;
    assign #(tLZB,  tHZB ) lb_drv = LBx;

    // Drive condition seen on the external bus after proper enable/disable delays
    wire drive_bus = ce_drv && oe_drv && !we_drv && (ub_drv || lb_drv);

    // Tri-state data bus; the *timing of drive/Hi‑Z* is carried by the delayed enables above.
    // The value put on the bus comes from data_output (which itself respects tREAD).
    assign data = drive_bus ? data_output : 16'hzzzz;

    // Raw read/write intents (without the enable/disable edge timing)
    wire read_raw  = (CEx && !WEx && OEx && (UBx || LBx));
    wire write_raw = (CEx &&  WEx && (UBx || LBx));

    // ---------------------------- Read path ----------------------------
    // Update data_output after the proper read access delay.
    always @(*) begin
        if (read_raw) begin
            #(tREAD);
            if (UBx && LBx)
                data_output = mem[addr];                 // Full 16-bit read
            else if (UBx)
                data_output = {mem[addr][15:8], 8'hzz};  // Upper byte
            else if (LBx)
                data_output = {8'hzz, mem[addr][7:0]};   // Lower byte
            else
                data_output = 16'hzzzz;
        end
        // else: retain previous data_output (so the bus can hold tOHA when needed)
    end

    // ---------------------------- Write path ---------------------------
    // Commit the write after the proper write timing.
    always @(*) begin
        if (write_raw) begin
            #(tWRITE);
            if (UBx && LBx)
                mem[addr] = data;                   // Full 16-bit write
            else if (UBx)
                mem[addr][15:8] = data[15:8];       // Upper byte
            else if (LBx)
                mem[addr][7:0] = data[7:0];         // Lower byte
        end
    end

    // ---------------------------- Timing checks ------------------------
    specify
        // Path delays (for read)
        (addr *> data) = tAA;        // 10 ns delay from addr to data
        (CE   *> data) = tACE;
        (OE   *> data) = tDOE;
        (UB   *> data) = tBA;
        (LB   *> data) = tBA;

        // Write: setup/hold & pulse widths
        $setup (addr, posedge WE, tAW);
        $hold  (posedge WE, addr, tHA);

        $setup (data, posedge WE, tSD);
        $hold  (posedge WE, data, tHD);

        // WE pulse width (active low)
        $width (negedge WE, tPWB);

        // Optional cycle times (you can comment these if noisy)
        $period (posedge WE, tWC);   // Approximate write cycle
        $period (posedge OE, tRC);   // Approximate read cycle

        // CE low time for write (approximate, unconditional)
        $width (negedge CE, tSCE);
    endspecify

endmodule
