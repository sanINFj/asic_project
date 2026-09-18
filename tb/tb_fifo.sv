`timescale 1ns/1ps

module tb_fifo;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter DEPTH      = 16;

    // Clock and reset
    logic clk;
    logic rst;

    // FIFO inputs
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;

    logic                  rd_en;

    // FIFO outputs
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  full;
    logic                  empty;
    logic [4:0]            occupancy;

    // ------------------------------------------------
    // DUT: FIFO
    // ------------------------------------------------
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),

        .wr_en(wr_en),
        .wr_data(wr_data),

        .rd_en(rd_en),
        .rd_data(rd_data),

        .full(full),
        .empty(empty),
        .occupancy(occupancy)
    );

    // ------------------------------------------------
    // Clock generation
    // 10 ns period
    // ------------------------------------------------
    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ------------------------------------------------
    // VCD waveform dump
    // ------------------------------------------------
    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, tb_fifo);
    end

    // ------------------------------------------------
    // Monitor
    // ------------------------------------------------
    initial begin
        $monitor(
            "TIME=%0t | rst=%b | wr_en=%b | wr_data=%0d | rd_en=%b | rd_data=%0d | occupancy=%0d | full=%b | empty=%b",
            $time,
            rst,
            wr_en,
            wr_data,
            rd_en,
            rd_data,
            occupancy,
            full,
            empty
        );
    end

    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------
    initial begin

        // Initial values
        rst     = 1'b1;
        wr_en   = 1'b0;
        wr_data = '0;
        rd_en   = 1'b0;

        // --------------------------------------------
        // RESET TEST
        // --------------------------------------------
        #12;

        if (occupancy != 0)
            $display("ERROR: FIFO occupancy not zero after reset");

        if (!empty)
            $display("ERROR: FIFO should be empty after reset");

        $display("RESET TEST PASSED");

        // Release reset
        rst = 1'b0;

        // --------------------------------------------
        // WRITE TEST
        // --------------------------------------------

        // Write 25
        @(negedge clk);
        wr_en   = 1'b1;
        wr_data = 16'd25;

        @(negedge clk);
        wr_en   = 1'b0;

        #1;

        if (occupancy != 1)
            $display("ERROR: Occupancy should be 1 after first write");

        $display("WRITE 25 PASSED");

        // Write 30
        @(negedge clk);
        wr_en   = 1'b1;
        wr_data = 16'd30;

        @(negedge clk);
        wr_en   = 1'b0;

        #1;

        if (occupancy != 2)
            $display("ERROR: Occupancy should be 2 after second write");

        $display("WRITE 30 PASSED");

        // Write 40
        @(negedge clk);
        wr_en   = 1'b1;
        wr_data = 16'd40;

        @(negedge clk);
        wr_en   = 1'b0;

        #1;

        if (occupancy != 3)
            $display("ERROR: Occupancy should be 3 after third write");

        $display("WRITE 40 PASSED");

        // --------------------------------------------
        // READ TEST
        // --------------------------------------------

        // Read first value
        @(negedge clk);
        rd_en = 1'b1;

        @(negedge clk);
        rd_en = 1'b0;

        #1;

        if (rd_data != 16'd25)
            $display("ERROR: Expected 25, got %0d", rd_data);

        if (occupancy != 2)
            $display("ERROR: Occupancy should be 2 after reading 25");

        $display("READ 25 PASSED");

        // Read second value
        @(negedge clk);
        rd_en = 1'b1;

        @(negedge clk);
        rd_en = 1'b0;

        #1;

        if (rd_data != 16'd30)
            $display("ERROR: Expected 30, got %0d", rd_data);

        if (occupancy != 1)
            $display("ERROR: Occupancy should be 1 after reading 30");

        $display("READ 30 PASSED");

        // Read third value
        @(negedge clk);
        rd_en = 1'b1;

        @(negedge clk);
        rd_en = 1'b0;

        #1;

        if (rd_data != 16'd40)
            $display("ERROR: Expected 40, got %0d", rd_data);

        if (occupancy != 0)
            $display("ERROR: Occupancy should be 0 after reading 40");

        if (!empty)
            $display("ERROR: FIFO should be empty");

        $display("READ 40 PASSED");

        // --------------------------------------------
        // EMPTY READ TEST
        // --------------------------------------------

        @(negedge clk);
        rd_en = 1'b1;

        @(negedge clk);
        rd_en = 1'b0;

        #1;

        if (occupancy != 0)
            $display("ERROR: Occupancy changed while reading empty FIFO");

        $display("EMPTY READ TEST PASSED");

        // --------------------------------------------
        // FULL FIFO TEST
        // --------------------------------------------

        $display("Starting FULL FIFO test...");

        for (int i = 0; i < DEPTH; i++) begin

            @(negedge clk);

            wr_en   = 1'b1;
            wr_data = i;

        end

        @(negedge clk);
        wr_en = 1'b0;

        #1;

        if (occupancy != DEPTH)
            $display(
                "ERROR: FIFO should be full. Occupancy = %0d",
                occupancy
            );

        if (!full)
            $display("ERROR: FIFO full flag not asserted");

        $display("FULL FIFO TEST PASSED");

        // --------------------------------------------
        // OVERFLOW TEST
        // Try writing when FIFO is full
        // --------------------------------------------

        @(negedge clk);

        wr_en   = 1'b1;
        wr_data = 16'd999;

        @(negedge clk);

        wr_en = 1'b0;

        #1;

        if (occupancy != DEPTH)
            $display("ERROR: FIFO overflow occurred!");

        if (!full)
            $display("ERROR: FIFO should remain full");

        $display("OVERFLOW PROTECTION TEST PASSED");

        // --------------------------------------------
        // READ EVERYTHING BACK
        // --------------------------------------------

        for (int i = 0; i < DEPTH; i++) begin

            @(negedge clk);
            rd_en = 1'b1;

            @(negedge clk);
            rd_en = 1'b0;

            #1;

            if (rd_data != i)
                $display(
                    "ERROR: Expected %0d, got %0d",
                    i,
                    rd_data
                );

        end

        if (occupancy != 0)
            $display("ERROR: FIFO should be empty after reading everything");

        if (!empty)
            $display("ERROR: FIFO empty flag not asserted");

        $display("FULL FIFO READBACK TEST PASSED");

        // --------------------------------------------
        // FINISH
        // --------------------------------------------

        $display("----------------------------------");
        $display("ALL FIFO TESTS COMPLETED");
        $display("----------------------------------");

        #20;

        $finish;

    end

endmodule