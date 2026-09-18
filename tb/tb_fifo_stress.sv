`timescale 1ns/1ps

module tb_fifo_stress;

    localparam DATA_WIDTH = 16;
    localparam DEPTH      = 16;

    logic clk;
    logic rst;

    logic                  wr_en;
    logic [DATA_WIDTH-1:0]  wr_data;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0]  rd_data;
    logic                  full;
    logic                  empty;
    logic [4:0]            occupancy;

    integer i;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .PTR_WIDTH(4)
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .wr_en      (wr_en),
        .wr_data    (wr_data),
        .rd_en      (rd_en),
        .rd_data    (rd_data),
        .full       (full),
        .empty      (empty),
        .occupancy  (occupancy)
    );

    // ------------------------------------------------------------
    // Clock: 20 ns period
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Waveform dump
    // ------------------------------------------------------------
    initial begin
        $dumpfile("fifo_stress.vcd");
        $dumpvars(0, tb_fifo_stress);
    end

    // ------------------------------------------------------------
    // Monitor
    // ------------------------------------------------------------
    always @(posedge clk) begin
        #1;
        $display(
            "FIFO @ %0t ns | wr=%b data=%0d | rd=%b data=%0d | occ=%0d | full=%b | empty=%b",
            $time,
            wr_en,
            wr_data,
            rd_en,
            rd_data,
            occupancy,
            full,
            empty
        );
    end

    // ------------------------------------------------------------
    // TESTS
    // ------------------------------------------------------------
    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------
        rst     = 1'b1;
        wr_en   = 1'b0;
        wr_data = 16'd0;
        rd_en   = 1'b0;

        // Hold reset for two clock cycles
        repeat (2) @(posedge clk);
        #1;

        rst = 1'b0;

        // ========================================================
        // TEST 1: BURST WRITE
        // ========================================================
        $display("");
        $display("===============================================");
        $display("TEST 1: BURST WRITE");
        $display("===============================================");

        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            wr_en   = 1'b1;
            wr_data = i;

            @(posedge clk);
        end

        @(negedge clk);
        wr_en   = 1'b0;
        wr_data = 16'd0;

        @(posedge clk);
        #1;

        if (occupancy !== 5'd8) begin
            $display(
                "FAIL: expected occupancy 8, got %0d",
                occupancy
            );
            $finish;
        end

        $display("PASS: occupancy reached 8");


        // ========================================================
        // TEST 2: PARTIAL READ
        // ========================================================
        $display("");
        $display("===============================================");
        $display("TEST 2: PARTIAL READ");
        $display("===============================================");

        for (i = 0; i < 4; i = i + 1) begin

            @(negedge clk);
            rd_en = 1'b1;

            @(posedge clk);
            #1;

            if (rd_data !== i) begin
                $display(
                    "FAIL: expected %0d, got %0d",
                    i,
                    rd_data
                );
                $finish;
            end
        end

        @(negedge clk);
        rd_en = 1'b0;

        @(posedge clk);
        #1;

        if (occupancy !== 5'd4) begin
            $display(
                "FAIL: expected occupancy 4, got %0d",
                occupancy
            );
            $finish;
        end

        $display("PASS: 4 entries remain");


        // ========================================================
        // TEST 3: SIMULTANEOUS READ/WRITE
        // ========================================================
        $display("");
        $display("===============================================");
        $display("TEST 3: SIMULTANEOUS READ/WRITE");
        $display("===============================================");

        for (i = 0; i < 4; i = i + 1) begin

            @(negedge clk);

            wr_en   = 1'b1;
            wr_data = 8 + i;

            rd_en   = 1'b1;

            @(posedge clk);
            #1;

            // Old data must come out first
            if (rd_data !== (4 + i)) begin
                $display(
                    "FAIL: expected read %0d, got %0d",
                    4 + i,
                    rd_data
                );
                $finish;
            end

            // Occupancy must stay constant
            if (occupancy !== 5'd4) begin
                $display(
                    "FAIL: expected occupancy 4, got %0d",
                    occupancy
                );
                $finish;
            end
        end

        @(negedge clk);
        wr_en   = 1'b0;
        wr_data = 16'd0;
        rd_en   = 1'b0;

        @(posedge clk);
        #1;

        if (occupancy !== 5'd4) begin
            $display(
                "FAIL: expected occupancy 4, got %0d",
                occupancy
            );
            $finish;
        end

        $display("PASS: simultaneous read/write preserved FIFO ordering");


        // ========================================================
        // TEST 4: FILL TO CAPACITY
        // ========================================================
        $display("");
        $display("===============================================");
        $display("TEST 4: FILL TO CAPACITY");
        $display("===============================================");

        // Current FIFO contents:
        // 8, 9, 10, 11
        //
        // Add:
        // 12, 13, ..., 23
        //
        // Final contents:
        // 8,9,10,11,12,...,23
        //
        // Total = 16 entries

        for (i = 12; i <= 23; i = i + 1) begin

            @(negedge clk);

            wr_en   = 1'b1;
            wr_data = i;

            @(posedge clk);
        end

        @(negedge clk);
        wr_en   = 1'b0;
        wr_data = 16'd0;

        @(posedge clk);
        #1;

        if (occupancy !== 5'd16) begin
            $display(
                "FAIL: expected occupancy 16, got %0d",
                occupancy
            );
            $finish;
        end

        if (!full) begin
            $display("FAIL: full flag was not asserted");
            $finish;
        end

        $display("PASS: FIFO reached full capacity");


        // ========================================================
        // TEST 5: OVERFLOW PROTECTION
        // ========================================================
        $display("");
        $display("===============================================");
        $display("TEST 5: OVERFLOW PROTECTION");
        $display("===============================================");

        @(negedge clk);

        wr_en   = 1'b1;
        wr_data = 16'd999;
        rd_en   = 1'b0;

        @(posedge clk);
        #1;

        @(negedge clk);
        wr_en   = 1'b0;
        wr_data = 16'd0;

        @(posedge clk);
        #1;

        if (occupancy !== 5'd16) begin
            $display(
                "FAIL: overflow changed occupancy to %0d",
                occupancy
            );
            $finish;
        end

        if (!full) begin
            $display("FAIL: FIFO full flag dropped after overflow attempt");
            $finish;
        end

        $display("PASS: overflow prevented");


        // ========================================================
        // TEST 6: COMPLETE DRAIN
        // ========================================================
        $display("");
        $display("===============================================");
        $display("TEST 6: COMPLETE DRAIN");
        $display("===============================================");

        // FIFO currently contains:
        //
        // 8, 9, 10, 11, 12, 13, 14, 15,
        // 16,17,18,19,20,21,22,23
        //
        // Therefore drain must begin at 8.

        for (i = 8; i <= 23; i = i + 1) begin

            @(negedge clk);
            rd_en = 1'b1;

            @(posedge clk);
            #1;

            if (rd_data !== i) begin
                $display(
                    "FAIL: expected %0d, got %0d",
                    i,
                    rd_data
                );
                $finish;
            end
        end

        @(negedge clk);
        rd_en = 1'b0;

        @(posedge clk);
        #1;

        if (occupancy !== 5'd0) begin
            $display(
                "FAIL: expected occupancy 0, got %0d",
                occupancy
            );
            $finish;
        end

        if (!empty) begin
            $display("FAIL: empty flag was not asserted");
            $finish;
        end

        if (full) begin
            $display("FAIL: full flag remained asserted");
            $finish;
        end

        $display("PASS: FIFO completely drained");
        $display("");
        $display("===============================================");
        $display("ALL FIFO STRESS TESTS PASSED");
        $display("===============================================");

        #20;
        $finish;
    end

endmodule
