library verilog;
use verilog.vl_types.all;
entity pwm_ramp is
    port(
        clk             : in     vl_logic;
        reset           : in     vl_logic;
        pwm_out         : out    vl_logic
    );
end pwm_ramp;
