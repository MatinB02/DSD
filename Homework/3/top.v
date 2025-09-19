`timescale 1ns/1ns
module HalfAdder(input A, B, output Sum, Carry);
    xor #2 (Sum, A, B);     // Sum with 2ns delay
    and #3 (Carry, A, B);   // Carry with 3ns delay
endmodule

`timescale 1ns/1ns
module FullAdder(input A, B, Cin, output S, Cout);
    wire sum1, carry1, carry2;
    HalfAdder HA1(.A(A), .B(B), .Sum(sum1), .Carry(carry1));
    HalfAdder HA2(.A(sum1), .B(Cin), .Sum(S), .Carry(carry2));
    or #0 (Cout, carry1, carry2);// OR gate with 0ns delay
endmodule


module adder(input cin, input [3:0] a, b, output cout, output [3:0] s);
    wire [2:0] carry;
    FullAdder FA0(.A(a[0]), .B(b[0]), .Cin(cin), .S(s[0]), .Cout(carry[0]));
    FullAdder FA1(.A(a[1]), .B(b[1]), .Cin(carry[0]), .S(s[1]), .Cout(carry[1]));
    FullAdder FA2(.A(a[2]), .B(b[2]), .Cin(carry[1]), .S(s[2]), .Cout(carry[2]));
    FullAdder FA3(.A(a[3]), .B(b[3]), .Cin(carry[2]), .S(s[3]), .Cout(cout));
endmodule



`timescale 1ns/1ns
module test_bench();

    reg [3:0] A, B;
    reg Cin;
    wire [3:0] Sum;
    wire Cout;

    reg [4:0] expected_result;
    integer total_tests = 0;
    integer successful_tests = 0;
    realtime max_delay = 0;
    realtime start_time, end_time;

    integer i, j; // Declare loop variables

    adder uut(.a(A), .b(B), .cin(Cin), .s(Sum), .cout(Cout));

    task check_result;
        input [3:0] a_val, b_val;
        input cin_val;
        reg [4:0] local_expected;
        realtime local_start, local_end;
        reg timeout_flag;
        begin
            A = a_val;
            B = b_val;
            Cin = cin_val;
            local_expected = A + B + Cin;
            timeout_flag = 0;
            local_start = $realtime;

            fork
                begin
                    wait({Cout, Sum} === local_expected);
                    local_end = $realtime;
                end

                begin
                    #50;
                    if ({Cout, Sum} !== local_expected) begin
                        $display("Warning: Timeout at %0tns for A=%b, B=%b, Cin=%b", $time, A, B, Cin);
                        timeout_flag = 1;
                        local_end = $realtime;
                    end
                end
            join

            if ((local_end - local_start) > max_delay)
                max_delay = local_end - local_start;

            total_tests = total_tests + 1;

            if (!timeout_flag && ({Cout, Sum} === local_expected)) begin
                successful_tests = successful_tests + 1;
                $display("PASS: A=%b, B=%b, Cin=%b => Sum=%b, Cout=%b (Delay: %0tns)",
                         A, B, Cin, Sum, Cout, local_end - local_start);
            end else begin
                $display("FAIL: A=%b, B=%b, Cin=%b => Got {Cout=%b, Sum=%b}, Expected {Cout=%b, Sum=%b}",
                         A, B, Cin, Cout, Sum, local_expected[4], local_expected[3:0]);
            end
        end
    endtask

    initial begin
        #10;
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                check_result(i[3:0], j[3:0], 1'b1);
                check_result(i[3:0], j[3:0], 1'b0);
            end
        end

        $display("\nTest Results:");
        $display("Successful calculations: %0d / %0d", successful_tests, total_tests);
        $display("Maximum delay observed: %0.3f ns", max_delay);
        $display("Theoretical worst-case delay: 14 ns");

        $finish;
    end
endmodule
