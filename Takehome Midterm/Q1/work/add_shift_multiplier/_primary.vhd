library verilog;
use verilog.vl_types.all;
entity add_shift_multiplier is
    port(
        a               : in     vl_logic_vector(63 downto 0);
        b               : in     vl_logic_vector(63 downto 0);
        product         : out    vl_logic_vector(127 downto 0);
        clk             : in     vl_logic
    );
end add_shift_multiplier;
