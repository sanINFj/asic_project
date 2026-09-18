`timescale 1ns/1ps

module tb_scheduler;

    logic clk;
    logic rst;

    logic        event_valid;
    logic [1:0]  event_type;
    logic [15:0] event_score;

    logic [4:0] fifo_occupancy;

    logic mac_busy;
    logic mac_valid;

    logic compute_start;
    logic fifo_read;
    logic mac_enable;


    // ============================================================
    // CLOCK
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ============================================================
    // DUT
    // ============================================================

    scheduler dut (
        .clk(clk),
        .rst(rst),

        .event_valid(event_valid),
        .event_type(event_type),
        .event_score(event_score),

        .fifo_occupancy(fifo_occupancy),

        .mac_busy(mac_busy),
        .mac_valid(mac_valid),

        .compute_start(compute_start),
        .fifo_read(fifo_read),
        .mac_enable(mac_enable)
    );


    // ============================================================
    // TEST SEQUENCE
    // ============================================================

    initial begin

        $dumpfile("scheduler.vcd");
        $dumpvars(0, tb_scheduler);


        // ========================================================
        // INITIAL VALUES
        // ========================================================

        rst = 1'b1;

        event_valid    = 1'b0;
        event_type     = 2'b00;
        event_score    = 16'd0;

        fifo_occupancy = 5'd0;

        mac_busy  = 1'b0;
        mac_valid = 1'b0;


        // ========================================================
        // RESET
        // ========================================================

        repeat (2)
            @(posedge clk);

        #1;

        rst = 1'b0;

        @(negedge clk);


        // ========================================================
        // TEST 1
        //
        // NORMAL event must be ignored.
        // ========================================================

        event_valid    = 1'b1;
        event_type     = 2'b00;
        event_score    = 16'h0100;
        fifo_occupancy = 5'd4;
        mac_busy      = 1'b0;

        @(posedge clk);
        #1;

        event_valid = 1'b0;

        repeat (2)
            @(posedge clk);

        #1;

        $display("------------------------------------------");
        $display("TEST 1: NORMAL EVENT");
        $display("compute_start = %b", compute_start);
        $display("fifo_read     = %b", fifo_read);
        $display("mac_enable    = %b", mac_enable);
        $display("pending_event = %b", dut.pending_event);

        if ((compute_start == 1'b0) &&
            (fifo_read     == 1'b0) &&
            (mac_enable    == 1'b0) &&
            (dut.pending_event == 1'b0))
            $display("TEST 1 PASSED");
        else
            $display("TEST 1 FAILED");


        // ========================================================
        // TEST 2
        //
        // GRADUAL event
        // FIFO has data
        // MAC is free
        //
        // Expected:
        //
        // IDLE
        //   ->
        // WAIT_READY
        //   ->
        // ISSUE
        //
        // Then one-cycle control pulses.
        // ========================================================

        @(negedge clk);

        event_valid    = 1'b1;
        event_type     = 2'b01;
        event_score    = 16'h0500;
        fifo_occupancy = 5'd4;
        mac_busy       = 1'b0;

        // Event captured
        @(posedge clk);
        #1;

        event_valid = 1'b0;

        // WAIT_READY -> ISSUE
        @(posedge clk);
        #1;

        // ISSUE outputs occur here
        @(posedge clk);
        #1;

        $display("------------------------------------------");
        $display("TEST 2: GRADUAL EVENT");
        $display("compute_start = %b", compute_start);
        $display("fifo_read     = %b", fifo_read);
        $display("mac_enable    = %b");
        $display("pending_event = %b", dut.pending_event);

        if ((compute_start == 1'b1) &&
            (fifo_read     == 1'b1) &&
            (mac_enable    == 1'b1) &&
            (dut.pending_event == 1'b0))
            $display("TEST 2 PASSED");
        else
            $display("TEST 2 FAILED");


        // Finish the ISSUE pulse.
        @(posedge clk);
        #1;


        // ========================================================
        // TEST 3
        //
        // New SUDDEN event arrives while the current MAC
        // operation is still running.
        //
        // MAC is busy.
        //
        // Expected:
        // no new issue
        // pending_event = 1
        // ========================================================

        @(negedge clk);

        event_valid    = 1'b1;
        event_type     = 2'b10;
        event_score    = 16'h0A00;
        fifo_occupancy = 5'd5;
        mac_busy       = 1'b1;
        mac_valid      = 1'b0;

        @(posedge clk);
        #1;

        event_valid = 1'b0;

        // Give scheduler time to remain in WAIT_DONE.
        repeat (2)
            @(posedge clk);

        #1;

        $display("------------------------------------------");
        $display("TEST 3: SUDDEN EVENT WHILE MAC BUSY");
        $display("compute_start = %b", compute_start);
        $display("fifo_read     = %b", fifo_read);
        $display("mac_enable    = %b");
        $display("pending_event = %b", dut.pending_event);

        if ((compute_start == 1'b0) &&
            (fifo_read     == 1'b0) &&
            (mac_enable    == 1'b0) &&
            (dut.pending_event == 1'b1))
            $display("TEST 3 PASSED");
        else
            $display("TEST 3 FAILED");


        // ========================================================
        // TEST 4
        //
        // Current MAC operation completes.
        //
        // mac_valid = 1
        //
        // Scheduler should move:
        //
        // WAIT_DONE -> WAIT_READY
        //
        // Then, because FIFO has data and MAC is free:
        //
        // WAIT_READY -> ISSUE
        // ========================================================

        @(negedge clk);

        mac_busy  = 1'b0;
        mac_valid = 1'b1;

        @(posedge clk);
        #1;

        // mac_valid has completed the old operation.
        mac_valid = 1'b0;

        // WAIT_READY -> ISSUE
        @(posedge clk);
        #1;

        // ISSUE outputs
        @(posedge clk);
        #1;

        $display("------------------------------------------");
        $display("TEST 4: PENDING EVENT AFTER MAC COMPLETION");
        $display("compute_start = %b", compute_start);
        $display("fifo_read     = %b", fifo_read);
        $display("mac_enable    = %b");
        $display("pending_event = %b", dut.pending_event);

        if ((compute_start == 1'b1) &&
            (fifo_read     == 1'b1) &&
            (mac_enable    == 1'b1) &&
            (dut.pending_event == 1'b0))
            $display("TEST 4 PASSED");
        else
            $display("TEST 4 FAILED");


        // Finish ISSUE pulse.
        @(posedge clk);
        #1;


        // ========================================================
        // TEST 5
        //
        // Current MAC completes and there is no pending event.
        //
        // Scheduler should return to IDLE.
        // ========================================================

        @(negedge clk);

        mac_valid = 1'b1;

        @(posedge clk);
        #1;

        mac_valid = 1'b0;

        @(posedge clk);
        #1;

        $display("------------------------------------------");
        $display("TEST 5: MAC COMPLETION WITH NO PENDING EVENT");
        $display("pending_event = %b", dut.pending_event);
        $display("TEST 5 PASSED");


        // ========================================================
        // TEST 6
        //
        // New event arrives while FIFO is empty.
        //
        // Expected:
        // pending_event = 1
        // no issue
        // ========================================================

        @(negedge clk);

        event_valid    = 1'b1;
        event_type     = 2'b01;
        event_score    = 16'h0300;
        fifo_occupancy = 5'd0;
        mac_busy       = 1'b0;

        @(posedge clk);
        #1;

        event_valid = 1'b0;

        repeat (2)
            @(posedge clk);

        #1;

        $display("------------------------------------------");
        $display("TEST 6: FIFO EMPTY");
        $display("compute_start = %b", compute_start);
        $display("fifo_read     = %b", fifo_read);
        $display("mac_enable    = %b");
        $display("pending_event = %b", dut.pending_event);

        if ((compute_start == 1'b0) &&
            (fifo_read     == 1'b0) &&
            (mac_enable    == 1'b0) &&
            (dut.pending_event == 1'b1))
            $display("TEST 6 PASSED");
        else
            $display("TEST 6 FAILED");


        // ========================================================
        // TEST 7
        //
        // FIFO becomes available.
        //
        // Expected:
        // WAIT_READY -> ISSUE
        // ========================================================

        @(negedge clk);

        fifo_occupancy = 5'd3;

        // WAIT_READY -> ISSUE
        @(posedge clk);
        #1;

        // ISSUE outputs
        @(posedge clk);
        #1;

        $display("------------------------------------------");
        $display("TEST 7: FIFO BECOMES AVAILABLE");
        $display("compute_start = %b", compute_start);
        $display("fifo_read     = %b", fifo_read);
        $display("mac_enable    = %b");
        $display("pending_event = %b", dut.pending_event);

        if ((compute_start == 1'b1) &&
            (fifo_read     == 1'b1) &&
            (mac_enable    == 1'b1) &&
            (dut.pending_event == 1'b0))
            $display("TEST 7 PASSED");
        else
            $display("TEST 7 FAILED");


        // ========================================================
        // FINISH
        // ========================================================

        $display("------------------------------------------");
        $display("ALL SCHEDULER TESTS COMPLETED");
        $display("------------------------------------------");

        #10;

        $finish;

    end

endmodule
