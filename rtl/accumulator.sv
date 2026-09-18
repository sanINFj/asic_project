`timescale 1ns/1ps

module accumulator #(
    parameter integer NUM_MAC = 4
)(
    input logic clk,
    input logic rst,

    input logic enable,
    input logic clear,

    input logic signed [NUM_MAC*16-1:0] product,

    output logic signed [31:0] accumulated_value,
    output logic valid
);

    // ============================================================
    // Sum of NUM_MAC signed 16-bit products.
    //
    // For 4 MACs, 18 bits are sufficient:
    //
    // 16-bit + 16-bit + 16-bit + 16-bit
    //            -> 18-bit sum
    // ============================================================

    logic signed [17:0] product_sum;

    integer i;

    always_comb begin

        product_sum = 18'sd0;

        for (i = 0; i < NUM_MAC; i = i + 1) begin

            product_sum =
                product_sum +
                $signed(product[i*16 +: 16]);

        end

    end

    // ============================================================
    // Accumulator
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            accumulated_value <= 32'sd0;
            valid <= 1'b0;

        end else begin

            valid <= 1'b0;

            if (clear) begin

                accumulated_value <= 32'sd0;

            end else if (enable) begin

                accumulated_value <=
                    accumulated_value + product_sum;

                valid <= 1'b1;

            end

        end

    end

endmodule
