`timescale 1ns/1ps

module tb_compute_chain;

    // ============================================================
    // Clock and reset
    // ============================================================

    logic clk;
    logic rst;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Sparse Encoder inputs
    // ============================================================

    logic        event_valid;
    logic [1:0]  event_type;

    logic signed [15:0] delta;
    logic        [15:0] acceleration;
    logic        [15:0] deviation;
    logic        [15:0] event_score;

    // Sparse Encoder outputs
    logic signed [7:0] feature_0;
    logic signed [7:0] feature_1;
    logic signed [7:0] feature_2;
    logic signed [7:0] feature_3;
    logic feature_valid;

    // ============================================================
    // MAC Array signals
    // ============================================================

    logic signed [31:0] mac_data;
    logic signed [31:0] mac_weight;

    logic signed [63:0] product;
    logic mac_valid;

    // ============================================================
    // Accumulator signals
    // ============================================================

    logic accumulator_enable;
    logic accumulator_clear;

    logic signed [31:0] accumulated_value;
    logic accumulator_valid;

    // ============================================================
    // DUT 1: Sparse Encoder
    // ============================================================

    sparse_encoder u_sparse_encoder (
        .clk(clk),
        .rst(rst),

        .event_valid(event_valid),
        .event_type(event_type),

        .delta(delta),
        .acceleration(acceleration),
        .deviation(deviation),
        .event_score(event_score),

        .feature_0(feature_0),
        .feature_1(feature_1),
        .feature_2(feature_2),
        .feature_3(feature_3),

        .feature_valid(feature_valid)
    );

    // ============================================================
    // Connect Sparse Encoder → MAC Array
    // ============================================================

    always_comb begin

        mac_data[7:0]   = feature_0;
        mac_data[15:8]  = feature_1;
        mac_data[23:16] = feature_2;
        mac_data[31:24] = feature_3;

    end

    // Fixed weights:
    //
    // feature_0 × 2
    // feature_1 × 3
    // feature_2 × 4
    // feature_3 × 5

    always_comb begin

        mac_weight[7:0]   = 8'sd2;
        mac_weight[15:8]  = 8'sd3;
        mac_weight[23:16] = 8'sd4;
        mac_weight[31:24] = 8'sd5;

    end

    // ============================================================
    // DUT 2: MAC Array
    // ============================================================

    mac_array #(
        .NUM_MAC(4)
    ) u_mac_array (
        .clk(clk),
        .rst(rst),
        .enable(feature_valid),

        .data(mac_data),
        .weight(mac_weight),

        .product(product),
        .valid(mac_valid)
    );

    // ============================================================
    // DUT 3: Accumulator
    // ============================================================

    assign accumulator_enable = mac_valid;

    accumulator u_accumulator (
        .clk(clk),
        .rst(rst),

        .enable(accumulator_enable),
        .clear(accumulator_clear),

        .product(product),

        .accumulated_value(accumulated_value),
        .valid(accumulator_valid)
    );

    // ============================================================
    // Test sequence
    // ============================================================

    initial begin

        // VCD generation
        $dumpfile("compute_chain.vcd");
        $dumpvars(0, tb_compute_chain);

        // Initial values
        rst = 1'b1;

        event_valid = 1'b0;
        event_type = 2'b00;

        delta = 16'd0;
        acceleration = 16'd0;
        deviation = 16'd0;
        event_score = 16'd0;

        accumulator_clear = 1'b0;

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        #12;

        rst = 1'b0;

        // --------------------------------------------------------
        // TEST 1: GRADUAL EVENT
        //
        // Q8.8 inputs:
        //
        // delta        = 0x0200 = 2
        // acceleration = 0x0100 = 1
        // deviation    = 0x0300 = 3
        // score        = 0x0500 = 5
        //
        // Sparse Encoder:
        //
        // feature = [2,1,3,5]
        //
        // MAC:
        //
        // 2×2 + 1×3 + 3×4 + 5×5
        // = 4 + 3 + 12 + 25
        // = 44
        // --------------------------------------------------------

        @(negedge clk);

        event_type = 2'b01;
        delta = 16'h0200;
        acceleration = 16'h0100;
        deviation = 16'h0300;
        event_score = 16'h0500;
        event_valid = 1'b1;

        @(negedge clk);

        event_valid = 1'b0;

        // Allow MAC and accumulator pipeline to complete
        repeat (3)
            @(negedge clk);

        $display("------------------------------------------");
        $display("TEST 1: GRADUAL EVENT");
        $display("Features : %0d %0d %0d %0d",
                 feature_0,
                 feature_1,
                 feature_2,
                 feature_3);

        $display("Products : %0d %0d %0d %0d",
                 $signed(product[15:0]),
                 $signed(product[31:16]),
                 $signed(product[47:32]),
                 $signed(product[63:48]));

        $display("Accumulator = %0d", accumulated_value);

        if (accumulated_value == 32'sd44)
            $display("TEST 1 PASSED");
        else
            $display("TEST 1 FAILED");

        // --------------------------------------------------------
        // TEST 2: SUDDEN EVENT
        //
        // Inputs produce:
        //
        // feature = [4,2,6,10]
        //
        // MAC:
        //
        // 4×2 + 2×3 + 6×4 + 10×5
        // = 8 + 6 + 24 + 50
        // = 88
        //
        // Accumulator should:
        //
        // previous = 44
        // new      = 44 + 88
        //          = 132
        // --------------------------------------------------------

        @(negedge clk);

        event_type = 2'b10;
        delta = 16'h0400;
        acceleration = 16'h0200;
        deviation = 16'h0600;
        event_score = 16'h0A00;
        event_valid = 1'b1;

        @(negedge clk);

        event_valid = 1'b0;

        repeat (3)
            @(negedge clk);

        $display("------------------------------------------");
        $display("TEST 2: SUDDEN EVENT");
        $display("Features : %0d %0d %0d %0d",
                 feature_0,
                 feature_1,
                 feature_2,
                 feature_3);

        $display("Products : %0d %0d %0d %0d",
                 $signed(product[15:0]),
                 $signed(product[31:16]),
                 $signed(product[47:32]),
                 $signed(product[63:48]));

        $display("Accumulator = %0d", accumulated_value);

        if (accumulated_value == 32'sd132)
            $display("TEST 2 PASSED");
        else
            $display("TEST 2 FAILED");

        // --------------------------------------------------------
        // TEST 3: NORMAL EVENT
        //
        // NORMAL should NOT reach MAC.
        // --------------------------------------------------------

        @(negedge clk);

        event_type = 2'b00;
        delta = 16'h0100;
        acceleration = 16'h0000;
        deviation = 16'h0000;
        event_score = 16'h0000;
        event_valid = 1'b1;

        @(negedge clk);

        event_valid = 1'b0;

        repeat (2)
            @(negedge clk);

        $display("------------------------------------------");
        $display("TEST 3: NORMAL EVENT");
        $display("Feature valid = %b", feature_valid);
        $display("MAC valid     = %b", mac_valid);
        $display("Accumulator   = %0d", accumulated_value);

        if ((feature_valid == 1'b0) &&
            (mac_valid == 1'b0) &&
            (accumulated_value == 32'sd132))
            $display("TEST 3 PASSED");
        else
            $display("TEST 3 FAILED");

        // --------------------------------------------------------
        // Finish
        // --------------------------------------------------------

        $display("------------------------------------------");
        $display("ALL COMPUTE CHAIN TESTS COMPLETED");
        $display("------------------------------------------");

        #10;
        $finish;

    end

endmodule
