`timescale 1ns/1ps

module feature_extract (
    input  logic               clk,
    input  logic               rst,

    input  logic signed [15:0] temperature,
    input  logic               sample_valid,

    output logic signed [15:0] delta,
    output logic        [15:0] delta_mag,
    output logic        [15:0] acceleration,
    output logic               feature_valid
);

    // Previous-sample state
    logic signed [15:0] previous_temperature;
    logic        [15:0] previous_delta_mag;
    logic               have_previous;

    // Intermediate arithmetic
    logic signed [16:0] delta_temp_ext;
    logic        [16:0] delta_mag_ext;
    logic        [16:0] acceleration_ext;


    // ------------------------------------------------------------
    // Combinational feature calculation
    // ------------------------------------------------------------

    always_comb begin

        // Sign-extend both temperatures to 17 bits
        delta_temp_ext =
            $signed({temperature[15], temperature}) -
            $signed({previous_temperature[15], previous_temperature});

        // Absolute value of delta
        if (delta_temp_ext < 0)
            delta_mag_ext = $unsigned(-delta_temp_ext);
        else
            delta_mag_ext = $unsigned(delta_temp_ext);

        // Acceleration = |current delta magnitude
        //                  - previous delta magnitude|
        if (delta_mag_ext >= {1'b0, previous_delta_mag})
            acceleration_ext =
                delta_mag_ext - {1'b0, previous_delta_mag};
        else
            acceleration_ext =
                {1'b0, previous_delta_mag} - delta_mag_ext;

    end


    // ------------------------------------------------------------
    // Sequential state and outputs
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            previous_temperature <= '0;
            previous_delta_mag   <= '0;
            have_previous        <= 1'b0;

            delta                <= '0;
            delta_mag            <= '0;
            acceleration         <= '0;
            feature_valid        <= 1'b0;

        end

        else begin

            // Default: no new feature set
            feature_valid <= 1'b0;

            if (sample_valid) begin

                // --------------------------------------------
                // First sample
                // --------------------------------------------

                if (!have_previous) begin

                    previous_temperature <= temperature;
                    previous_delta_mag   <= '0;
                    have_previous        <= 1'b1;

                    delta                <= '0;
                    delta_mag            <= '0;
                    acceleration         <= '0;

                end

                // --------------------------------------------
                // Subsequent samples
                // --------------------------------------------

                else begin

                    // Store calculated features
                    delta        <= $signed(delta_temp_ext[15:0]);
                    delta_mag    <= delta_mag_ext[15:0];
                    acceleration <= acceleration_ext[15:0];

                    // Update state for next sample
                    previous_temperature <= temperature;
                    previous_delta_mag   <= delta_mag_ext[15:0];

                    // Tell RAESE that these outputs are valid
                    feature_valid <= 1'b1;

                end

            end

        end

    end

endmodule