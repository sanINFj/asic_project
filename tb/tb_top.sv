`timescale 1ns/1ps

module tb_top #(
    parameter integer SCENARIO = 2
);

    // ============================================================
    // Clock / Reset
    // ============================================================

    logic clk;
    logic rst;

    initial clk = 1'b0;
    always #10 clk = ~clk;       // 50 MHz


    // ============================================================
    // LM75 behavioral model
    // ============================================================

    logic signed [15:0] sensor_temperature;
    logic sensor_valid;

    lm75_model #(
        .SAMPLE_INTERVAL(10),
        .SCENARIO(SCENARIO)
    ) u_lm75 (
        .clk(clk),
        .rst(rst),
        .temperature(sensor_temperature),
        .sample_valid(sensor_valid)
    );


    // ============================================================
    // ASSCE inputs
    // ============================================================

    logic [15:0] e_threshold;
    logic [15:0] a_threshold;

    logic signed [31:0] weights;

    logic accumulator_clear;


    // ============================================================
    // ASSCE outputs
    // ============================================================

    logic signed [31:0] result;
    logic result_valid;

    logic [4:0] fifo_occupancy;
    logic fifo_empty;
    logic fifo_full;
    logic signed [15:0] fifo_temperature;
    logic fifo_data_valid;

    logic signed [15:0] delta;
    logic [15:0] delta_mag;
    logic [15:0] acceleration;
    logic feature_valid;

    logic event_valid;
    logic [1:0] event_type;
    logic [15:0] event_score;
    logic [15:0] baseline;
    logic [15:0] deviation;

    logic signed [7:0] feature_0;
    logic signed [7:0] feature_1;
    logic signed [7:0] feature_2;
    logic signed [7:0] feature_3;
    logic sparse_feature_valid;

    logic scheduler_fifo_read;
    logic compute_start;
    logic mac_enable;
    logic mac_busy;
    logic mac_valid;

    logic signed [63:0] products;


    // ============================================================
    // DUT
    // ============================================================

    top #(
        .NUM_MAC(4)
    ) dut (
        .clk(clk),
        .rst(rst),

        .sensor_temperature(sensor_temperature),
        .sensor_valid(sensor_valid),

        .e_threshold(e_threshold),
        .a_threshold(a_threshold),

        .weights(weights),

        .accumulator_clear(accumulator_clear),

        .result(result),
        .result_valid(result_valid),

        .fifo_occupancy(fifo_occupancy),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_temperature(fifo_temperature),
        .fifo_data_valid(fifo_data_valid),

        .delta(delta),
        .delta_mag(delta_mag),
        .acceleration(acceleration),
        .feature_valid(feature_valid),

        .event_valid(event_valid),
        .event_type(event_type),
        .event_score(event_score),
        .baseline(baseline),
        .deviation(deviation),

        .feature_0(feature_0),
        .feature_1(feature_1),
        .feature_2(feature_2),
        .feature_3(feature_3),
        .sparse_feature_valid(sparse_feature_valid),

        .scheduler_fifo_read(scheduler_fifo_read),
        .compute_start(compute_start),
        .mac_enable(mac_enable),
        .mac_busy(mac_busy),
        .mac_valid(mac_valid),

        .products(products)
    );


    // ============================================================
    // Test setup
    // ============================================================

    initial begin

        e_threshold = 16'd256;    // 1.0 C in Q8.8
        a_threshold = 16'd128;    // 0.5 C in Q8.8

        // [2,3,4,5]
        weights = {
            8'sd5,
            8'sd4,
            8'sd3,
            8'sd2
        };

        accumulator_clear = 1'b1;

        rst = 1'b1;

        #100;

        @(negedge clk);
        rst = 1'b0;
        accumulator_clear = 1'b0;

        // Run long enough for all LM75 samples
        // and the complete ASSCE pipeline.
        repeat (500)
            @(posedge clk);

        $display("");
        $display("===============================================");
        $display("ASSCE SYSTEM TEST COMPLETED");
        $display("SCENARIO = %0d", SCENARIO);
        $display("FINAL ACCUMULATOR = %0d", result);
        $display("===============================================");

        $finish;
    end


    // ============================================================
    // Monitoring
    // ============================================================

    always @(posedge clk) begin

        if (sensor_valid) begin
            $display(
                "SENSOR @ %0t ns | temperature=%0d",
                $time,
                sensor_temperature
            );
        end

        if (fifo_data_valid) begin
            $display(
                "FIFO    @ %0t ns | temperature=%0d | occupancy=%0d",
                $time,
                fifo_temperature,
                fifo_occupancy
            );
        end

        if (event_valid) begin
            $display(
                "EVENT   @ %0t ns | type=%b | score=%0d | delta_mag=%0d | acceleration=%0d | deviation=%0d",
                $time,
                event_type,
                event_score,
                delta_mag,
                acceleration,
                deviation
            );
        end

        if (sparse_feature_valid) begin
            $display(
                "SPARSE  @ %0t ns | features=[%0d,%0d,%0d,%0d]",
                $time,
                feature_0,
                feature_1,
                feature_2,
                feature_3
            );
        end

        if (compute_start) begin
            $display(
                "COMPUTE @ %0t ns | scheduler issued computation",
                $time
            );
        end

        if (mac_enable) begin
            $display(
                "MAC     @ %0t ns | features=[%0d,%0d,%0d,%0d]",
                $time,
                feature_0,
                feature_1,
                feature_2,
                feature_3
            );
        end

        if (result_valid) begin
            $display(
                "ACCUM   @ %0t ns | result=%0d",
                $time,
                result
            );
        end

    end


    // ============================================================
    // Waveform
    // ============================================================

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
