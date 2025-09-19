library verilog;
use verilog.vl_types.all;
entity carry_stage is
    port(
        G               : in     vl_logic;
        P               : in     vl_logic;
        Cin             : in     vl_logic;
        Cout            : out    vl_logic
    );
end carry_stage;
