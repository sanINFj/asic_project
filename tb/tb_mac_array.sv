`timescale 1ns/1ps

module tb_mac_array;

    localparam NUM_MAC = 4;

    logic clk;
    logic rst;
    logic enable;

    // 4 × signed 8-bit inputs
    logic signed [NUM_MAC*8-1:0] data;
    logic signed [NUM_MAC*8-1:0] weight;

    // 4 × signed 16-bit outputs
    logic signed [NUM_MAC*16-1:0] product;

    logic valid;

    mac_array #(
        .NUM_MAC(NUM_MAC)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .data(data),
        .weight(weight),
        .product(product),
        .valid(valid)
    );

    always #5 clk = ~clk;

    initial begin

        $dumpfile("mac_array.vcd");
        $dumpvars(0, tb_mac_array);

        clk = 0;
        rst = 1;
        enable = 0;
        data = '0;
        weight = '0;

        // Hold reset
        #12;
        rst = 0;

        // ==================================================
        // TEST 1: Positive numbers
        // ==================================================

        // data = [1, 2, 3, 4]
        data[7:0]   = 8'sd1;
        data[15:8]  = 8'sd2;
        data[23:16] = 8'sd3;
        data[31:24] = 8'sd4;

        // weight = [2, 3, 4, 5]
        weight[7:0]   = 8'sd2;
        weight[15:8]  = 8'sd3;
        weight[23:16] = 8'sd4;
        weight[31:24] = 8'sd5;

        $display("DEBUG data:   %0d, %0d, %0d, %0d",
                 $signed(data[7:0]),
                 $signed(data[15:8]),
                 $signed(data[23:16]),
                 $signed(data[31:24]));

        $display("DEBUG weight: %0d, %0d, %0d, %0d",
                 $signed(weight[7:0]),
                 $signed(weight[15:8]),
                 $signed(weight[23:16]),
                 $signed(weight[31:24]));

        enable = 1;

        #10;

        enable = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 1: Positive numbers");
        $display("Expected: 2, 6, 12, 20");
        $display("Actual:   %0d, %0d, %0d, %0d",
                 $signed(product[15:0]),
                 $signed(product[31:16]),
                 $signed(product[47:32]),
                 $signed(product[63:48]));
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 2: Signed numbers
        // ==================================================

        #9;

        data[7:0]   = 8'sd5;
        data[15:8]  = -8'sd3;
        data[23:16] = 8'sd2;
        data[31:24] = 8'sd1;

        weight[7:0]   = -8'sd2;
        weight[15:8]  = 8'sd4;
        weight[23:16] = -8'sd1;
        weight[31:24] = 8'sd6;

        enable = 1;

        #10;

        enable = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 2: Signed numbers");
        $display("Expected: -10, -12, -2, 6");
        $display("Actual:   %0d, %0d, %0d, %0d",
                 $signed(product[15:0]),
                 $signed(product[31:16]),
                 $signed(product[47:32]),
                 $signed(product[63:48]));
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 3: Zero values
        // ==================================================

        #9;

        data[7:0]   = 8'sd0;
        data[15:8]  = 8'sd5;
        data[23:16] = 8'sd0;
        data[31:24] = -8'sd3;

        weight[7:0]   = 8'sd7;
        weight[15:8]  = 8'sd0;
        weight[23:16] = -8'sd4;
        weight[31:24] = 8'sd2;

        enable = 1;

        #10;

        enable = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 3: Zero values");
        $display("Expected: 0, 0, 0, -6");
        $display("Actual:   %0d, %0d, %0d, %0d",
                 $signed(product[15:0]),
                 $signed(product[31:16]),
                 $signed(product[47:32]),
                 $signed(product[63:48]));
        $display("Valid: %0d", valid);

        // ==================================================
        // TEST 4: Enable disabled
        // ==================================================

        #9;

        data[7:0]   = 8'sd10;
        data[15:8]  = 8'sd10;
        data[23:16] = 8'sd10;
        data[31:24] = 8'sd10;

        weight[7:0]   = 8'sd10;
        weight[15:8]  = 8'sd10;
        weight[23:16] = 8'sd10;
        weight[31:24] = 8'sd10;

        // MAC disabled
        enable = 0;

        #10;

        $display("------------------------------------------");
        $display("TEST 4: Enable disabled");
        $display("Expected: 0, 0, 0, -6");
        $display("Actual:   %0d, %0d, %0d, %0d",
                 $signed(product[15:0]),
                 $signed(product[31:16]),
                 $signed(product[47:32]),
                 $signed(product[63:48]));
        $display("Valid: %0d", valid);

        #10;

        $display("------------------------------------------");
        $display("ALL MAC ARRAY TESTS COMPLETED");
        $display("------------------------------------------");

        $finish;

    end

endmodule
