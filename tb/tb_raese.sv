`timescale 1ns/1ps

module tb_raese;

    logic clk;
    logic rst;

    logic [15:0] delta_mag;
    logic [15:0] acceleration;
    logic feature_valid;

    logic [15:0] e_threshold;
    logic [15:0] a_threshold;

    logic event_valid;
    logic [1:0] event_type;
    logic [15:0] event_score;
    logic [15:0] baseline;
    logic [15:0] deviation;


    raese dut (
        .clk(clk),
        .rst(rst),
        .delta_mag(delta_mag),
        .acceleration(acceleration),
        .feature_valid(feature_valid),
        .e_threshold(e_threshold),
        .a_threshold(a_threshold),
        .event_valid(event_valid),
        .event_type(event_type),
        .event_score(event_score),
        .baseline(baseline),
        .deviation(deviation)
    );


    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // VCD
    initial begin
        $dumpfile("raese.vcd");
        $dumpvars(0, tb_raese);
    end


    // Monitor
    initial begin
        $monitor(
            "TIME=%0t | rst=%b | valid=%b | D=%0d | A=%0d | baseline=%0d | deviation=%0d | score=%0d | type=%b | event_valid=%b",
            $time,
            rst,
            feature_valid,
            delta_mag,
            acceleration,
            baseline,
            deviation,
            event_score,
            event_type,
            event_valid
        );
    end


    initial begin

        rst = 1'b1;
        delta_mag = 16'h0000;
        acceleration = 16'h0000;
        feature_valid = 1'b0;

        // 1.0 C
        e_threshold = 16'h0100;

        // 0.5 C
        a_threshold = 16'h0080;


        // ----------------------------------------------------
        // RESET
        // ----------------------------------------------------

        #12;
        rst = 1'b0;

        #8;


        // ----------------------------------------------------
        // TEST 1: FIRST VALID FEATURE
        //
        // D = 0.5 C
        //
        // Expected:
        // baseline = 0.5 C
        // deviation = 0
        // score = 0
        // event_valid = 0
        // ----------------------------------------------------

        delta_mag = 16'h0080;
        acceleration = 16'h0080;
        feature_valid = 1'b1;

        #10;

        feature_valid = 1'b0;

        #10;


        // ----------------------------------------------------
        // TEST 2: NORMAL
        //
        // D = 0.5 C
        // A = 0
        //
        // Baseline is already 0.5 C.
        //
        // Expected:
        // deviation = 0
        // score = 0
        // NORMAL
        // ----------------------------------------------------

        delta_mag = 16'h0080;
        acceleration = 16'h0000;
        feature_valid = 1'b1;

        #10;

        feature_valid = 1'b0;

        #10;


        // ----------------------------------------------------
        // TEST 3: SUDDEN
        //
        // D = 1.5 C
        // A = 1.0 C
        //
        // Expected:
        // deviation > threshold
        // acceleration > threshold
        // SUDDEN
        // ----------------------------------------------------

        delta_mag = 16'h0180;
        acceleration = 16'h0100;
        feature_valid = 1'b1;

        #10;

        feature_valid = 1'b0;

        #10;


        // ----------------------------------------------------
        // TEST 4: GRADUAL
        //
        // D = 3.0 C
        // A = 0.25 C
        //
        // Expected:
        // deviation > threshold
        // acceleration < threshold
        // GRADUAL
        // ----------------------------------------------------

        delta_mag = 16'h0300;
        acceleration = 16'h0040;
        feature_valid = 1'b1;

        #10;

        feature_valid = 1'b0;

        #10;


        // ----------------------------------------------------
        // TEST 5: INVALID FEATURE
        //
        // feature_valid = 0
        //
        // Outputs should not change.
        // ----------------------------------------------------

        delta_mag = 16'h1000;
        acceleration = 16'h1000;
        feature_valid = 1'b0;

        #10;


        $display("------------------------------------------");
        $display("ALL RAESE TESTS COMPLETED");
        $display("------------------------------------------");

        #10;

        $finish;

    end

endmodule