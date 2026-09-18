`timescale 1ns/1ps

module scheduler (
    input logic clk,
    input logic rst,

    input logic        event_valid,
    input logic [1:0]  event_type,
    input logic [15:0] event_score,

    input logic [4:0]  fifo_occupancy,

    input logic        mac_busy,
    input logic        mac_valid,

    output logic compute_start,
    output logic fifo_read,
    output logic mac_enable
);

    // Event types
    localparam NORMAL  = 2'b00;
    localparam GRADUAL = 2'b01;
    localparam SUDDEN  = 2'b10;

    // Scheduler states
    localparam IDLE       = 2'b00;
    localparam WAIT_READY = 2'b01;
    localparam ISSUE      = 2'b10;
    localparam WAIT_DONE  = 2'b11;

    logic [1:0] state;

    // One pending event can be remembered while
    // the current MAC operation is running.
    logic        pending_event;
    logic [15:0] pending_score;


    always @(posedge clk) begin

        if (rst) begin

            state <= IDLE;

            pending_event <= 1'b0;
            pending_score <= 16'd0;

            compute_start <= 1'b0;
            fifo_read     <= 1'b0;
            mac_enable    <= 1'b0;

        end else begin

            // Default: all control outputs are one-cycle pulses.
            compute_start <= 1'b0;
            fifo_read     <= 1'b0;
            mac_enable    <= 1'b0;

            case (state)

                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    if (event_valid &&
                        ((event_type == GRADUAL) ||
                         (event_type == SUDDEN))) begin

                        pending_event <= 1'b1;
                        pending_score <= event_score;

                        state <= WAIT_READY;

                    end

                end


                // =================================================
                // WAIT_READY
                //
                // Wait for:
                //   1. FIFO to contain data
                //   2. MAC to be free
                // =================================================

                WAIT_READY: begin

                    if (pending_event &&
                        (fifo_occupancy != 5'd0) &&
                        !mac_busy) begin

                        state <= ISSUE;

                    end

                end


                // =================================================
                // ISSUE
                //
                // Start one computation.
                // =================================================

                ISSUE: begin

                    compute_start <= 1'b1;
                    fifo_read     <= 1'b1;
                    mac_enable    <= 1'b1;

                    pending_event <= 1'b0;

                    state <= WAIT_DONE;

                end


                // =================================================
                // WAIT_DONE
                //
                // Current MAC operation is running.
                //
                // A new GRADUAL/SUDDEN event can be remembered.
                // The current operation finishes when mac_valid=1.
                // =================================================

                WAIT_DONE: begin

                    // Capture one new event while MAC is working.
                    if (event_valid &&
                        ((event_type == GRADUAL) ||
                         (event_type == SUDDEN)) &&
                        !pending_event) begin

                        pending_event <= 1'b1;
                        pending_score <= event_score;

                    end

                    // Current MAC operation completed.
                    if (mac_valid) begin

                        // If another event is waiting, process it next.
                        if (pending_event) begin

                            state <= WAIT_READY;

                        end else if (event_valid &&
                                     ((event_type == GRADUAL) ||
                                      (event_type == SUDDEN))) begin

                            // Also handle a new event arriving on
                            // the same clock as mac_valid.
                            state <= WAIT_READY;

                        end else begin

                            state <= IDLE;

                        end

                    end

                end


                // =================================================
                // DEFAULT
                // =================================================

                default: begin

                    state <= IDLE;

                    pending_event <= 1'b0;
                    pending_score <= 16'd0;

                end

            endcase

        end

    end

endmodule
