`timescale 1ns/1ps

module raese (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] delta_mag,
    input  logic [15:0] acceleration,
    input  logic        feature_valid,
    input  logic [15:0] e_threshold,
    input  logic [15:0] a_threshold,

    output logic        event_valid,
    output logic [1:0]  event_type,
    output logic [15:0] event_score,
    output logic [15:0] baseline,
    output logic [15:0] deviation
);

    logic baseline_initialized;

    logic [16:0] deviation_ext;
    logic [16:0] acceleration_x2;
    logic [16:0] score_ext;

    always_comb begin

        // Calculate absolute deviation from adaptive baseline
        if ({1'b0, delta_mag} >= {1'b0, baseline})
            deviation_ext =
                {1'b0, delta_mag} - {1'b0, baseline};
        else
            deviation_ext =
                {1'b0, baseline} - {1'b0, delta_mag};

        // Score = deviation + 2 * acceleration
        acceleration_x2 =
            {1'b0, acceleration} << 1;

        score_ext =
            deviation_ext + acceleration_x2;

    end

    always_ff @(posedge clk) begin

        if (rst) begin

            baseline <= 16'd0;
            deviation <= 16'd0;
            event_score <= 16'd0;
            event_type <= 2'b00;
            event_valid <= 1'b0;

            baseline_initialized <= 1'b0;

        end else begin

            // event_valid is a one-cycle pulse
            event_valid <= 1'b0;

            if (feature_valid) begin

                // ------------------------------------------------
                // First valid feature:
                // Initialize baseline without generating an event
                // ------------------------------------------------
                if (!baseline_initialized) begin

                    baseline <= delta_mag;

                    deviation <= 16'd0;
                    event_score <= 16'd0;
                    event_type <= 2'b00;
                    event_valid <= 1'b0;

                    baseline_initialized <= 1'b1;

                end else begin

                    // --------------------------------------------
                    // Normal RAESE operation
                    // --------------------------------------------

                    // Saturate deviation to 16 bits
                    if (deviation_ext > 17'h0FFFF)
                        deviation <= 16'hFFFF;
                    else
                        deviation <= deviation_ext[15:0];

                    // Saturate event score to 16 bits
                    if (score_ext > 17'h0FFFF)
                        event_score <= 16'hFFFF;
                    else
                        event_score <= score_ext[15:0];

                    // --------------------------------------------
                    // Event classification
                    //
                    // deviation < E_TH
                    //      -> NORMAL
                    //
                    // deviation >= E_TH AND
                    // acceleration > A_TH
                    //      -> SUDDEN
                    //
                    // deviation >= E_TH AND
                    // acceleration <= A_TH
                    //      -> GRADUAL
                    // --------------------------------------------

                    if (deviation_ext < {1'b0, e_threshold}) begin

                        event_type <= 2'b00;       // NORMAL

                    end else if (acceleration > a_threshold) begin

                        event_type <= 2'b10;       // SUDDEN

                    end else begin

                        event_type <= 2'b01;       // GRADUAL

                    end

                    event_valid <= 1'b1;

                    // --------------------------------------------
                    // Adaptive baseline update
                    // B_new = B_old + (delta - B_old)/8
                    // --------------------------------------------

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