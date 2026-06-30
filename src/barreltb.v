`timescale 1ns/1ps

module tb_barrel_shifter_16bit;

    // Inputs
    reg         clk;
    reg         rst_n;
    reg  [15:0] din;
    reg  [3:0]  shift_amt;
    reg  [1:0]  mode;

    // Outputs
    wire [15:0] dout;

    // Instantiate the Unit Under Test (UUT)
    barrel_shifter_16bit uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .shift_amt(shift_amt),
        .mode(mode),
        .dout(dout)
    );

    // Clock Generation (100 MHz -> Period of 10ns)
    always #5 clk = ~clk;

    // Task for checking actual vs expected with a pipeline delay account
    // Since input is registered and output is registered, there is a 
    // latency of 2 clock cycles from setting 'din' to reading 'dout'.
    task check_output(input [15:0] expected_val, input [15:0] active_input, input [3:0] active_amt, input [1:0] active_mode);
        begin
            @(posedge clk); // Allow pipeline delay to clear
            #1; // Minor offset after clock edge
            if (dout !== expected_val) begin
                $display("[ERROR] Mode: %b, Amt: %d, Din: 16'h%h | Expected: 16'h%h, Got: 16'h%h", 
                          active_mode, active_amt, active_input, expected_val, dout);
            end else begin
                $display("[SUCCESS] Mode: %b, Amt: %d, Din: 16'h%h | Output correctly matches: 16'h%h", 
                          active_mode, active_amt, active_input, dout);
            end
        end
    endtask

    initial begin
        // ----------------------------------------------------------------------
        // VCD File Dump Configuration
        // This is crucial for generating waveforms (.vcd) to analyze in GTKWave 
        // and for conducting power analysis in the Physical Design flow.
        // ----------------------------------------------------------------------
        $dumpfile("tb_barrel_shifter_16bit.vcd");
        $dumpvars(0, tb_barrel_shifter_16bit);

        // Initialize Signals
        clk = 0;
        rst_n = 0;
        din = 16'h0000;
        shift_amt = 4'd0;
        mode = 2'b00;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        // ----------------------------------------------------------------------
        // Test Case 1: Logical Left Shift (LSL) - Mode 00
        // Shift 16'hF00F by 4 -> Expected result: 16'h00F0 (after 2 cycles)
        // ----------------------------------------------------------------------
        $display("\n--- Starting Test Case 1: LSL ---");
        din = 16'hF00F; shift_amt = 4'd4; mode = 2'b00;
        @(posedge clk); // Data enters input registers
        @(posedge clk); // Data passes through combinatorial logic to output register
        check_output(16'h00F0, 16'hF00F, 4'd4, 2'b00);

        // ----------------------------------------------------------------------
        // Test Case 2: Logical Right Shift (LSR) - Mode 01
        // Shift 16'hFF00 by 8 -> Expected result: 16'h00FF
        // ----------------------------------------------------------------------
        $display("\n--- Starting Test Case 2: LSR ---");
        din = 16'hFF00; shift_amt = 4'd8; mode = 2'b01;
        @(posedge clk);
        @(posedge clk);
        check_output(16'h00FF, 16'hFF00, 4'd8, 2'b01);

        // ----------------------------------------------------------------------
        // Test Case 3: Arithmetic Right Shift (ASR) - Mode 10 (Negative number)
        // Shift 16'hF000 by 4 -> Expected result: 16'hFF00 (Sign-extended)
        // ----------------------------------------------------------------------
        $display("\n--- Starting Test Case 3: ASR (Negative) ---");
        din = 16'hF000; shift_amt = 4'd4; mode = 2'b10;
        @(posedge clk);
        @(posedge clk);
        check_output(16'hFF00, 16'hF000, 4'd4, 2'b10);

        // ----------------------------------------------------------------------
        // Test Case 4: Rotate Right (ROR) - Mode 11
        // Rotate 16'h000F by 4 -> Expected result: 16'hF000 (Bits wrap around)
        // ----------------------------------------------------------------------
        $display("\n--- Starting Test Case 4: ROR ---");
        din = 16'h000F; shift_amt = 4'd4; mode = 2'b11;
        @(posedge clk);
        @(posedge clk);
        check_output(16'hF000, 16'h000F, 4'd4, 2'b11);

        // ----------------------------------------------------------------------
        // Test Case 5: Shift by 0 (Pass-through test)
        // Shift 16'h1234 by 0 -> Expected result: 16'h1234
        // ----------------------------------------------------------------------
        $display("\n--- Starting Test Case 5: Shift by 0 ---");
        din = 16'h1234; shift_amt = 4'd0; mode = 2'b00;
        @(posedge clk);
        @(posedge clk);
        check_output(16'h1234, 16'h1234, 4'd0, 2'b00);

        $display("\nAll simulation checks finished.");
        $finish;
    end

endmodule
