library verilog;
use verilog.vl_types.all;
entity mm is
    port(
        a               : in     vl_logic;
        b               : in     vl_logic;
        Cin             : in     vl_logic;
        Sum             : out    vl_logic;
        Cout            : out    vl_logic
    );
end mm;
