`timescale 1ns/1ps

module mac_array #(
    parameter NUM_MAC = 4
)(
    input logic clk,
    input logic rst,
    input logic enable,

    // Four signed 8-bit operands packed into one bus
    input logic signed [NUM_MAC*8-1:0] data,
    input logic signed [NUM_MAC*8-1:0] weight,

    // Four signed 16-bit products packed into one bus
    output logic signed [NUM_MAC*16-1:0] product,

    output logic valid
);

    integer i;

    always_ff @(posedge clk) begin

        if (rst) begin

            valid <= 1'b0;
            product <= '0;

        end else begin

            valid <= 1'b0;

            if (enable) begin

                for (i = 0; i < NUM_MAC; i = i + 1) begin

                    product[i*16 +: 16] <=
                        $signed(data[i*8 +: 8]) *
                        $signed(weight[i*8 +: 8]);

                end

                valid <= 1'b1;
            end
        end
    end

endmodule
