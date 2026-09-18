`timescale 1ns/1ps

module tb_feature_extract;

    // ------------------------------------------------
    // Signals
    // ------------------------------------------------

    logic               clk;
    logic               rst;

    logic signed [15:0] temperature;
    logic               sample_valid;

    logic signed [15:0] delta;
    logic        [15:0] delta_mag;
    logic        [15:0] acceleration;
    logic               feature_valid;


    // ------------------------------------------------
    // DUT
    // ------------------------------------------------

    feature_extract dut (
        .clk(clk),
        .rst(rst),

        .temperature(temperature),
        .sample_valid(sample_valid),

        .delta(delta),
        .delta_mag(delta_mag),
        .acceleration(acceleration),
        .feature_valid(feature_valid)
    );


    // ------------------------------------------------
    // Clock
    // 10 ns period
    // ------------------------------------------------

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // ------------------------------------------------
    // VCD waveform dump
    // ------------------------------------------------

    initial begin
        $dumpfile("feature_extract.vcd");
        $dumpvars(0, tb_feature_extract);
    end


    // ------------------------------------------------
    // Monitor
    // ------------------------------------------------

    initial begin

        $monitor(
            "TIME=%0t | rst=%b | sample_valid=%b | temperature=%0d | delta=%0d | delta_mag=%0d | acceleration=%0d | feature_valid=%b",
            $time,
            rst,
            sample_valid,
            temperature,
            delta,
            delta_mag,
            acceleration,
            feature_valid
        );

    end


    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------

    initial begin

        // Initial values
        rst          = 1'b1;
        sample_valid = 1'b0;
        temperature  = 16'sd0;


        // ============================================
        // RESET
        // ============================================

        #12;

        if (feature_valid !== 1'b0)
            $display("ERROR: feature_valid should be 0 after reset");

        if (delta !== 16'sd0)
            $display("ERROR: delta should be 0 after reset");

        if (delta_mag !== 16'd0)
            $display("ERROR: delta_mag should be 0 after reset");

        if (acceleration !== 16'd0)
            $display("ERROR: acceleration should be 0 after reset");

        $display("RESET TEST PASSED");


        // Release reset
        rst = 1'b0;


        // ============================================
        // TEST 1
        // First sample: 25.0
        //
        // Q8.8:
        // 25.0 * 256 = 6400
        // ============================================

        @(negedge clk);

        temperature  = 16'sd6400;
        sample_valid = 1'b1;

        @(negedge clk);

        sample_valid = 1'b0;

        #1;

        if (feature_valid !== 1'b0)
            $display("ERROR: First sample should not produce valid features");

        $display("FIRST SAMPLE TEST PASSED");


        // ============================================
        // TEST 2
        // Second sample: 25.5
        //
        // ΔT = +0.5
        // |ΔT| = 0.5
        // acceleration = |0.5 - 0| = 0.5
        //
        // Q8.8:
        // 0.5 = 128
        // ============================================

        @(negedge clk);

        temperature  = 16'sd6528;
        sample_valid = 1'b1;

        @(negedge clk);

        sample_valid = 1'b0;

        #1;

        if (delta !== 16'sd128)
            $display(
                "ERROR TEST 2: Expected delta=128, got %0d",
                delta
            );

        if (delta_mag !== 16'd128)
            $display(
                "ERROR TEST 2: Expected delta_mag=128, got %0d",
                delta_mag
            );

        if (acceleration !== 16'd128)
            $display(
                "ERROR TEST 2: Expected acceleration=128, got %0d",
                acceleration
            );

        if (feature_valid !== 1'b1)
            $display(
                "ERROR TEST 2: feature_valid should be 1"
            );

        $display("TEST 2 PASSED: 25.0 -> 25.5");


        // ============================================
        // TEST 3
        // Third sample: 27.0
        //
        // ΔT = +1.5
        // |ΔT| = 1.5
        // acceleration = |1.5 - 0.5| = 1.0
        //
        // Q8.8:
        // 1.5 = 384
        // 1.0 = 256
        // ============================================

        @(negedge clk);

        temperature  = 16'sd6912;
        sample_valid = 1'b1;

        @(negedge clk);

        sample_valid = 1'b0;

        #1;

        if (delta !== 16'sd384)
            $display(
                "ERROR TEST 3: Expected delta=384, got %0d",
                delta
            );

        if (delta_mag !== 16'd384)
            $display(
                "ERROR TEST 3: Expected delta_mag=384, got %0d",
                delta_mag
            );

        if (acceleration !== 16'd256)
            $display(
                "ERROR TEST 3: Expected acceleration=256, got %0d",
                acceleration
            );

        if (feature_valid !== 1'b1)
            $display(
                "ERROR TEST 3: feature_valid should be 1"
            );

        $display("TEST 3 PASSED: 25.5 -> 27.0");


        // ============================================
        // TEST 4
        // Decreasing temperature
        //
        // 27.0 -> 26.0
        //
        // ΔT = -1.0
        // |ΔT| = 1.0
        //
        // Previous |ΔT| = 1.5
        //
        // acceleration = |1.0 - 1.5|
        //              = 0.5
        //
        // Q8.8:
        // -1.0 = -256
        // 1.0  = 256
        // 0.5  = 128
        // ============================================

        @(negedge clk);

        temperature  = 16'sd6656;       // 26.0
        sample_valid = 1'b1;

        @(negedge clk);

        sample_valid = 1'b0;

        #1;

        if (delta !== -16'sd256)
            $display(
                "ERROR TEST 4: Expected delta=-256, got %0d",
                delta
            );

        if (delta_mag !== 16'd256)
            $display(
                "ERROR TEST 4: Expected delta_mag=256, got %0d",
                delta_mag
            );

        if (acceleration !== 16'd128)
            $display(
                "ERROR TEST 4: Expected acceleration=128, got %0d",
                acceleration
            );

        $display("TEST 4 PASSED: 27.0 -> 26.0");


        // ============================================
        // TEST 5
        // No new sample
        //
        // sample_valid = 0
        //
        // Outputs should remain unchanged.
        // ============================================

        @(negedge clk);

        temperature  = 16'sd7680;       // 30.0
        sample_valid = 1'b0;

        @(negedge clk);

        #1;

        if (feature_valid !== 1'b0)
            $display(
                "ERROR TEST 5: feature_valid should be 0"
            );

        if (delta !== -16'sd256)
            $display(
                "ERROR TEST 5: delta changed without valid sample"
            );

        $display("TEST 5 PASSED: sample_valid=0");


        // ============================================
        // TEST 6
        // Sudden change
        //
        // Current previous temperature = 26.0
        // New temperature = 30.0
        //
        // ΔT = +4.0
        // |ΔT| = 4.0
        //
        // Previous |ΔT| = 1.0
        //
        // acceleration = |4.0 - 1.0|
        //              = 3.0
        //
        // Q8.8:
        // 4.0 = 1024
        // 3.0 = 768
        // ============================================

        @(negedge clk);

        temperature  = 16'sd7680;       // 30.0
        sample_valid = 1'b1;

        @(negedge clk);

        sample_valid = 1'b0;

        #1;

        if (delta !== 16'sd1024)
            $display(
                "ERROR TEST 6: Expected delta=1024, got %0d",
                delta
            );

        if (delta_mag !== 16'd1024)
            $display(
                "ERROR TEST 6: Expected delta_mag=1024, got %0d",
                delta_mag
            );

        if (acceleration !== 16'd768)
            $display(
                "ERROR TEST 6: Expected acceleration=768, got %0d",
                acceleration
            );

        if (feature_valid !== 1'b1)
            $display(
                "ERROR TEST 6: feature_valid should be 1"
            );

        $display("TEST 6 PASSED: 26.0 -> 30.0");


        // ============================================
        // FINISH
        // ============================================

        $display("------------------------------------------");
        $display("ALL FEATURE EXTRACTOR TESTS COMPLETED");
        $display("------------------------------------------");

        #20;

        $finish;

    end

endmodule