module pwm_ramp (
    input clk,
    input reset,
    output reg pwm_out
);
    reg [7:0] counter = 0;       // 8-bit PWM counter
    reg [7:0] duty = 0;          // 8-bit Duty cycle (0?255)
    reg [15:0] tick_counter = 0; // Controls ramp speed

    // How fast to ramp duty: 1 ms ramp = 50,000 cycles @ 50MHz
    // 256 steps from 0 to 255 ? increase duty every 195 cycles (roughly)
    localparam STEP_PERIOD = 195;

    always @(posedge clk) begin
    if (reset) begin
        counter <= 0;
        duty <= 0;
        tick_counter <= 0;
        pwm_out <= 0;
    end else begin
        counter <= counter + 1;

        pwm_out <= (counter < duty) ? 1 : 0;

        tick_counter <= tick_counter + 1;

        // Increase duty every fixed interval
        if (tick_counter >= STEP_PERIOD) begin
            tick_counter <= 0;
            if (duty < 255)
                duty <= duty + 1;
            else
                duty <= 0;
        end
    end
end

endmodule




`timescale 1ns/1ps

module pwm_tb;
  reg clk = 0;
  reg reset = 1;
  wire pwm_out;

  // Instantiate PWM module
  pwm_ramp uut (.clk(clk), .reset(reset), .pwm_out(pwm_out));

  // Clock generation: 50 MHz (20 ns period)
  always #1 clk = ~clk;

  integer f, i;

  initial begin
    f = $fopen("pwm_output.txt", "w");

    // Initial reset
    #2;
    reset = 0;
    
    // Let simulation run and log PWM output
    for (i = 0; i < 250000; i = i + 1) begin // 250,000 iterations / 50,000 = 5 ms
        @(posedge clk);
        $fwrite(f, "%d\n", pwm_out);
    end

    $fclose(f);
    $stop;
  end
endmodule

