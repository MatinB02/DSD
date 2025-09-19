library verilog;
use verilog.vl_types.all;
entity karatsuba_multiplier is
    port(
        a               : in     vl_logic_vector(127 downto 0);
        b               : in     vl_logic_vector(127 downto 0);
        product         : out    vl_logic_vector(255 downto 0);
        clk             : in     vl_logic
    );
end karatsuba_multiplier;
