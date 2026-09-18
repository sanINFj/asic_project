`timescale 1ns/1ps

module tb_accumulator;

    logic clk;
    logic rst;

    logic enable;
    logic clear;

    logic signed [63:0] product;

    logic signed [31:0] accumulated_value;
    logic valid;

    accumulator dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .clear(clear),
        .product(product),
        .accumulated_value(accumulated_value),
        .valid(valid)
    );

    always #5 clk = ~clk;

    initial begin

        $dumpfile("accumulator.vcd");
        $dumpvars(0, tb_accumulator);

        clk = 0;
        rst = 1;
        enable = 0;
        clear = 0;
        product = '0;

        // ==================================================
        // RESET
        // ==================================================

        #12;
        rst = 0;

        // ==================================================
        // TEST 1: Positive products
        // 2 + 6 + 12 + 20 = 40
        // ==================================================

        product[15:0]  = 16'sd2;
        product[31:16] = 16'sd6;
        product[47:32] = 16'sd12;
        product[63:48] = 16'sd20;

        enable = 1;

        #10;

        enable = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 1: Positive products");
        $display("Expected accumulated value: 40");
        $display("Actual accumulated value:   %0d",
                 accumulated_value);
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 2: Signed products
        // -10 + -12 + -2 + 6 = -18
        // ==================================================

        #9;

        product[15:0]   = -16'sd10;
        product[31:16]  = -16'sd12;
        product[47:32]  = -16'sd2;
        product[63:48]  = 16'sd6;

        enable = 1;

        #10;

        enable = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 2: Signed products");
        $display("Expected accumulated value: 22");
        $display("Actual accumulated value:   %0d",
                 accumulated_value);
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 3: CLEAR
        // ==================================================

        #9;

        clear = 1;

        #10;

        clear = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 3: Clear accumulator");
        $display("Expected accumulated value: 0");
        $display("Actual accumulated value:   %0d",
                 accumulated_value);
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 4: Accumulate multiple times
        //
        // First: 1 + 2 + 3 + 4 = 10
        // Second: 5 + 5 + 5 + 5 = 20
        // Final = 30
        // ==================================================

        #9;

        product[15:0]   = 16'sd1;
        product[31:16]  = 16'sd2;
        product[47:32]  = 16'sd3;
        product[63:48]  = 16'sd4;

        enable = 1;

        #10;

        enable = 0;

        #9;

        product[15:0]   = 16'sd5;
        product[31:16]  = 16'sd5;
        product[47:32]  = 16'sd5;
        product[63:48]  = 16'sd5;

        enable = 1;

        #10;

        enable = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 4: Multiple accumulation");
        $display("Expected accumulated value: 30");
        $display("Actual accumulated value:   %0d",
                 accumulated_value);
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 5: Enable disabled
        // ==================================================

        #9;

        product[15:0]   = 16'sd100;
        product[31:16]  = 16'sd100;
        product[47:32]  = 16'sd100;
        product[63:48]  = 16'sd100;

        enable = 0;

        #10;

        $display("------------------------------------------");
        $display("TEST 5: Enable disabled");
        $display("Expected accumulated value: 30");
        $display("Actual accumulated value:   %0d",
                 accumulated_value);
        $display("Valid: %0d", valid);

        #10;

        $display("------------------------------------------");
        $display("ALL ACCUMULATOR TESTS COMPLETED");
        $display("------------------------------------------");

        $finish;

    end

endmodule
