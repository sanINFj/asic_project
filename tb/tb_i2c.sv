`timescale 1ns/1ps

module tb_i2c;

    // ============================================================
    // Clock
    // ============================================================

    logic clk;
    logic rst;

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;       // 50 MHz
    end

    // ============================================================
    // I2C bus
    // ============================================================

    tri sda;
    logic scl;

    pullup(sda);

    // ============================================================
    // I2C interface signals
    // ============================================================

    logic start;

    logic signed [15:0] temperature;
    logic sample_valid;

    logic busy;
    logic done;
    logic error;

    // LM75 temperature in units of 0.5 C
    integer temperature_half_c;

    // ============================================================
    // DUT
    // ============================================================

    i2c_if #(
        .CLK_FREQ_HZ(50_000_000),
        .I2C_FREQ_HZ(100_000),
        .I2C_ADDR(7'h48)
    ) dut (
        .clk            (clk),
        .rst            (rst),

        .sda            (sda),
        .scl            (scl),

        .temperature    (temperature),
        .sample_valid   (sample_valid),

        .start          (start),

        .busy           (busy),
        .done           (done),
        .error          (error)
    );

    // ============================================================
    // LM75 behavioral model
    // ============================================================

    lm75_model #(
        .I2C_ADDR(7'h48)
    ) sensor (
        .clk                (clk),
        .sda                (sda),
        .scl                (scl),
        .temperature_half_c (temperature_half_c)
    );

    // ============================================================
    // Expected Q8.8 conversion
    // ============================================================

    function automatic signed [15:0] temp_to_q8_8(
        input integer half_c
    );

        begin
            // 0.5 C = 128 in Q8.8
            temp_to_q8_8 = half_c * 128;
        end

    endfunction

    // ============================================================
    // Run one I2C temperature transaction
    // ============================================================

    task automatic read_temperature(
        input integer half_c,
        input integer test_number
    );

        integer timeout;
        reg signed [15:0] expected;

        begin

            expected = temp_to_q8_8(half_c);

            temperature_half_c = half_c;

            $display("");
            $display("================================================");
            $display("TEST %0d", test_number);
            $display("LM75 temperature = %0.1f C",
                     half_c / 2.0);
            $display("Expected Q8.8    = %0d (0x%04h)",
                     expected,
                     expected);
            $display("================================================");

            // ----------------------------------------------------
            // Start transaction
            // ----------------------------------------------------

            @(negedge clk);
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            // ----------------------------------------------------
            // Wait for sample_valid
            // ----------------------------------------------------

            timeout = 0;

            while (!sample_valid && timeout < 500000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 500000) begin

                $display("TEST %0d FAILED: timeout", test_number);

            end

            else if (error) begin

                $display("TEST %0d FAILED: I2C error",
                         test_number);

            end

            else if (temperature !== expected) begin

                $display("TEST %0d FAILED", test_number);
                $display("Expected temperature = %0d (0x%04h)",
                         expected,
                         expected);
                $display("Actual temperature   = %0d (0x%04h)",
                         temperature,
                         temperature);

            end

            else begin

                $display("TEST %0d PASSED", test_number);
                $display("temperature = %0d (0x%04h)",
                         temperature,
                         temperature);

            end

            // Give transaction time to finish.
            repeat (20)
                @(posedge clk);

        end

    endtask

    // ============================================================
    // Main test
    // ============================================================

    initial begin

        rst = 1'b1;
        start = 1'b0;

        temperature_half_c = 50;      // 25.0 C

        repeat (5)
            @(posedge clk);

        rst = 1'b0;

        // --------------------------------------------------------
        // Test temperatures
        // --------------------------------------------------------

        read_temperature(50,  1);     // 25.0 C
        read_temperature(51,  2);     // 25.5 C
        read_temperature(54,  3);     // 27.0 C
        read_temperature(52,  4);     // 26.0 C
        read_temperature(60,  5);     // 30.0 C

        $display("");
        $display("===============================================");
        $display("ALL I2C TESTS COMPLETED");
        $display("===============================================");

        $finish;

    end

    // ============================================================
    // Waveform dump
    // ============================================================

    initial begin

        $dumpfile("i2c.vcd");

        $dumpvars(0, tb_i2c);

    end

endmodule
