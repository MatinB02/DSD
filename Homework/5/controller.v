`timescale 1ns/1ps

module sram_controller
#(
    // System clock frequency in MHz
    parameter integer FREQ_MHZ   = 100,
    // SRAM read and write latencies in ns
    parameter integer tREAD_NS   = 10,
    parameter integer tWRITE_NS  = 8
)
(
    // System interface
    input  wire         clk,          // Clock input
    input  wire         rst,          // Async reset, active high
    input  wire         memRead,      // Start 32-bit read (sampled in IDLE)
    input  wire         memWrite,     // Start 32-bit write (sampled in IDLE)
    input  wire [8:0]   addrTarget,   // 9-bit word address (lower 16-bit half)
    input  wire [31:0]  dataIn,       // 32-bit data to write
    output reg  [31:0]  dataOut,      // 32-bit data read
    output reg          ready,        // High when idle or operation complete

    // SRAM interface
    output reg  [8:0]   addr,         // 9-bit address to SRAM
    inout  wire [15:0]  data,         // 16-bit bidirectional data bus
    output wire         CE,           // Chip Enable (active low)
    output wire         OE,           // Output Enable (active low)
    output reg          WE,           // Write Enable (active low)
    output wire         UB,           // Upper Byte control (active low)
    output wire         LB            // Lower Byte control (active low)
);

    // Calculate wait cycles from ns, adding safety margin
    function integer ns_to_cycles(input integer ns);
        integer tmp;
    begin
        tmp = (ns * FREQ_MHZ + 999) / 1000; // ceil(ns * FREQ_MHZ / 1000)
        if (tmp < 1) tmp = 1;
        ns_to_cycles = tmp + 1; // One extra cycle for safety
    end
    endfunction

    // Define wait cycles for read and write operations
    localparam integer READ_WAIT_CYC  = ns_to_cycles(tREAD_NS);
    localparam integer WRITE_WAIT_CYC = ns_to_cycles(tWRITE_NS);
    localparam integer MAX_WAIT = (READ_WAIT_CYC > WRITE_WAIT_CYC) ? READ_WAIT_CYC : WRITE_WAIT_CYC;
    localparam integer WAIT_W   = $clog2(MAX_WAIT + 1); // Bit width for wait counter

    // SRAM static control lines (always active)
    assign CE = 1'b0; // Chip Enable always low
    assign OE = 1'b0; // Output Enable always low
    assign UB = 1'b0; // Upper Byte always enabled
    assign LB = 1'b0; // Lower Byte always enabled

    // Bidirectional data bus handling
    reg  [15:0] data_out16; // Data to drive on bus during writes
    wire [15:0] data_in16;  // Data read from bus
    reg         drive_bus;  // Control bus direction (drive during writes)

    assign data      = drive_bus ? data_out16 : 16'hzzzz; // Drive or Hi-Z
    assign data_in16 = data; // Capture bus input

    // FSM states for read/write operations
    localparam [3:0]
        S_IDLE        = 4'd0,  // Idle, waiting for command
        S_W_LO_SETUP  = 4'd1,  // Setup lower 16-bit write
        S_W_LO_WAIT   = 4'd2,  // Wait for SRAM write latency
        S_W_HI_SETUP  = 4'd3,  // Setup upper 16-bit write
        S_W_HI_WAIT   = 4'd4,  // Wait for SRAM write latency
        S_W_DONE      = 4'd5,  // Write complete
        S_R_LO_SETUP  = 4'd6,  // Setup lower 16-bit read
        S_R_LO_WAIT   = 4'd7,  // Wait for SRAM read latency
        S_R_LO_SAMPLE = 4'd8,  // Sample lower 16-bit read
        S_R_HI_SETUP  = 4'd9,  // Setup upper 16-bit read
        S_R_HI_WAIT   = 4'd10, // Wait for SRAM read latency
        S_R_HI_SAMPLE = 4'd11, // Sample upper 16-bit read
        S_R_DONE      = 4'd12; // Read complete

    reg [3:0]  state, next_state;     // Current and next state
    reg [WAIT_W-1:0] wait_cnt;        // Wait counter for timing
    reg [15:0] read_lo, read_hi;      // Temp storage for 16-bit read halves

    // State and wait counter update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;      // Reset to idle
            wait_cnt  <= {WAIT_W{1'b0}}; // Clear wait counter
        end else begin
            state     <= next_state;  // Update state
        end
    end

    // Wait counter logic
    wire wait_done = (wait_cnt == 0); // Signal when wait is complete
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wait_cnt <= 0; // Reset counter
        end else begin
            case (state)
                S_W_LO_WAIT, S_W_HI_WAIT, S_R_LO_WAIT, S_R_HI_WAIT:
                    wait_cnt <= wait_done ? 0 : wait_cnt - 1; // Decrement or clear
                default: begin
                    // Load counter on entering wait states
                    if (next_state == S_W_LO_WAIT) wait_cnt <= WRITE_WAIT_CYC - 1;
                    else if (next_state == S_W_HI_WAIT) wait_cnt <= WRITE_WAIT_CYC - 1;
                    else if (next_state == S_R_LO_WAIT) wait_cnt <= READ_WAIT_CYC - 1;
                    else if (next_state == S_R_HI_WAIT) wait_cnt <= READ_WAIT_CYC - 1;
                    else wait_cnt <= 0;
                end
            endcase
        end
    end

    // Output and side-effect logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ready      <= 1'b1;       // Ready on reset
            addr       <= 9'd0;       // Clear address
            WE         <= 1'b1;       // Write disable (read mode)
            drive_bus  <= 1'b0;       // Bus not driven
            data_out16 <= 16'h0000;   // Clear output data
            dataOut    <= 32'h0000_0000; // Clear read data
            read_lo    <= 16'h0000;   // Clear temp read storage
            read_hi    <= 16'h0000;
        end else begin
            case (next_state)
                S_IDLE: begin
                    ready      <= 1'b1;   // Signal ready
                    WE         <= 1'b1;   // Disable writes
                    drive_bus  <= 1'b0;   // Release bus
                end
                S_W_LO_SETUP: begin
                    ready      <= 1'b0;   // Not ready during operation
                    addr       <= addrTarget; // Set lower address
                    data_out16 <= dataIn[15:0]; // Lower 16-bit data
                    WE         <= 1'b0;   // Enable write
                    drive_bus  <= 1'b1;   // Drive bus
                end
                S_W_LO_WAIT: begin
                    // Hold signals during wait
                end
                S_W_HI_SETUP: begin
                    addr       <= addrTarget + 1'b1; // Set upper address
                    data_out16 <= dataIn[31:16]; // Upper 16-bit data
                    WE         <= 1'b0;
                    drive_bus  <= 1'b1;
                end
                S_W_HI_WAIT: begin
                    // Hold signals
                end
                S_W_DONE: begin
                    WE         <= 1'b1;   // Disable write
                    drive_bus  <= 1'b0;   // Release bus
                    ready      <= 1'b1;   // Signal completion
                end
                S_R_LO_SETUP: begin
                    ready      <= 1'b0;   // Not ready
                    addr       <= addrTarget; // Set lower address
                    WE         <= 1'b1;   // Read mode
                    drive_bus  <= 1'b0;   // Release bus
                end
                S_R_LO_WAIT: begin
                    // Wait for SRAM read data
                end
                S_R_LO_SAMPLE: begin
                    read_lo <= data_in16; // Sample lower 16-bit data
                end
                S_R_HI_SETUP: begin
                    addr       <= addrTarget + 1'b1; // Set upper address
                    WE         <= 1'b1;
                    drive_bus  <= 1'b0;
                end
                S_R_HI_WAIT: begin
                    // Wait for SRAM read data
                end
                S_R_HI_SAMPLE: begin
                    read_hi <= data_in16; // Sample upper 16-bit data
                end
                S_R_DONE: begin
                    dataOut <= {read_hi, read_lo}; // Combine read data
                    ready   <= 1'b1;  // Signal completion
                end
                default: ;
            endcase
        end
    end

    // Next-state logic
    always @* begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (memWrite)       next_state = S_W_LO_SETUP;
                else if (memRead)   next_state = S_R_LO_SETUP;
                else                next_state = S_IDLE;
            end
            S_W_LO_SETUP:  next_state = S_W_LO_WAIT;
            S_W_LO_WAIT:   next_state = wait_done ? S_W_HI_SETUP : S_W_LO_WAIT;
            S_W_HI_SETUP:  next_state = S_W_HI_WAIT;
            S_W_HI_WAIT:   next_state = wait_done ? S_W_DONE : S_W_HI_WAIT;
            S_W_DONE:      next_state = S_IDLE;
            S_R_LO_SETUP:  next_state = S_R_LO_WAIT;
            S_R_LO_WAIT:   next_state = wait_done ? S_R_LO_SAMPLE : S_R_LO_WAIT;
            S_R_LO_SAMPLE: next_state = S_R_HI_SETUP;
            S_R_HI_SETUP:  next_state = S_R_HI_WAIT;
            S_R_HI_WAIT:   next_state = wait_done ? S_R_HI_SAMPLE : S_R_HI_WAIT;
            S_R_HI_SAMPLE: next_state = S_R_DONE;
            S_R_DONE:      next_state = S_IDLE;
            default:       next_state = S_IDLE;
        endcase
    end

endmodule