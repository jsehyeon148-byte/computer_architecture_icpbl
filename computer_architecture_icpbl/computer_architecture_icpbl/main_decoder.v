//==============================================================================
// Main Control Decoder
//==============================================================================
// Description:
// Decodes the 6-bit Opcode to generate primary control signals for the pipeline.
// 
// Supported Instructions:
// - R-type : opcode 000000
// - lw     : opcode 100011
// - sw     : opcode 101011
// - beq    : opcode 000100
// - addi   : opcode 001000
// - j      : opcode 000010 (Jump)
//==============================================================================
`timescale 1ns / 1ps

module main_decoder (
    input  wire [5:0] opcode,
    output wire       mem_to_reg,
    output wire       mem_write,
    output wire       branch,
    output wire       alu_src,
    output wire       reg_dst,
    output wire       reg_write,
    output wire       jump,        // Added for Jump support
    output wire [1:0] alu_op    
);
    reg [9:0] controls; 
    assign {reg_write, reg_dst, alu_src, branch, mem_write, mem_to_reg, jump, alu_op} = controls;

    // Control Logic Truth Table
    // {reg_write, reg_dst, alu_src, branch, mem_write, mem_to_reg, jump, alu_op}
    always @(*) begin
        case (opcode)
            6'b000000: controls = 10'b1_1_0_0_0_0_0_10; // R-type
            6'b100011: controls = 10'b1_0_1_0_0_1_0_00; // lw
            6'b101011: controls = 10'b0_0_1_0_1_0_0_00; // sw
            6'b000100: controls = 10'b0_0_0_1_0_0_0_01; // beq
            6'b000101: controls = 10'b0_0_0_1_0_0_0_01; // bne (same as beq, comparison in datapath)
            6'b001000: controls = 10'b1_0_1_0_0_0_0_00; // addi
            6'b000010: controls = 10'b0_0_0_0_0_0_1_00; // j (Jump)
            default:   controls = 10'b0_0_0_0_0_0_0_00; // Safe default
        endcase
    end
endmodule