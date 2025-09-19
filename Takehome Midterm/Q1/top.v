module add_shift_multiplier (
    input wire [63:0] a,
    input wire [63:0] b,
    output reg [127:0] product,
    input wire clk
);

    reg [63:0] aa;
    reg [127:0] bb;
    reg signed [7:0] counter;

    // Initialize everything at the beginning (only once)
    initial begin
        aa = 0;
        bb = 0;
        product = 0;
        counter = 0;
    end

    // Load inputs on first clock cycle when counter is 0
    always @(posedge clk) begin
        if (counter == 0) begin
            aa <= a;
            bb <= {64'b0, b};
            product <= 0;
            counter <= 64;
        end else if (counter > 0) begin
            if (aa[0]) begin
                product <= product + bb;
            end
            aa <= aa >> 1;
            bb <= bb << 1;
            counter <= counter - 1;
            if (counter == 0) begin
                counter <= counter - 1;
            end
        end
    end
    
endmodule



module karatsuba_multiplier(
    input signed [127:0] a,
    input signed [127:0] b,
    output signed [255:0] product,
    input wire clk
);
    // get abs values
    wire [127:0] abs_a = a[127] ? -a : a;
    wire [127:0] abs_b = b[127] ? -b : b;
    // result sign
    wire result_sign = a[127] ^ b[127];
    
    // Split 128-bit inputs into 64-bit halves
    wire [63:0] a_high = abs_a[127:64];
    wire [63:0] a_low = abs_a[63:0];
    wire [63:0] b_high = abs_b[127:64];
    wire [63:0] b_low = abs_b[63:0];
    
    // Intermediate products needed for Karatsuba
    wire [127:0] z0, z1, z2, z3;
    
    // Compute the four partial products using 64-bit multipliers
    add_shift_multiplier mult_low     (.a(a_low), .b(b_low), .product(z0), .clk(clk));
    add_shift_multiplier mult_cross1  (.a(a_low), .b(b_high), .product(z1), .clk(clk));
    add_shift_multiplier mult_cross2  (.a(a_high), .b(b_low), .product(z2), .clk(clk));
    add_shift_multiplier mult_high    (.a(a_high), .b(b_high), .product(z3), .clk(clk)); 
    
    // Final product assembly
    wire [255:0] p = (z3 << 128) + (z2 << 64) + (z1 << 64) + z0;
    assign product = result_sign ? -p : p;

endmodule




module tb_karatsuba_multiplier();

    reg signed [127:0] a, b;
    wire signed [255:0] product;
    reg clk;

    integer i;
    integer correct_32 = 0;
    integer correct_128 = 0;
    integer correct_edge = 0;

    integer pass;
    reg signed [127:0] ra, rb;
    reg signed [127:0] edge_a [0:13];
    reg signed [127:0] edge_b [0:13];

    // Instantiate the multiplier
    karatsuba_multiplier uut (.a(a), .b(b), .product(product), .clk(clk));

    // Clock generation
    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    // Task to test multiplication
    task test_multiplication;
        input signed [127:0] ta, tb;
        output integer pass_flag;
        begin
            a = ta;
            b = tb;
            #130; // 64 cycles + margin
            if (product === ta * tb) begin
                $display("PASS: a = %0d, b = %0d, product = %0d", ta, tb, product);
                pass_flag = 1;
            end else begin
                $display("FAIL: a = %0d, b = %0d, expected = %0d, got = %0d", ta, tb, ta * tb, product);
                pass_flag = 0;
            end
        end
    endtask

    initial begin
        // --------- 100 random 32-bit tests ---------
        $display("\n--- 100 Random 32-bit Tests ---");
        for (i = 0; i < 100; i = i + 1) begin
            ra = $random; // 32-bit signed
            rb = $random;
            test_multiplication(ra, rb, pass);
            correct_32 = correct_32 + pass;
        end

        // --------- 20 random 128-bit tests ---------
        $display("\n--- 20 Random 128-bit Tests ---");
        for (i = 0; i < 20; i = i + 1) begin
            ra = {$random(), $random(), $random(), $random()};
            rb = {$random(), $random(), $random(), $random()};
            if ($random % 2) ra = -ra;
            if ($random % 2) rb = -rb;
            test_multiplication(ra, rb, pass);
            correct_128 = correct_128 + pass;
        end

        // --------- 14 edge case tests ---------
        $display("\n--- 14 Edge Case Tests ---");
        edge_a[0]  = 0;               edge_b[0]  = 0;
        edge_a[1]  = 1;               edge_b[1]  = 1;
        edge_a[2]  = -1;              edge_b[2]  = -1;
        edge_a[3]  = 1;               edge_b[3]  = -1;
        edge_a[4]  = 127;             edge_b[4]  = 127;
        edge_a[5]  = -127;            edge_b[5]  = -127;
        edge_a[6]  = (2**64 - 1);     edge_b[6]  = (2**64 - 1);
        edge_a[7]  = -(2**64 - 1);    edge_b[7]  = (2**64 - 1);
        edge_a[8]  = (2**127 - 1);    edge_b[8]  = 1;
        edge_a[9]  = -(2**127);       edge_b[9]  = 1;
        edge_a[10] = -(2**127);       edge_b[10] = -1;
        edge_a[11] = (2**126);        edge_b[11] = 2;
        edge_a[12] = 1;               edge_b[12] = (2**127 - 1);
        edge_a[13] = (2**127 - 1);    edge_b[13] = (2**127 - 1);

        for (i = 0; i < 14; i = i + 1) begin
            test_multiplication(edge_a[i], edge_b[i], pass);
            correct_edge = correct_edge + pass;
        end

        // --------- Summary ---------
        $display("\n--- TEST SUMMARY ---");
        $display("Random 32-bit tests passed : %0d / 100", correct_32);
        $display("Random 128-bit tests passed: %0d / 20",  correct_128);
        $display("Edge case tests passed     : %0d / 14",  correct_edge);

        $finish;
    end

endmodule
