module fifo #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 16,
    parameter PTR_WIDTH  = 4
)(
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    output logic                  full,
    output logic                  empty,

    output logic [4:0]            occupancy
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_ptr;
    logic [PTR_WIDTH-1:0] rd_ptr;

    always_ff @(posedge clk) begin

        if (rst) begin
            wr_ptr    <= '0;
            rd_ptr    <= '0;
            occupancy <= '0;
            rd_data   <= '0;
        end

        else begin

            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end

            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= rd_ptr + 1'b1;
            end

            case ({wr_en && !full, rd_en && !empty})

                2'b10:
                    occupancy <= occupancy + 1'b1;

                2'b01:
                    occupancy <= occupancy - 1'b1;

                default:
                    occupancy <= occupancy;

            endcase
        end
    end

    assign empty = (occupancy == 0);
    assign full  = (occupancy == DEPTH);

endmodule