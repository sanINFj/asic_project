`timescale 1ns/1ps

module raese #(
    parameter integer GRADUAL_COUNT_TH = 3
)(
    input logic        clk,
    input logic        rst,

    input logic [15:0] delta_mag,
    input logic signed [15:0] delta,
    input logic [15:0] acceleration,
    input logic        feature_valid,

    input logic [15:0] e_threshold,
    input logic [15:0] a_threshold,

    output logic        event_valid,
    output logic [1:0]  event_type,
    output logic [15:0] event_score,
    output logic [15:0] baseline,
    output logic [15:0] deviation
);

    // ============================================================
    // Event types
    // ============================================================

    localparam logic [1:0] EVENT_NORMAL  = 2'b00;
    localparam logic [1:0] EVENT_GRADUAL = 2'b01;
    localparam logic [1:0] EVENT_SUDDEN  = 2'b10;


    // ============================================================
    // Baseline / trend state
    // ============================================================

    logic baseline_initialized;

    // Trend direction:
    //   +1 = temperature increasing
    //   -1 = temperature decreasing
    //    0 = no active trend
    logic signed [1:0] trend_direction;

    // Number of consecutive nonzero deltas
    // in the same direction.
    integer trend_count;


    // ============================================================
    // Combinational calculations
    // ============================================================

    logic [16:0] deviation_ext;
    logic [16:0] acceleration_x2;
    logic [16:0] score_ext;

    // Next trend state.
    logic signed [1:0] next_trend_direction;
    integer next_trend_count;


    always_comb begin

        // --------------------------------------------------------
        // Deviation:
        //
        // D = |delta_mag - baseline|
        // --------------------------------------------------------

        if ({1'b0, delta_mag} >= {1'b0, baseline}) begin

            deviation_ext =
                {1'b0, delta_mag} -
                {1'b0, baseline};

        end else begin

            deviation_ext =
                {1'b0, baseline} -
                {1'b0, delta_mag};

        end


        // --------------------------------------------------------
        // 2 * acceleration
        // --------------------------------------------------------

        acceleration_x2 =
            {1'b0, acceleration} << 1;


        // --------------------------------------------------------
        // Event score:
        //
        // S = D + 2*a
        // --------------------------------------------------------

        score_ext =
            deviation_ext + acceleration_x2;


        // --------------------------------------------------------
        // Determine NEXT trend state.
        //
        // This is calculated combinationally so that the current
        // sample can trigger GRADUAL as soon as the threshold
        // number of consecutive changes is reached.
        // --------------------------------------------------------

        next_trend_direction = trend_direction;
        next_trend_count     = trend_count;

        if (delta > 0) begin

            if (trend_direction == 2'sd1) begin

                if (trend_count < GRADUAL_COUNT_TH)
                    next_trend_count = trend_count + 1;

            end else begin

                next_trend_direction = 2'sd1;
                next_trend_count     = 1;

            end

        end else if (delta < 0) begin

            if (trend_direction == -2'sd1) begin

                if (trend_count < GRADUAL_COUNT_TH)
                    next_trend_count = trend_count + 1;

            end else begin

                next_trend_direction = -2'sd1;
                next_trend_count     = 1;

            end

        end else begin

            // No temperature change breaks the trend.

            next_trend_direction = 2'sd0;
            next_trend_count     = 0;

        end

    end


    // ============================================================
    // Sequential RAESE
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            baseline <= 16'd0;
            deviation <= 16'd0;
            event_score <= 16'd0;

            event_type <= EVENT_NORMAL;
            event_valid <= 1'b0;

            baseline_initialized <= 1'b0;

            trend_direction <= 2'sd0;
            trend_count <= 0;

        end else begin

            // event_valid is a one-cycle pulse.
            event_valid <= 1'b0;


            if (feature_valid) begin

                // ==================================================
                // First feature:
                // initialize baseline.
                // ==================================================

                if (!baseline_initialized) begin

                    baseline <= delta_mag;

                    deviation <= 16'd0;
                    event_score <= 16'd0;
                    event_type <= EVENT_NORMAL;

                    event_valid <= 1'b0;

                    baseline_initialized <= 1'b1;

                    trend_direction <= 2'sd0;
                    trend_count <= 0;

                end else begin

                    // ==============================================
                    // Store deviation
                    // ==============================================

                    if (deviation_ext > 17'h0FFFF)
                        deviation <= 16'hFFFF;
                    else
                        deviation <= deviation_ext[15:0];


                    // ==============================================
                    // Store event score
                    // ==============================================

                    if (score_ext > 17'h0FFFF)
                        event_score <= 16'hFFFF;
                    else
                        event_score <= score_ext[15:0];


                    // ==============================================
                    // Store updated trend state
                    // ==============================================

                    trend_direction <= next_trend_direction;
                    trend_count <= next_trend_count;


                    // ==============================================
                    // Event classification
                    // ==============================================

                    // SUDDEN has highest priority.
                    //
                    // A large deviation combined with a large
                    // acceleration represents a sudden event.

                    if (
                        (deviation_ext >= {1'b0, e_threshold}) &&
                        (acceleration > a_threshold)
                    ) begin

                        event_type <= EVENT_SUDDEN;

                    end

                    // GRADUAL:
                    // persistent nonzero change in the same
                    // direction for the required number of samples.

                    else if (
                        (next_trend_count >= GRADUAL_COUNT_TH) &&
                        (delta != 0)
                    ) begin

                        event_type <= EVENT_GRADUAL;

                    end

                    // Otherwise NORMAL.

                    else begin

                        event_type <= EVENT_NORMAL;

                    end


                    // A feature has been classified.
                    event_valid <= 1'b1;


                    // ==============================================
                    // EMA-like baseline update
                    //
                    // B = B + (delta_mag - B)/8
                    // ==============================================

                    if (delta_mag >= baseline) begin

                        baseline <= baseline +
                                     ((delta_mag - baseline) >> 3);

                    end else begin

                        baseline <= baseline -
                                     ((baseline - delta_mag) >> 3);

                    end

                end

            end

        end

    end

endmodule
