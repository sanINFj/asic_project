`timescale 1ns/1ps

module tb_sparse_encoder;

    logic clk;
    logic rst;

    logic event_valid;
    logic [1:0] event_type;

    logic signed [15:0] delta;
    logic [15:0] acceleration;
    logic [15:0] deviation;
    logic [15:0] event_score;

    logic signed [7:0] feature_0;
    logic signed [7:0] feature_1;
    logic signed [7:0] feature_2;
    logic signed [7:0] feature_3;

    logic feature_valid;

    sparse_encoder dut (
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

    always #5 clk = ~clk;

    initial begin

        $dumpfile("sparse_encoder.vcd");
        $dumpvars(0, tb_sparse_encoder);

        clk = 0;
        rst = 1;

        event_valid = 0;
        event_type = 2'b00;

        delta = 0;
        acceleration = 0;
        deviation = 0;
        event_score = 0;

        // ==================================================
        // RESET
        // ==================================================

        #12;
        rst = 0;

        // ==================================================
        // TEST 1: NORMAL EVENT
        // Should be discarded
        // ==================================================

        event_type = 2'b00;
        event_valid = 1;

        delta = 16'h0100;
        acceleration = 16'h0080;
        deviation = 16'h0200;
        event_score = 16'h0300;

        #10;

        event_valid = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 1: NORMAL event");
        $display("Expected feature_valid: 0");
        $display("Actual feature_valid:   %0d", feature_valid);

        // ==================================================
        // TEST 2: GRADUAL EVENT
        // Should be accepted
        // ==================================================

        #9;

        event_type = 2'b01;
        event_valid = 1;

        delta = 16'h0200;        // 2.0
        acceleration = 16'h0100; // 1.0
        deviation = 16'h0300;    // 3.0
        event_score = 16'h0500;  // 5.0

        #10;

        event_valid = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 2: GRADUAL event");
        $display("Expected features: 2, 1, 3, 5");
        $display("Actual features:   %0d, %0d, %0d, %0d",
                 feature_0,
                 feature_1,
                 feature_2,
                 feature_3);
        $display("Feature valid: %0d", feature_valid);

        // ==================================================
        // TEST 3: SUDDEN EVENT
        // Should be accepted
        // ==================================================

        #9;

        event_type = 2'b10;
        event_valid = 1;

        delta = 16'h0400;        // 4.0
        acceleration = 16'h0200; // 2.0
        deviation = 16'h0600;    // 6.0
        event_score = 16'h0A00;  // 10.0

        #10;

        event_valid = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 3: SUDDEN event");
        $display("Expected features: 4, 2, 6, 10");
        $display("Actual features:   %0d, %0d, %0d, %0d",
                 feature_0,
                 feature_1,
                 feature_2,
                 feature_3);
        $display("Feature valid: %0d", feature_valid);

        // ==================================================
        // TEST 4: RESERVED EVENT
        // Should be discarded
        // ==================================================

        #9;

        event_type = 2'b11;
        event_valid = 1;

        delta = 16'h0500;
        acceleration = 16'h0300;
        deviation = 16'h0700;
        event_score = 16'h0B00;

        #10;

        event_valid = 0;

        #1;

        $display("------------------------------------------");
        $display("TEST 4: RESERVED event");
        $display("Expected feature_valid: 0");
        $display("Actual feature_valid:   %0d", feature_valid);

        // ==================================================
        // TEST 5: No event
        // ==================================================

        #9;

        event_valid = 0;

        #10;

        $display("------------------------------------------");
        $display("TEST 5: No event");
        $display("Expected feature_valid: 0");
        $display("Actual feature_valid:   %0d", feature_valid);

        #10;

        $display("------------------------------------------");
        $display("ALL SPARSE ENCODER TESTS COMPLETED");
        $display("------------------------------------------");

        $finish;

    end

endmodule
