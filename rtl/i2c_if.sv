`timescale 1ns/1ps

module i2c_if #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer I2C_FREQ_HZ = 100_000,
    parameter logic [6:0] I2C_ADDR = 7'h48
)(
    input  logic clk,
    input logic rst,

    // I2C
    inout  wire sda,
    output logic scl,

    // Temperature output in signed Q8.8
    output logic signed [15:0] temperature,
    output logic sample_valid,

    // Start one temperature read
    input logic start,

    // Status
    output logic busy,
    output logic done,
    output logic error
);

    // ============================================================
    // I2C timing
    // ============================================================

    localparam integer HALF_PERIOD =
        CLK_FREQ_HZ / (2 * I2C_FREQ_HZ);

    integer clk_count;
    logic i2c_tick;

    always_ff @(posedge clk) begin
        if (rst) begin
            clk_count <= 0;
            i2c_tick  <= 1'b0;
        end else begin
            if (clk_count == HALF_PERIOD - 1) begin
                clk_count <= 0;
                i2c_tick  <= 1'b1;
            end else begin
                clk_count <= clk_count + 1;
                i2c_tick  <= 1'b0;
            end
        end
    end

    // ============================================================
    // Open-drain SDA
    //
    // 0 -> actively pull SDA low
    // 1 -> release SDA
    // ============================================================

    logic sda_drive_low;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    wire sda_in = sda;

    // ============================================================
    // FSM
    // ============================================================

    localparam logic [5:0]
        ST_IDLE             = 6'd0,

        // START
        ST_START_LOW        = 6'd1,
        ST_START_DROP       = 6'd2,

        // WRITE ADDRESS
        ST_TX_LOW           = 6'd3,
        ST_TX_HIGH          = 6'd4,
        ST_TX_SAMPLE        = 6'd5,

        // ACK from slave
        ST_ACK_LOW          = 6'd6,
        ST_ACK_HIGH         = 6'd7,
        ST_ACK_SAMPLE       = 6'd8,

        // Pointer byte
        ST_PTR_LOW          = 6'd9,
        ST_PTR_HIGH         = 6'd10,
        ST_PTR_SAMPLE       = 6'd11,

        // ACK pointer
        ST_PTR_ACK_LOW      = 6'd12,
        ST_PTR_ACK_HIGH     = 6'd13,
        ST_PTR_ACK_SAMPLE   = 6'd14,

        // Repeated START
        ST_RESTART_LOW      = 6'd15,
        ST_RESTART_HIGH     = 6'd16,

        // READ ADDRESS
        ST_RXADDR_LOW       = 6'd17,
        ST_RXADDR_HIGH      = 6'd18,
        ST_RXADDR_SAMPLE    = 6'd19,

        // ACK read address
        ST_RXADDR_ACK_LOW   = 6'd20,
        ST_RXADDR_ACK_HIGH  = 6'd21,
        ST_RXADDR_ACK_SAMPLE= 6'd22,

        // Read MSB
        ST_READ_MSB_LOW     = 6'd23,
        ST_READ_MSB_HIGH    = 6'd24,
        ST_READ_MSB_SAMPLE  = 6'd25,

        // Master ACK
        ST_MASTER_ACK_LOW   = 6'd26,
        ST_MASTER_ACK_HIGH  = 6'd27,
        ST_MASTER_ACK_DONE  = 6'd28,

        // Read LSB
        ST_READ_LSB_LOW     = 6'd29,
        ST_READ_LSB_HIGH    = 6'd30,
        ST_READ_LSB_SAMPLE  = 6'd31,

        // Master NACK
        ST_MASTER_NACK_LOW  = 6'd32,
        ST_MASTER_NACK_HIGH = 6'd33,
        ST_MASTER_NACK_DONE = 6'd34,

        // STOP
        ST_STOP_LOW         = 6'd35,
        ST_STOP_HIGH        = 6'd36,
        ST_STOP_DONE        = 6'd37,

        ST_ERROR            = 6'd38;

    logic [5:0] state;

    // ============================================================
    // Transaction registers
    // ============================================================

    logic [7:0] tx_byte;

    logic [7:0] rx_msb;
    logic [7:0] rx_lsb;

    logic [3:0] bit_count;

    // ============================================================
    // Main FSM
    // ============================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            state         <= ST_IDLE;

            scl           <= 1'b1;
            sda_drive_low <= 1'b0;

            tx_byte       <= 8'h00;
            rx_msb        <= 8'h00;
            rx_lsb        <= 8'h00;

            bit_count     <= 4'd0;

            temperature   <= 16'sd0;
            sample_valid  <= 1'b0;

            busy          <= 1'b0;
            done          <= 1'b0;
            error         <= 1'b0;

        end else begin

            // These are pulses.
            sample_valid <= 1'b0;
            done         <= 1'b0;

            // ====================================================
            // IDLE
            // ====================================================

            if (state == ST_IDLE) begin

                scl           <= 1'b1;
                sda_drive_low <= 1'b0;

                if (start) begin

                    busy  <= 1'b1;
                    error <= 1'b0;

                    // Prepare START:
                    // SDA will go LOW while SCL is HIGH.
                    state <= ST_START_LOW;
                end
            end

            // ====================================================
            // START
            // ====================================================

            else if ((state == ST_START_LOW) && i2c_tick) begin

                // START condition
                sda_drive_low <= 1'b1;
                scl           <= 1'b1;

                state <= ST_START_DROP;
            end

            else if ((state == ST_START_DROP) && i2c_tick) begin

                // Enter normal I2C low phase.
                scl <= 1'b0;

                tx_byte   <= {I2C_ADDR, 1'b0};
                bit_count <= 4'd7;

                state <= ST_TX_LOW;
            end

            // ====================================================
            // WRITE BYTE
            // ====================================================

            else if ((state == ST_TX_LOW) && i2c_tick) begin

                scl <= 1'b0;

                if (tx_byte[bit_count])
                    sda_drive_low <= 1'b0;
                else
                    sda_drive_low <= 1'b1;

                state <= ST_TX_HIGH;
            end

            else if ((state == ST_TX_HIGH) && i2c_tick) begin

                // Rising edge of SCL.
                scl <= 1'b1;

                state <= ST_TX_SAMPLE;
            end

            else if ((state == ST_TX_SAMPLE) && i2c_tick) begin

                // Finish this bit.
                scl <= 1'b0;

                if (bit_count == 0) begin
                    state <= ST_ACK_LOW;
                end else begin
                    bit_count <= bit_count - 1'b1;
                    state <= ST_TX_LOW;
                end
            end

            // ====================================================
            // SLAVE ACK
            // ====================================================

            else if ((state == ST_ACK_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                state <= ST_ACK_HIGH;
            end

            else if ((state == ST_ACK_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_ACK_SAMPLE;
            end

            else if ((state == ST_ACK_SAMPLE) && i2c_tick) begin

                scl <= 1'b0;

                if (sda_in == 1'b0) begin

                    tx_byte   <= 8'h00;
                    bit_count <= 4'd7;

                    state <= ST_PTR_LOW;

                end else begin

                    state <= ST_ERROR;

                end
            end

            // ====================================================
            // WRITE TEMPERATURE REGISTER POINTER = 0x00
            // ====================================================

            else if ((state == ST_PTR_LOW) && i2c_tick) begin

                scl <= 1'b0;

                if (tx_byte[bit_count])
                    sda_drive_low <= 1'b0;
                else
                    sda_drive_low <= 1'b1;

                state <= ST_PTR_HIGH;
            end

            else if ((state == ST_PTR_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_PTR_SAMPLE;
            end

            else if ((state == ST_PTR_SAMPLE) && i2c_tick) begin

                scl <= 1'b0;

                if (bit_count == 0) begin
                    state <= ST_PTR_ACK_LOW;
                end else begin
                    bit_count <= bit_count - 1'b1;
                    state <= ST_PTR_LOW;
                end
            end

            // ====================================================
            // POINTER ACK
            // ====================================================

            else if ((state == ST_PTR_ACK_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                state <= ST_PTR_ACK_HIGH;
            end

            else if ((state == ST_PTR_ACK_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_PTR_ACK_SAMPLE;
            end

            else if ((state == ST_PTR_ACK_SAMPLE) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                if (sda_in == 1'b0) begin
                    state <= ST_RESTART_LOW;
                end else begin
                    state <= ST_ERROR;
                end
            end

            // ====================================================
            // REPEATED START
            // ====================================================

            else if ((state == ST_RESTART_LOW) && i2c_tick) begin

                // SCL is LOW here.
                // Release SDA first.
                sda_drive_low <= 1'b0;
                scl           <= 1'b0;

                state <= ST_RESTART_HIGH;
            end

            else if ((state == ST_RESTART_HIGH) && i2c_tick) begin

                // SCL HIGH, SDA HIGH
                scl           <= 1'b1;

                // Next state will pull SDA low to create
                // the repeated START.
                sda_drive_low <= 1'b1;

                tx_byte   <= {I2C_ADDR, 1'b1};
                bit_count <= 4'd7;

                state <= ST_RXADDR_LOW;
            end

            // ====================================================
            // READ ADDRESS
            // ====================================================

            else if ((state == ST_RXADDR_LOW) && i2c_tick) begin

                scl <= 1'b0;

                if (tx_byte[bit_count])
                    sda_drive_low <= 1'b0;
                else
                    sda_drive_low <= 1'b1;

                state <= ST_RXADDR_HIGH;
            end

            else if ((state == ST_RXADDR_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_RXADDR_SAMPLE;
            end

            else if ((state == ST_RXADDR_SAMPLE) && i2c_tick) begin

                scl <= 1'b0;

                if (bit_count == 0) begin
                    state <= ST_RXADDR_ACK_LOW;
                end else begin
                    bit_count <= bit_count - 1'b1;
                    state <= ST_RXADDR_LOW;
                end
            end

            // ====================================================
            // READ ADDRESS ACK
            // ====================================================

            else if ((state == ST_RXADDR_ACK_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                state <= ST_RXADDR_ACK_HIGH;
            end

            else if ((state == ST_RXADDR_ACK_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_RXADDR_ACK_SAMPLE;
            end

            else if ((state == ST_RXADDR_ACK_SAMPLE) && i2c_tick) begin

                scl <= 1'b0;

                if (sda_in == 1'b0) begin

                    bit_count <= 4'd7;
                    rx_msb    <= 8'h00;

                    state <= ST_READ_MSB_LOW;

                end else begin

                    state <= ST_ERROR;

                end
            end

            // ====================================================
            // READ MSB
            // ====================================================

            else if ((state == ST_READ_MSB_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                state <= ST_READ_MSB_HIGH;
            end

            else if ((state == ST_READ_MSB_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_READ_MSB_SAMPLE;
            end

            else if ((state == ST_READ_MSB_SAMPLE) && i2c_tick) begin

                // Sample while SCL is HIGH.
                rx_msb[bit_count] <= sda_in;

                scl <= 1'b0;

                if (bit_count == 0) begin
                    state <= ST_MASTER_ACK_LOW;
                end else begin
                    bit_count <= bit_count - 1'b1;
                    state <= ST_READ_MSB_LOW;
                end
            end

            // ====================================================
            // MASTER ACK AFTER MSB
            // ====================================================

            else if ((state == ST_MASTER_ACK_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b1;

                state <= ST_MASTER_ACK_HIGH;
            end

            else if ((state == ST_MASTER_ACK_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_MASTER_ACK_DONE;
            end

            else if ((state == ST_MASTER_ACK_DONE) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                bit_count <= 4'd7;
                rx_lsb    <= 8'h00;

                state <= ST_READ_LSB_LOW;
            end

            // ====================================================
            // READ LSB
            // ====================================================

            else if ((state == ST_READ_LSB_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                state <= ST_READ_LSB_HIGH;
            end

            else if ((state == ST_READ_LSB_HIGH) && i2c_tick) begin

                scl <= 1'b1;

                state <= ST_READ_LSB_SAMPLE;
            end

            else if ((state == ST_READ_LSB_SAMPLE) && i2c_tick) begin

                rx_lsb[bit_count] <= sda_in;

                scl <= 1'b0;

                if (bit_count == 0) begin
                    state <= ST_MASTER_NACK_LOW;
                end else begin
                    bit_count <= bit_count - 1'b1;
                    state <= ST_READ_LSB_LOW;
                end
            end

            // ====================================================
            // MASTER NACK AFTER FINAL BYTE
            // ====================================================

            else if ((state == ST_MASTER_NACK_LOW) && i2c_tick) begin

                scl           <= 1'b0;
                sda_drive_low <= 1'b0;

                state <= ST_MASTER_NACK_HIGH;
            end

            else if ((state == ST_MASTER_NACK_HIGH) && i2c_tick) begin

                // NACK = SDA released while SCL HIGH.
                scl           <= 1'b1;
                sda_drive_low <= 1'b0;

                state <= ST_MASTER_NACK_DONE;
            end

            else if ((state == ST_MASTER_NACK_DONE) && i2c_tick) begin

                scl <= 1'b0;

                // LM75 temperature:
                //
                // raw = {MSB[7:0], LSB[7]}
                //
                // This is signed 9-bit, 0.5 C / LSB.
                //
                // Convert to Q8.8:
                // 0.5 C = 128 = 16'h0080
                //
                // Therefore raw << 7.

                temperature <=
                    $signed({
                        {7{rx_msb[7]}},
                        rx_msb,
                        rx_lsb[7]
                    }) <<< 7;

                sample_valid <= 1'b1;

                state <= ST_STOP_LOW;
            end

            // ====================================================
            // STOP
            // ====================================================

            else if ((state == ST_STOP_LOW) && i2c_tick) begin

                // SDA LOW while SCL LOW.
                sda_drive_low <= 1'b1;
                scl           <= 1'b0;

                state <= ST_STOP_HIGH;
            end

            else if ((state == ST_STOP_HIGH) && i2c_tick) begin

                // Raise SCL while SDA remains LOW.
                scl <= 1'b1;

                state <= ST_STOP_DONE;
            end

            else if ((state == ST_STOP_DONE) && i2c_tick) begin

                // SDA LOW -> HIGH while SCL HIGH = STOP.
                scl           <= 1'b1;
                sda_drive_low <= 1'b0;

                busy <= 1'b0;
                done <= 1'b1;

                state <= ST_IDLE;
            end

            // ====================================================
            // ERROR
            // ====================================================

            else if (state == ST_ERROR) begin

                scl           <= 1'b1;
                sda_drive_low <= 1'b0;

                busy  <= 1'b0;
                error <= 1'b1;

                state <= ST_IDLE;
            end

        end
    end

endmodule
