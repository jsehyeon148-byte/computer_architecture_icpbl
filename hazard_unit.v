//==============================================================================
// Hazard Unit
//==============================================================================
// Description:
// Manages data and control hazards in the pipeline.
//
// Functions:
// 1. Data Forwarding: Forwards ALU results from MEM or WB stage to EX (ALU inputs)
//    and to ID (Branch inputs) to solve RAW hazards.
// 2. Load-Use Stall: Detection of data dependency on a Load instruction.
// 3. Branch Stall: Stalls if valid branch operands cannot be forwarded in time.
//==============================================================================
`timescale 1ns / 1ps

module hazard_unit (
    // Inputs for Forwarding Logic (EX Stage Targets)
    input  wire [4:0] rs_E, rt_E,     // Source registers in EX
    input  wire [4:0] write_reg_E,    // Dest register in EX
    input  wire       reg_write_E,    // Write enable in EX
    input  wire       mem_to_reg_E,   // Load instruction in EX
    
    // Inputs for Forwarding Logic (MEM/WB Stage Sources)
    input  wire [4:0] write_reg_M,    // Dest register in MEM
    input  wire       reg_write_M,    // Write enable in MEM
    input  wire       mem_to_reg_M,   // Load instruction in MEM
    input  wire [4:0] write_reg_W,    // Dest register in WB
    input  wire       reg_write_W,    // Write enable in WB
    
    // Inputs for Stall Logic (ID Stage)
    input  wire [4:0] rs_D, rt_D,     // Source registers in ID
    input  wire       branch_D,       // Branch instruction in ID
    
    // Outputs
    output reg  [1:0] forward_a_E,    // Fwd Control for ALU Src A
    output reg  [1:0] forward_b_E,    // Fwd Control for ALU Src B
    output reg  [1:0] forward_a_D,    // Fwd Control for Branch Src A
    output reg  [1:0] forward_b_D,    // Fwd Control for Branch Src B
    output wire       stall_F,        // Stall Fetch
    output wire       stall_D,        // Stall Decode
    output wire       flush_E         // Flush Execute
);

    wire lwstall;
    wire branchstall;

    // --- 1. Forwarding to EX (ALU) ---
    // Solves Data Hazards for Arithmetic Instructions
    always @(*) begin
        // Forward A (ALU input 1)
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rs_E)) forward_a_E = 2'b10; // Forward from MEM
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rs_E)) forward_a_E = 2'b01; // Forward from WB
        else forward_a_E = 2'b00;

        // Forward B (ALU input 2)
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rt_E)) forward_b_E = 2'b10;
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rt_E)) forward_b_E = 2'b01;
        else forward_b_E = 2'b00;
    end

    // --- 2. Forwarding to ID (Branch Comparator) ---
    // Solves Data Hazards for Branch Instructions (Early Branch)
    always @(*) begin
        // Forward A to ID
        // Note: Can only forward from MEM if it is NOT a Load (result not ready yet)
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rs_D)) forward_a_D = 2'b10;
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rs_D)) forward_a_D = 2'b01;
        else forward_a_D = 2'b00;

        // Forward B to ID
        if (reg_write_M && (write_reg_M != 0) && (write_reg_M == rt_D)) forward_b_D = 2'b10;
        else if (reg_write_W && (write_reg_W != 0) && (write_reg_W == rt_D)) forward_b_D = 2'b01;
        else forward_b_D = 2'b00;
    end

    // --- 3. Stall Logic ---
    
    // Load-Use Stall (for ALU consumer)
    // If Load in EX, and consumer in ID is NOT Branch (Branch handled separately)
    assign lwstall = mem_to_reg_E && ((write_reg_E == rs_D) || (write_reg_E == rt_D));

    // Branch Stall
    // Stall if Branch depends on:
    //  1. ALU/Load instruction currently in EX (result not valid in ID even with fwd from MEM start)
    //  2. Load instruction currently in MEM (result not valid in ID until WB)
    assign branchstall = branch_D && (
        (reg_write_E && (write_reg_E == rs_D || write_reg_E == rt_D)) ||
        (mem_to_reg_M && (write_reg_M == rs_D || write_reg_M == rt_D))
    );

    assign stall_F = lwstall || branchstall;
    assign stall_D = lwstall || branchstall;
    assign flush_E = lwstall || branchstall;

endmodule