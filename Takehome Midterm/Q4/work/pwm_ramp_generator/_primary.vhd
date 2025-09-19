library verilog;
use verilog.vl_types.all;
entity pwm_ramp_generator is
    generic(
        CLK_FREQ        : integer := 100000000;
        PWM_FREQ        : integer := 1000;
        PWM_PERIOD      : vl_notype;
        STEP            : integer := 2000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        pwm_out         : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_FREQ : constant is 1;
    attribute mti_svvh_generic_type of PWM_FREQ : constant is 1;
    attribute mti_svvh_generic_type of PWM_PERIOD : constant is 3;
    attribute mti_svvh_generic_type of STEP : constant is 1;
end pwm_ramp_generator;
