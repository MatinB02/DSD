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
    // Memory array: 512 locations, each 16 bits
    reg [15:0] mem [0:511];
    reg [15:0] data_output;

    // Invert active-low inputs to active-high internally
    wire CEx = ~CE, OEx = ~OE, WEx = ~WE, UBx = ~UB, LBx = ~LB;

    // High-impedance state for data bus when not driven (4.4 ns for read/standby, 5.5 ns for write)
    assign #(4) data = (CEx && OEx && !WEx && (UBx || LBx)) ? data_output : 16'bz;

    // Read and write control signals using internal active-high signals
    wire read  = (CEx && !WEx && OEx && (UBx || LBx));
    wire write = (CEx && WEx && (UBx || LBx));

    // Read operation with 11 ns delay (t_AA/t_ACE + 10% margin)
    always @(*) begin
        if (read) begin
            #10;
            if (UBx && LBx)
                data_output = mem[addr];                // Full 16-bit read
            else if (UBx)
                data_output = {mem[addr][15:8], 8'bz};  // Upper byte
            else if (LBx)
                data_output = {8'bz, mem[addr][7:0]};   // Lower byte
            else
                data_output = 16'bz;                    // No valid byte select
        end // else: preserve data_output for potential write or idle state
    end

    // Write operation with 8.8 ns delay (t_SCE/t_AW/t_PWB + 10% margin)
    always @(*) begin
        if (write) begin
            #8;
            if (UBx && LBx)
                mem[addr] = data;                   // Full 16-bit write
            else if (UBx)
                mem[addr][15:8] = data[15:8];       // Upper byte
            else if (LBx)
                mem[addr][7:0] = data[7:0];         // Lower byte
        end // else: no write, maintain current memory state
    end

endmodule