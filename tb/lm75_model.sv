`timescale 1ns/1ps

module lm75_model #(
    parameter integer SAMPLE_INTERVAL = 10,
    parameter integer SCENARIO = 0
)(
    input  logic clk,
    input  logic rst,

    output logic signed [15:0] temperature,
    output logic               sample_valid
);

    // ============================================================
    // Scenario selection
    //
    // 0 = Stable
    // 1 = Gradual heating
    // 2 = Sudden event
    // 3 = Noisy
    // ============================================================

    integer sample_count;
    integer interval_count;

    // ============================================================
    // Temperature generation
    //
    // Internal format = signed Q8.8
    //
    // 25.0 C = 25 * 256 = 6400
    // 25.5 C = 6528
    // 26.0 C = 6656
    // etc.
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            temperature  <= 16'sd6400;   // 25.0 C
            sample_valid <= 1'b0;

            sample_count  <= 0;
            interval_count <= 0;

        end else begin

            // Default: sample_valid is a one-cycle pulse.
            sample_valid <= 1'b0;

            if (interval_count == SAMPLE_INTERVAL - 1) begin

                interval_count <= 0;

                sample_valid <= 1'b1;

                case (SCENARIO)

                    // =================================================
                    // SCENARIO 0: STABLE
                    // =================================================

                    0: begin

                        case (sample_count)

                            0: temperature <= 16'sd6400; // 25.0
                            1: temperature <= 16'sd6400; // 25.0
                            2: temperature <= 16'sd6400; // 25.0
                            3: temperature <= 16'sd6400; // 25.0
                            4: temperature <= 16'sd6528; // 25.5
                            5: temperature <= 16'sd6400; // 25.0
                            6: temperature <= 16'sd6400; // 25.0
                            7: temperature <= 16'sd6400; // 25.0

                            default:
                                temperature <= 16'sd6400;

                        endcase

                    end

                    // =================================================
                    // SCENARIO 1: GRADUAL HEATING
                    // =================================================

                    1: begin

                        case (sample_count)

                            0: temperature <= 16'sd6400; // 25.0
                            1: temperature <= 16'sd6528; // 25.5
                            2: temperature <= 16'sd6656; // 26.0
                            3: temperature <= 16'sd6784; // 26.5
                            4: temperature <= 16'sd6912; // 27.0
                            5: temperature <= 16'sd7040; // 27.5
                            6: temperature <= 16'sd7168; // 28.0
                            7: temperature <= 16'sd7296; // 28.5

                            default:
                                temperature <= 16'sd7296;

                        endcase

                    end

                    // =================================================
                    // SCENARIO 2: SUDDEN EVENT
                    // =================================================

                    2: begin

                        case (sample_count)

                            0: temperature <= 16'sd6400; // 25.0
                            1: temperature <= 16'sd6400; // 25.0
                            2: temperature <= 16'sd6528; // 25.5
                            3: temperature <= 16'sd6528; // 25.5
                            4: temperature <= 16'sd6528; // 25.5
                            5: temperature <= 16'sd8064; // 31.5
                            6: temperature <= 16'sd8064; // 31.5
                            7: temperature <= 16'sd8064; // 31.5

                            default:
                                temperature <= 16'sd8064;

                        endcase

                    end

                    // =================================================
                    // SCENARIO 3: NOISY
                    // =================================================

                    3: begin

                        case (sample_count)

                            0: temperature <= 16'sd6400; // 25.0
                            1: temperature <= 16'sd6528; // 25.5
                            2: temperature <= 16'sd6272; // 24.5
                            3: temperature <= 16'sd6528; // 25.5
                            4: temperature <= 16'sd6272; // 24.5
                            5: temperature <= 16'sd6400; // 25.0
                            6: temperature <= 16'sd6528; // 25.5
                            7: temperature <= 16'sd6400; // 25.0

                            default:
                                temperature <= 16'sd6400;

                        endcase

                    end

                    default: begin
                        temperature <= 16'sd6400;
                    end

                endcase

                if (sample_count < 7)
                    sample_count <= sample_count + 1;
                else
                    sample_count <= 7;

            end else begin

                interval_count <= interval_count + 1;

            end

        end
    end

endmodule
