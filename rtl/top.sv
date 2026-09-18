`timescale 1ns/1ps

module top #(
    parameter integer NUM_MAC = 4
)(
    // ============================================================
    // Clock / Reset
    // ============================================================

    input logic clk,
    input logic rst,


    // ============================================================
    // Sensor interface
    // ============================================================

    input logic signed [15:0] sensor_temperature,
    input logic sensor_valid,


    // ============================================================
    // RAESE thresholds
    // ============================================================

    input logic [15:0] e_threshold,
    input logic [15:0] a_threshold,


    // ============================================================
    // MAC weights
    // ============================================================

    input logic signed [NUM_MAC*8-1:0] weights,


    // ============================================================
    // Accumulator control
    // ============================================================

    input logic accumulator_clear,


    // ============================================================
    // Final result
    // ============================================================

    output logic signed [31:0] result,
    output logic result_valid,


    // ============================================================
    // FIFO debug/status
    // ============================================================

    output logic [4:0] fifo_occupancy,
    output logic fifo_empty,
    output logic fifo_full,

    output logic signed [15:0] fifo_temperature,
    output logic fifo_data_valid,


    // ============================================================
    // Feature extractor outputs
    // ============================================================

    output logic signed [15:0] delta,
    output logic [15:0] delta_mag,
    output logic [15:0] acceleration,
    output logic feature_valid,


    // ============================================================
    // RAESE outputs
    // ============================================================

    output logic event_valid,
    output logic [1:0] event_type,
    output logic [15:0] event_score,
    output logic [15:0] baseline,
    output logic [15:0] deviation,


    // ============================================================
    // Sparse encoder outputs
    // ============================================================

    output logic signed [7:0] feature_0,
    output logic signed [7:0] feature_1,
    output logic signed [7:0] feature_2,
    output logic signed [7:0] feature_3,
    output logic sparse_feature_valid,


    // ============================================================
    // Scheduler outputs
    // ============================================================

    output logic scheduler_fifo_read,
    output logic compute_start,
    output logic mac_enable,


    // ============================================================
    // MAC status
    // ============================================================

    output logic mac_busy,
    output logic mac_valid,

    output logic signed [NUM_MAC*16-1:0] products
);


    // ============================================================
    // FIFO internal signals
    // ============================================================

    logic fifo_wr_en;
    logic fifo_rd_en;

    logic signed [15:0] fifo_wr_data;
    logic signed [15:0] fifo_rd_data;


    // ============================================================
    // FIFO
    // ============================================================

    assign fifo_wr_data = sensor_temperature;

    // Write every valid sensor sample unless FIFO is full.
    assign fifo_wr_en =
        sensor_valid && !fifo_full;

    // For this first integrated architecture, samples are consumed
    // as soon as they are available.
    assign fifo_rd_en =
        !fifo_empty;


    fifo #(
        .DATA_WIDTH(16),
        .DEPTH(16),
        .PTR_WIDTH(4)
    ) u_fifo (
        .clk(clk),
        .rst(rst),

        .wr_en(fifo_wr_en),
        .wr_data(fifo_wr_data),

        .rd_en(fifo_rd_en),

        .rd_data(fifo_rd_data),

        .full(fifo_full),
        .empty(fifo_empty),

        .occupancy(fifo_occupancy)
    );


    // ============================================================
    // FIFO output alignment
    //
    // FIFO has registered read data, therefore fifo_data_valid
    // is delayed by one clock relative to fifo_rd_en.
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin
            fifo_data_valid <= 1'b0;
        end else begin
            fifo_data_valid <= fifo_rd_en;
        end

    end


    assign fifo_temperature =
        $signed(fifo_rd_data);


    // ============================================================
    // Feature Extractor
    // ============================================================

    feature_extract u_feature_extract (
        .clk(clk),
        .rst(rst),

        .temperature(fifo_temperature),
        .sample_valid(fifo_data_valid),

        .delta(delta),
        .delta_mag(delta_mag),
        .acceleration(acceleration),
        .feature_valid(feature_valid)
    );


    // ============================================================
    // RAESE
    // ============================================================

    raese u_raese (
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


    // ============================================================
    // Sparse Encoder
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

        .feature_valid(sparse_feature_valid)
    );


    // ============================================================
    // Scheduler
    // ============================================================

    logic mac_busy_reg;

    assign mac_busy = mac_busy_reg;


    scheduler u_scheduler (
        .clk(clk),
        .rst(rst),

        .event_valid(event_valid),
        .event_type(event_type),
        .event_score(event_score),

        .fifo_occupancy(fifo_occupancy),

        .mac_busy(mac_busy),
        .mac_valid(mac_valid),

        .compute_start(compute_start),
        .fifo_read(scheduler_fifo_read),
        .mac_enable(mac_enable)
    );


    // ============================================================
    // MAC busy tracking
    //
    // MAC becomes busy when a computation is issued and remains
    // busy until the registered MAC result becomes valid.
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            mac_busy_reg <= 1'b0;

        end else begin

            if (mac_enable)
                mac_busy_reg <= 1'b1;

            else if (mac_valid)
                mac_busy_reg <= 1'b0;

        end

    end


    // ============================================================
    // Pack sparse features into MAC input bus
    //
    // NUM_MAC = 4:
    //
    // data[7:0]   = feature_0
    // data[15:8]  = feature_1
    // data[23:16] = feature_2
    // data[31:24] = feature_3
    // ============================================================

    logic signed [NUM_MAC*8-1:0] mac_data;


    always_comb begin

        mac_data = '0;

        mac_data[7:0]   = feature_0;
        mac_data[15:8]  = feature_1;
        mac_data[23:16] = feature_2;
        mac_data[31:24] = feature_3;

    end


    // ============================================================
    // MAC Array
    // ============================================================

    mac_array #(
        .NUM_MAC(NUM_MAC)
    ) u_mac_array (
        .clk(clk),
        .rst(rst),

        .enable(mac_enable),

        .data(mac_data),
        .weight(weights),

        .product(products),
        .valid(mac_valid)
    );


    // ============================================================
    // Accumulator
    // ============================================================

    accumulator #(
        .NUM_MAC(NUM_MAC)
    ) u_accumulator (
        .clk(clk),
        .rst(rst),

        .enable(mac_valid),
        .clear(accumulator_clear),

        .product(products),

        .accumulated_value(result),
        .valid(result_valid)
    );

endmodule
