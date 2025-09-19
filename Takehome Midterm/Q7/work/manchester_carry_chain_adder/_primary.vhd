library verilog;
use verilog.vl_types.all;
entity manchester_carry_chain_adder is
    port(
        a               : in     vl_logic_vector(15 downto 0);
        b               : in     vl_logic_vector(15 downto 0);
        Cin             : in     vl_logic;
        Sum             : out    vl_logic_vector(15 downto 0);
        Cout            : out    vl_logic
    );
end manchester_carry_chain_adder;
