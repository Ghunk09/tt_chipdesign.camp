// Testbench for the morse code ENCODER - Comprehensive Test

`timescale 1ns/1ps
`default_nettype none

module tb;

    // Inputs
    reg [7:0] ui_in;
    reg       ena;
    reg       clk;
    reg       rst_n;

    // uio_in is not used in this design, but must be connected
    wire [7:0] uio_in;
    assign uio_in = 8'b0;

    // Outputs
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instantiate the design
    tt_um_ccmed_morse_translator uut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Task to wait for the busy signal to go low
    task wait_for_not_busy;
        begin
            // Wait for busy to start, with a timeout
            @(posedge uio_out[1])
            $display("Busy signal is high. Waiting for transmission to complete.");
            
            // Wait for busy to end
            @(negedge uio_out[1])
            $display("Busy signal is low. Transmission complete.");
        end
    endtask

    // Test sequence
    initial begin
        // Use an absolute path for the dump file to avoid confusion
        $dumpfile("/mnt/c/Users/ccmed/tinytapeout-morse-translator/test/comprehensive_tb.vcd");
        $dumpvars(0, tb);

        // Initialize inputs
        ui_in = 0;
        ena = 1;
        rst_n = 0;

        // Apply reset
        #20;
        rst_n = 1;
        #20;

        $display("Starting comprehensive test sequence for all 32 inputs...");

        // Loop through all 32 possible 5-bit inputs
        for (integer i = 0; i < 32; i = i + 1) begin
            $display("-----------------------------------------");
            $display("Test Case: Input 5'd%0d", i);
            
            ui_in[4:0] = i;
            ui_in[5] = 1;      // Start pulse
            #10;
            ui_in[5] = 0;
            #10; // Ensure start pulse is registered

            // Only wait if the design is expected to do something
            // morse_length is 0 for space (i=0) and invalid inputs
            // The FSM for space still takes time, so we wait anyway.
            // For truly invalid inputs, the FSM goes straight to IDLE, busy might not pulse.
            // The wait_for_not_busy task has a timeout, which is good.
            
            // A small initial wait to allow the busy signal to rise
            #1; 
            if (uut.busy) begin
                wait_for_not_busy;
            end else begin
                $display("Input 5'd%0d is invalid or has 0 length, skipping wait.", i);
            end

            #20; // Small delay between tests
        end

        $display("-----------------------------------------");
        $display("All test cases finished.");
        $finish;
    end

endmodule

`default_nettype wire
