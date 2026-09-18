`timescale 1ns/1ps

module sparse_encoder (
    input logic clk,
    input logic rst,

    input logic        event_valid,
    input logic [1:0]  event_type,

    input logic signed [15:0] delta,
    input logic [15:0] acceleration,
    input logic [15:0] deviation,
    input logic [15:0] event_score,

    output logic signed [7:0] feature_0,
    output logic signed [7:0] feature_1,
    output logic signed [7:0] feature_2,
    output logic signed [7:0] feature_3,

    output logic feature_valid
);


    // ============================================================
    // Event types
    // ============================================================

    localparam logic [1:0] EVENT_NORMAL  = 2'b00;
    localparam logic [1:0] EVENT_GRADUAL = 2'b01;
    localparam logic [1:0] EVENT_SUDDEN  = 2'b10;


    // ============================================================
    // Q8.8 → signed 8-bit feature
    //
    // One MAC unit represents 0.5°C.
    //
    // Therefore:
    //
    //     feature = Q8.8_value / 128
    //
    // Examples:
    //
    //     128  -> 1  (0.5°C)
    //     256  -> 2  (1.0°C)
    //     1536 -> 12 (6.0°C)
    //
    // Saturates to the signed 8-bit range [-128, +127].
    // ============================================================

    function automatic logic signed [7:0] quantize_signed_q8_8(
        input logic signed [15:0] value
    );

        integer signed temp;

        begin

            temp = value >>> 7;

            if (temp > 127)
                quantize_signed_q8_8 = 8'sd127;

            else if (temp < -128)
                quantize_signed_q8_8 = -8'sd128;

            else
                quantize_signed_q8_8 = temp;

        end

    endfunction


    // ============================================================
    // Q8.8 → unsigned magnitude represented as signed 8-bit
    //
    // Used for acceleration, deviation and event_score.
    //
    // Values above 127 saturate at +127.
    // ============================================================

    function automatic logic signed [7:0] quantize_unsigned_q8_8(
        input logic [15:0] value
    );

        integer unsigned temp;

        begin

            temp = value >> 7;

            if (temp > 127)
                quantize_unsigned_q8_8 = 8'sd127;

            else
                quantize_unsigned_q8_8 = temp;

        end

    endfunction


    // ============================================================
    // Sparse encoding
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            feature_0 <= 8'sd0;
            feature_1 <= 8'sd0;
            feature_2 <= 8'sd0;
            feature_3 <= 8'sd0;

            feature_valid <= 1'b0;

        end else begin

            // One-cycle valid pulse.
            feature_valid <= 1'b0;


            // Only meaningful events enter the compute path.
            //
            // NORMAL events are discarded.
            //

            if (event_valid) begin

                if (
                    (event_type == EVENT_GRADUAL) ||
                    (event_type == EVENT_SUDDEN)
                ) begin

                    // ------------------------------------------------
                    // Feature 0 = signed temperature change
                    // ------------------------------------------------

                    feature_0 <=
                        quantize_signed_q8_8(delta);


                    // ------------------------------------------------
                    // Feature 1 = acceleration magnitude
                    // ------------------------------------------------

                    feature_1 <=
                        quantize_unsigned_q8_8(acceleration);


                    // ------------------------------------------------
                    // Feature 2 = deviation from adaptive baseline
                    // ------------------------------------------------

                    feature_2 <=
                        quantize_unsigned_q8_8(deviation);


                    // ------------------------------------------------
                    // Feature 3 = RAESE event score
                    // ------------------------------------------------

                    feature_3 <=
                        quantize_unsigned_q8_8(event_score);


                    feature_valid <= 1'b1;

                end

            end

        end

    end

endmodule
