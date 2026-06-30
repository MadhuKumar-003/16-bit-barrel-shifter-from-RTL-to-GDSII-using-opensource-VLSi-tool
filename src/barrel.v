// ==============================================================================
// Module Name:  barrel_shifter_16bit
// Description:  A highly structured 16-bit Barrel Shifter with boundary registers.
//               Designed specifically for physical design (PD) flows. 
//               Features stage-by-stage 2:1 MUX structural logic to preserve 
//               predictable data-path routing across stages.
//
// Supported Modes:
//   2'b00 : Logical Left Shift (LSL)
//   2'b01 : Logical Right Shift (LSR)
//   2'b10 : Arithmetic Right Shift (ASR)
//   2'b11 : Rotate Right (ROR)
// ==============================================================================

module barrel_shifter_16bit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] din,         // Data input
    input  wire [3:0]  shift_amt,   // Shift amount (0 to 15)
    input  wire [1:0]  mode,        // Shift mode selector
    output reg  [15:0] dout         // Data output (registered)
);

    // --------------------------------------------------------------------------
    // Boundary Input Registers
    // --------------------------------------------------------------------------
    // Registering inputs is crucial for Physical Design. It provides well-defined
    // startpoints for STA (Static Timing Analysis) and prevents external delays
    // from corrupting internal data-path timing.
    // --------------------------------------------------------------------------
    reg [15:0] r_din;
    reg [3:0]  r_shift_amt;
    reg [1:0]  r_mode;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_din       <= 16'h0000;
            r_shift_amt <= 4'h0;
            r_mode      <= 2'b00;
        end else begin
            r_din       <= din;
            r_shift_amt <= shift_amt;
            r_mode      <= mode;
        end
    end

    // --------------------------------------------------------------------------
    // Stage-by-Stage Combinational Shifter Core
    // --------------------------------------------------------------------------
    // To make this a great physical design data-path, we build it out of 4 distinct
    // stages of 2:1 multiplexers. This maps beautifully to standard cell libraries
    // and creates a highly structured cell matrix during placement.
    // --------------------------------------------------------------------------
    
    // Internal wires for intermediate stage routing
    wire [15:0] stage0_out; // Output of Stage 0 (Shift-by-1 or 0)
    wire [15:0] stage1_out; // Output of Stage 1 (Shift-by-2 or 0)
    wire [15:0] stage2_out; // Output of Stage 2 (Shift-by-4 or 0)
    wire [15:0] stage3_out; // Output of Stage 3 (Shift-by-8 or 0)

    // Helper sign extension bit for Arithmetic Right Shift (ASR)
    wire sign_bit = r_din[15];

    // ==========================================================================
    // STAGE 0: Shift/Rotate by 1 bit or 0
    // ==========================================================================
    generate
        genvar i;
        for (i = 0; i < 16; i = i + 1) begin : stage0_mux_gen
            assign stage0_out[i] = (r_shift_amt[0] == 1'b0) ? r_din[i] : (
                (r_mode == 2'b00) ? ((i >= 1) ? r_din[i-1] : 1'b0) :         // LSL: Shift Left by 1
                (r_mode == 2'b01) ? ((i <= 14) ? r_din[i+1] : 1'b0) :        // LSR: Shift Right by 1
                (r_mode == 2'b10) ? ((i <= 14) ? r_din[i+1] : sign_bit) :    // ASR: Shift Right with Sign-extend
                                    ((i <= 14) ? r_din[i+1] : r_din[0])      // ROR: Rotate Right (bit 0 wraps to 15)
            );
        end
    endgenerate

    // ==========================================================================
    // STAGE 1: Shift/Rotate by 2 bits or 0
    // ==========================================================================
    generate
        for (i = 0; i < 16; i = i + 1) begin : stage1_mux_gen
            assign stage1_out[i] = (r_shift_amt[1] == 1'b0) ? stage0_out[i] : (
                (r_mode == 2'b00) ? ((i >= 2) ? stage0_out[i-2] : 1'b0) :
                (r_mode == 2'b01) ? ((i <= 13) ? stage0_out[i+2] : 1'b0) :
                (r_mode == 2'b10) ? ((i <= 13) ? stage0_out[i+2] : sign_bit) :
                                    stage0_out[(i+2)%16]
            );
        end
    endgenerate

    // ==========================================================================
    // STAGE 2: Shift/Rotate by 4 bits or 0
    // ==========================================================================
    generate
        for (i = 0; i < 16; i = i + 1) begin : stage2_mux_gen
            assign stage2_out[i] = (r_shift_amt[2] == 1'b0) ? stage1_out[i] : (
                (r_mode == 2'b00) ? ((i >= 4) ? stage1_out[i-4] : 1'b0) :
                (r_mode == 2'b01) ? ((i <= 11) ? stage1_out[i+4] : 1'b0) :
                (r_mode == 2'b10) ? ((i <= 11) ? stage1_out[i+4] : sign_bit) :
                                    stage1_out[(i+4)%16]
            );
        end
    endgenerate

    // ==========================================================================
    // STAGE 3: Shift/Rotate by 8 bits or 0
    // ==========================================================================
    // Note: This stage represents the largest physical routing jump. 
    // In physical design layout, these connections will span across approximately
    // half the physical width of the standard cell matrix.
    // ==========================================================================
    generate
        for (i = 0; i < 16; i = i + 1) begin : stage3_mux_gen
            assign stage3_out[i] = (r_shift_amt[3] == 1'b0) ? stage2_out[i] : (
                (r_mode == 2'b00) ? ((i >= 8) ? stage2_out[i-8] : 1'b0) :
                (r_mode == 2'b01) ? ((i <= 7) ? stage2_out[i+8] : 1'b0) :
                (r_mode == 2'b10) ? ((i <= 7) ? stage2_out[i+8] : sign_bit) :
                                    stage2_out[(i+8)%16]
            );
        end
    endgenerate

    // --------------------------------------------------------------------------
    // Boundary Output Registers
    // --------------------------------------------------------------------------
    // Registering outputs provides clean endpoints for timing constraints, making
    // it easy to close timing margins in place & route tools.
    // --------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 16'h0000;
        end else begin
            dout <= stage3_out;
        end
    end

endmodule
