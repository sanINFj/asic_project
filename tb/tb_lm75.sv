`timescale 1ns/1ps

module tb_lm75;

    logic clk;
    logic rst;

    logic signed [15:0] temperature;
    logic sample_valid;

    // ============================================================
    // Clock: 50 MHz
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ============================================================
    // LM75 model
    //
    // Change SCENARIO here:
    //
    // 0 = stable
    // 1 = gradual
    // 2 = sudden
    // 3 = noisy
    // ============================================================

    lm75_model #(
        .SAMPLE_INTERVAL(10),
        .SCENARIO(2)
    ) sensor (
        .clk          (clk),
        .rst          (rst),
        .temperature  (temperature),
        .sample_valid (sample_valid)
    );

    // ============================================================
    // Test
    // ============================================================

    initial begin

        rst = 1'b1;

        repeat (5)
            @(posedge clk);

        rst = 1'b0;

        // Run long enough to observe all 8 samples.
        repeat (100)
            @(posedge clk);

        $display("");
        $display("LM75 MODEL TEST COMPLETED");

        $finish;

    end

    // ============================================================
    // Monitor
    // ============================================================

    always @(posedge clk) begin

        if (sample_valid) begin

            $display(
                "time=%0t ns | sample_valid=1 | temperature=%0d | temp_C=%0.1f",
                $time,
                temperature,
                $itor($signed(temperature)) / 256.0
            );

        end

    end

    // ============================================================
    // Waveform
    // ============================================================

    initial begin

        $dumpfile("lm75.vcd");
        $dumpvars(0, tb_lm75);

    end

endmodule
