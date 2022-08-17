`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input  wire        clk,             // main clock
                     input  wire        rst,             // global reset
                     input  wire        gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input  wire [15:0] i_cur_insn_A,    // output of instruction memory (pipe A)
                     input  wire [15:0] i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input  wire [15:0] i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );


    // Things to implement: superscalar stall case, dispatch handling (dependencies --> dispatch, then appropriate stall values), 
    // bypassing logic (prioritize .B version of insn over .A version when handling bypasses, and consider MM bypass), squash logic 
    // (consider cases where branch is taken, but also is in either pipe A or pipe B)

    // Whenever only pipe B stalls, perform pipe switching
    // Be careful about how to handle LTU stalling (i.e., perform a sufficient number of dependency checks)


    // PROGRAM COUNTER
    wire [15:0]   pc;      // Current program counter (read out from pc_reg)
    wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

    Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] pc_plus_one, pc_plus_two;
    cla16 pc_plus_one_adder(.a(pc), .b(16'd1), .cin(1'b0), .sum(pc_plus_one));
    cla16 pc_plus_two_adder(.a(pc), .b(16'd2), .cin(1'b0), .sum(pc_plus_two));
    assign o_cur_pc = pc;
    assign next_pc = is_flush_A ? alu_output_A 
                   : is_flush_B ? alu_output_B 
                   : stall_A ? pc
                   : stall_B_only ? pc_plus_one 
                   : pc_plus_two;

    // PIPELINE REGISTERS
    
    wire [15:0] decode_pc_register_in_A = stall_B_only ? decode_pc_register_out_B : pc;
    wire [15:0] decode_pc_register_in_B = stall_B_only ? pc : pc_plus_one;

    wire [15:0] decode_pc_plus_one_register_in_A = stall_B_only ? decode_pc_plus_one_B : pc_plus_one;
    wire [15:0] decode_pc_plus_one_register_in_B = stall_B_only ? pc_plus_one : pc_plus_two;

    wire [15:0] decode_instruction_register_in_A = (is_flush_A || is_flush_B) ? 16'd0 
                                                 : stall_B_only ? decode_instruction_register_out_B
                                                 : i_cur_insn_A;
    wire [15:0] decode_instruction_register_in_B = (is_flush_A || is_flush_B) ? 16'd0 
                                                 : stall_B_only ? i_cur_insn_A 
                                                 : i_cur_insn_B;

    // Instruction Registers
    wire [15:0] decode_instruction_register_out_A, execute_instruction_register_out_A, memory_instruction_register_out_A, writeback_instruction_register_out_A;
    Nbit_reg #(16) decode_instruction_register_A(.in(decode_instruction_register_in_A), .out(decode_instruction_register_out_A), .clk(clk), .we(is_flush_A || is_flush_B || stall_A == 0), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_instruction_register_A(.in(decode_instruction_A), .out(execute_instruction_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_instruction_register_A(.in(execute_instruction_register_out_A), .out(memory_instruction_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_instruction_register_A(.in(memory_instruction_register_out_A), .out(writeback_instruction_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] decode_instruction_register_out_B, temp_execute_instruction_register_out_B, memory_instruction_register_out_B, writeback_instruction_register_out_B;
    Nbit_reg #(16) decode_instruction_register_B(.in(decode_instruction_register_in_B), .out(decode_instruction_register_out_B), .clk(clk), .we(is_flush_A || is_flush_B || stall_A == 0), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_instruction_register_B(.in(decode_instruction_B), .out(temp_execute_instruction_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_instruction_register_B(.in(execute_instruction_register_out_B), .out(memory_instruction_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_instruction_register_B(.in(memory_instruction_register_out_B), .out(writeback_instruction_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // PC Registers
    wire [15:0] decode_pc_register_out_A, execute_pc_register_out_A, memory_pc_register_out_A, writeback_pc_register_out_A;
    Nbit_reg #(16) decode_pc_register_A(.in(decode_pc_register_in_A), .out(decode_pc_register_out_A), .clk(clk), .we(!(stall_A)), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_pc_register_A(.in(decode_pc_register_out_A), .out(execute_pc_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_pc_register_A(.in(execute_pc_register_out_A), .out(memory_pc_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_pc_register_A(.in(memory_pc_register_out_A), .out(writeback_pc_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] decode_pc_register_out_B, execute_pc_register_out_B, memory_pc_register_out_B, writeback_pc_register_out_B;
    Nbit_reg #(16) decode_pc_register_B(.in(decode_pc_register_in_B), .out(decode_pc_register_out_B), .clk(clk), .we(!(stall_A)), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_pc_register_B(.in(decode_pc_register_out_B), .out(execute_pc_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_pc_register_B(.in(execute_pc_register_out_B), .out(memory_pc_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_pc_register_B(.in(memory_pc_register_out_B), .out(writeback_pc_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // PC plus one
    wire [15:0] decode_pc_plus_one_A, execute_pc_plus_one_A;
    Nbit_reg #(16) decode_pc_plus_one_register_A(.in(decode_pc_plus_one_register_in_A), .out(decode_pc_plus_one_A), .clk(clk), .we(!(stall_A)), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_pc_plus_one_register_A(.in(decode_pc_plus_one_A), .out(execute_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] decode_pc_plus_one_B, execute_pc_plus_one_B;
    Nbit_reg #(16) decode_pc_plus_one_register_B(.in(decode_pc_plus_one_register_in_B), .out(decode_pc_plus_one_B), .clk(clk), .we(!(stall_A)), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_pc_plus_one_register_B(.in(decode_pc_plus_one_B), .out(execute_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    // Stall Registers
    wire [1:0] decode_stall_register_out_A, execute_stall_register_out_A, memory_stall_register_out_A, writeback_stall_register_out_A;
    wire [1:0] stall_decode_A = (is_flush_A || is_flush_B) ? 2'b10 : 2'b00;
    wire [1:0] stall_execute_A = (is_flush_A || is_flush_B) ? 2'b10 : (|stall_A) ? stall_A : decode_stall_register_out_A;
    Nbit_reg #(2, 2'b10) decode_stall_register_A(.in(stall_decode_A), .out(decode_stall_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) execute_stall_register_A(.in(stall_execute_A), .out(execute_stall_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) memory_stall_register_A(.in(execute_stall_register_out_A), .out(memory_stall_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) writeback_stall_register_A(.in(memory_stall_register_out_A), .out(writeback_stall_register_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [1:0] decode_stall_register_out_B, execute_stall_register_out_B, memory_stall_register_out_B, writeback_stall_register_out_B;
    wire [1:0] stall_decode_B = (is_flush_A || is_flush_B) ? 2'b10 : 2'b00;
    wire [1:0] stall_execute_B = (is_flush_A || is_flush_B) ? 2'b10 : (|stall_B) ? stall_B : decode_stall_register_out_B;
    wire [1:0] stall_memory_B = (is_flush_A) ? 2'b10 : execute_stall_register_out_B;
    Nbit_reg #(2, 2'b10) decode_stall_register_B(.in(stall_decode_B), .out(decode_stall_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) execute_stall_register_B(.in(stall_execute_B), .out(execute_stall_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) memory_stall_register_B(.in(stall_memory_B), .out(memory_stall_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) writeback_stall_register_B(.in(memory_stall_register_out_B), .out(writeback_stall_register_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    // Stall Logic
    wire XA_DA_r1_dep = (initial_decode_r1re_A && (initial_decode_r1sel_A == execute_wsel_A) && execute_regfile_we_A);
    wire XB_DA_r1_dep = (initial_decode_r1re_A && (initial_decode_r1sel_A == execute_wsel_B) && execute_regfile_we_B);
    wire XA_DB_r1_dep = (initial_decode_r1re_B && (initial_decode_r1sel_B == execute_wsel_A) && execute_regfile_we_A);
    wire XB_DB_r1_dep = (initial_decode_r1re_B && (initial_decode_r1sel_B == execute_wsel_B) && execute_regfile_we_B);

    wire XA_DA_r2_dep = (initial_decode_r2re_A && (initial_decode_r2sel_A == execute_wsel_A) && execute_regfile_we_A) && !initial_decode_is_store_A;
    wire XB_DA_r2_dep = (initial_decode_r2re_A && (initial_decode_r2sel_A == execute_wsel_B) && execute_regfile_we_B) && !initial_decode_is_store_A;
    wire XA_DB_r2_dep = (initial_decode_r2re_B && (initial_decode_r2sel_B == execute_wsel_A) && execute_regfile_we_A) && !initial_decode_is_store_B;
    wire XB_DB_r2_dep = (initial_decode_r2re_B && (initial_decode_r2sel_B == execute_wsel_B) && execute_regfile_we_B) && !initial_decode_is_store_B;
      
    wire XB_clobbers_DB_r1 = execute_regfile_we_B && execute_wsel_B == initial_decode_r1sel_B && initial_decode_r1re_B;
    wire XB_clobbers_DB_r2 = execute_regfile_we_B && execute_wsel_B == initial_decode_r2sel_B && initial_decode_r2re_B;
    wire XB_clobbers_DA_r1 = execute_regfile_we_B && execute_wsel_B == initial_decode_r1sel_A && initial_decode_r1re_A;
    wire XB_clobbers_DA_r2 = execute_regfile_we_B && execute_wsel_B == initial_decode_r2sel_A && initial_decode_r2re_A;
      
    wire  r1_LTU_XB_DA = execute_is_load_B && XB_DA_r1_dep;
    wire  r2_LTU_XB_DA = execute_is_load_B && XB_DA_r2_dep;
    wire nzp_LTU_XB_DA = execute_is_load_B && initial_decode_is_branch_A;
    wire LTU_XB_DA = r1_LTU_XB_DA || r2_LTU_XB_DA || nzp_LTU_XB_DA;

    wire  r1_LTU_XB_DB = execute_is_load_B && XB_DB_r1_dep;
    wire  r2_LTU_XB_DB = execute_is_load_B && XB_DB_r2_dep;
    wire nzp_LTU_XB_DB = execute_is_load_B && initial_decode_is_branch_B;
    wire LTU_XB_DB = r1_LTU_XB_DB || r2_LTU_XB_DB || nzp_LTU_XB_DB && !initial_decode_nzp_we_A;

    wire  r1_LTU_XA_DA = execute_is_load_A && XA_DA_r1_dep && !XB_clobbers_DA_r1;
    wire  r2_LTU_XA_DA = execute_is_load_A && XA_DA_r2_dep && !XB_clobbers_DA_r2;
    wire nzp_LTU_XA_DA = execute_is_load_A && initial_decode_is_branch_A && !execute_nzp_we_B;
    wire LTU_XA_DA = r1_LTU_XA_DA || r2_LTU_XA_DA || nzp_LTU_XA_DA;

    wire  r1_LTU_XA_DB = execute_is_load_A && XA_DB_r1_dep && !XB_clobbers_DB_r1;
    wire  r2_LTU_XA_DB = execute_is_load_A && XA_DB_r2_dep && !XB_clobbers_DB_r2;
    wire nzp_LTU_XA_DB = execute_is_load_A && initial_decode_is_branch_B && !initial_decode_nzp_we_A && !execute_nzp_we_B;
    wire LTU_XA_DB = r1_LTU_XA_DB || r2_LTU_XA_DB || nzp_LTU_XA_DB;

    // LTU dependency from X.A to D.A
    wire is_load_use_only_A = LTU_XA_DA;

    // LTU dependency from X.A to D.B
    wire is_load_use_XA_DB = LTU_XA_DB;

    // LTU dependency for X.B to D.A 
    wire is_load_use_XB_DA = LTU_XB_DA;

    // LTU dependency from X.B to D.B
    wire is_load_use_only_B = LTU_XB_DB;

    wire is_superscalar_stall_on_rs = initial_decode_r1re_B && initial_decode_regfile_we_A && (initial_decode_r1sel_B == initial_decode_wsel_A); 
    wire is_superscalar_stall_on_rt = initial_decode_r2re_B && initial_decode_regfile_we_A && (initial_decode_r2sel_B == initial_decode_wsel_A) && !initial_decode_is_store_B; 
    wire is_superscalar_stall_on_nzp = initial_decode_is_branch_B && initial_decode_nzp_we_A;
    wire is_superscalar_stall = is_superscalar_stall_on_rs || is_superscalar_stall_on_rt || is_superscalar_stall_on_nzp || both_decode_insns_are_memory_insns;
    wire both_decode_insns_are_memory_insns = (initial_decode_is_store_A || initial_decode_is_load_A) && (initial_decode_is_store_B || initial_decode_is_load_B);
    wire stall_B_only = (|stall_B) && !(|stall_A);

    wire [1:0] stall_A = is_load_use_only_A || is_load_use_XB_DA ? 2'b11 
                       : is_flush_A || is_flush_B ? 2'b10 
                       : 2'b00; 
    wire [1:0] stall_B = stall_A == 2'b11 ? 2'b01
                       : is_superscalar_stall ? 2'b01 
                       : is_load_use_only_B || is_load_use_XA_DB ? 2'b11 
                       : is_flush_A || is_flush_B ? 2'b10 
                       : 2'b00;

   

    // DECODE
    wire [2:0] initial_decode_r1sel_A, initial_decode_r2sel_A, initial_decode_wsel_A;
    wire initial_decode_r1re_A, initial_decode_r2re_A, initial_decode_regfile_we_A, initial_decode_nzp_we_A, initial_decode_select_pc_plus_one_A, initial_decode_is_load_A, initial_decode_is_store_A, initial_decode_is_branch_A, initial_decode_is_control_insn_A;
    lc4_decoder decoder_A(.insn(decode_instruction_register_out_A), .r1sel(initial_decode_r1sel_A), .r1re(initial_decode_r1re_A), .r2sel(initial_decode_r2sel_A), .r2re(initial_decode_r2re_A), .wsel(initial_decode_wsel_A), 
                          .regfile_we(initial_decode_regfile_we_A), .nzp_we(initial_decode_nzp_we_A), .select_pc_plus_one(initial_decode_select_pc_plus_one_A), 
                          .is_load(initial_decode_is_load_A), .is_store(initial_decode_is_store_A), .is_branch(initial_decode_is_branch_A), .is_control_insn(initial_decode_is_control_insn_A)); 

    wire [2:0] initial_decode_r1sel_B, initial_decode_r2sel_B, initial_decode_wsel_B;
    wire initial_decode_r1re_B, initial_decode_r2re_B, initial_decode_regfile_we_B, initial_decode_nzp_we_B, initial_decode_select_pc_plus_one_B, initial_decode_is_load_B, initial_decode_is_store_B, initial_decode_is_branch_B, initial_decode_is_control_insn_B;
    lc4_decoder decoder_B(.insn(decode_instruction_register_out_B), .r1sel(initial_decode_r1sel_B), .r1re(initial_decode_r1re_B), .r2sel(initial_decode_r2sel_B), .r2re(initial_decode_r2re_B), .wsel(initial_decode_wsel_B), 
                          .regfile_we(initial_decode_regfile_we_B), .nzp_we(initial_decode_nzp_we_B), .select_pc_plus_one(initial_decode_select_pc_plus_one_B), 
                          .is_load(initial_decode_is_load_B), .is_store(initial_decode_is_store_B), .is_branch(initial_decode_is_branch_B), .is_control_insn(initial_decode_is_control_insn_B)); 

    wire [15:0] decode_instruction_A = (|stall_A) ? 0 : decode_instruction_register_out_A;
    wire [2:0] decode_r1sel_A        = (|stall_A) ? 0 : initial_decode_r1sel_A;
    wire [2:0] decode_r2sel_A        = (|stall_A) ? 0 : initial_decode_r2sel_A; 
    wire [2:0] decode_wsel_A         = (|stall_A) ? 0 : initial_decode_wsel_A;
    wire decode_r1re_A               = (|stall_A) ? 0 : initial_decode_r1re_A; 
    wire decode_r2re_A               = (|stall_A) ? 0 : initial_decode_r2re_A; 
    wire decode_regfile_we_A         = (|stall_A) ? 0 : initial_decode_regfile_we_A; 
    wire decode_nzp_we_A             = (|stall_A) ? 0 : initial_decode_nzp_we_A; 
    wire decode_select_pc_plus_one_A = (|stall_A) ? 0 : initial_decode_select_pc_plus_one_A; 
    wire decode_is_load_A            = (|stall_A) ? 0 : initial_decode_is_load_A;
    wire decode_is_store_A           = (|stall_A) ? 0 : initial_decode_is_store_A;
    wire decode_is_branch_A          = (|stall_A) ? 0 : initial_decode_is_branch_A;
    wire decode_is_control_insn_A    = (|stall_A) ? 0 : initial_decode_is_control_insn_A;

    wire [15:0] decode_instruction_B = (|stall_B) ? 0 : decode_instruction_register_out_B;
    wire [2:0] decode_r1sel_B        = (|stall_B) ? 0 : initial_decode_r1sel_B;
    wire [2:0] decode_r2sel_B        = (|stall_B) ? 0 : initial_decode_r2sel_B; 
    wire [2:0] decode_wsel_B         = (|stall_B) ? 0 : initial_decode_wsel_B;
    wire decode_r1re_B               = (|stall_B) ? 0 : initial_decode_r1re_B; 
    wire decode_r2re_B               = (|stall_B) ? 0 : initial_decode_r2re_B; 
    wire decode_regfile_we_B         = (|stall_B) ? 0 : initial_decode_regfile_we_B; 
    wire decode_nzp_we_B             = (|stall_B) ? 0 : initial_decode_nzp_we_B; 
    wire decode_select_pc_plus_one_B = (|stall_B) ? 0 : initial_decode_select_pc_plus_one_B; 
    wire decode_is_load_B            = (|stall_B) ? 0 : initial_decode_is_load_B;
    wire decode_is_store_B           = (|stall_B) ? 0 : initial_decode_is_store_B;
    wire decode_is_branch_B          = (|stall_B) ? 0 : initial_decode_is_branch_B;
    wire decode_is_control_insn_B    = (|stall_B) ? 0 : initial_decode_is_control_insn_B;

    // Register File
    wire [15:0] decode_rs_output_A, decode_rt_output_A, decode_rs_output_B, decode_rt_output_B;
        
    lc4_regfile_ss #(16) regfile(.clk(clk), .gwe(gwe), .rst(rst), 
                                 .i_rs_A(decode_r1sel_A), .o_rs_data_A(decode_rs_output_A), .i_rt_A(decode_r2sel_A), 
                                 .o_rt_data_A(decode_rt_output_A), .i_rd_A(writeback_wsel_A), .i_wdata_A(register_file_write_input_A), .i_rd_we_A(writeback_regfile_we_A),
                                 .i_rs_B(decode_r1sel_B), .o_rs_data_B(decode_rs_output_B), .i_rt_B(decode_r2sel_B), 
                                 .o_rt_data_B(decode_rt_output_B), .i_rd_B(writeback_wsel_B), .i_wdata_B(register_file_write_input_B), .i_rd_we_B(writeback_regfile_we_B)
                                );

    // EXECUTE
    // Registers
    wire [15:0] alu_rs_input_A, alu_rt_input_A;
    Nbit_reg #(16) execute_alu_rs_register_A(.in(decode_rs_output_A), .out(alu_rs_input_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_alu_rt_register_A(.in(decode_rt_output_A), .out(alu_rt_input_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] execute_r1sel_A, execute_r2sel_A, execute_wsel_A;
    Nbit_reg #(3) execute_r1sel_register_A(.in(decode_r1sel_A), .out(execute_r1sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) execute_r2sel_register_A(.in(decode_r2sel_A), .out(execute_r2sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) execute_wsel_register_A(.in(decode_wsel_A), .out(execute_wsel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    wire execute_is_load_A, execute_is_store_A, execute_regfile_we_A, execute_select_pc_plus_one_A, execute_nzp_we_A, execute_is_branch_A, execute_is_control_insn_A;
    Nbit_reg #(1) execute_is_load_register_A(.in(decode_is_load_A), .out(execute_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_store_register_A(.in(decode_is_store_A), .out(execute_is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_register_file_we_register_A(.in(decode_regfile_we_A), .out(execute_regfile_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_select_pc_plus_one_register_A(.in(decode_select_pc_plus_one_A), .out(execute_select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_nzp_we_register_A(.in(decode_nzp_we_A), .out(execute_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_branch_register_A(.in(decode_is_branch_A), .out(execute_is_branch_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_control_insn_register_A(.in(decode_is_control_insn_A), .out(execute_is_control_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


    wire [15:0] alu_rs_input_B, alu_rt_input_B;
    Nbit_reg #(16) execute_alu_rs_register_B(.in(decode_rs_output_B), .out(alu_rs_input_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_alu_rt_register_B(.in(decode_rt_output_B), .out(alu_rt_input_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] temp_execute_r1sel_B, temp_execute_r2sel_B, temp_execute_wsel_B;
    Nbit_reg #(3) execute_r1sel_register_B(.in(decode_r1sel_B), .out(temp_execute_r1sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) execute_r2sel_register_B(.in(decode_r2sel_B), .out(temp_execute_r2sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) execute_wsel_register_B(.in(decode_wsel_B), .out(temp_execute_wsel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    wire temp_execute_is_load_B, temp_execute_is_store_B, temp_execute_regfile_we_B, temp_execute_select_pc_plus_one_B, temp_execute_nzp_we_B, temp_execute_is_branch_B, temp_execute_is_control_insn_B;
    Nbit_reg #(1) execute_is_load_register_B(.in(decode_is_load_B), .out(temp_execute_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_store_register_B(.in(decode_is_store_B), .out(temp_execute_is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_register_file_we_register_B(.in(decode_regfile_we_B), .out(temp_execute_regfile_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_select_pc_plus_one_register_B(.in(decode_select_pc_plus_one_B), .out(temp_execute_select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_nzp_we_register_B(.in(decode_nzp_we_B), .out(temp_execute_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_branch_register_B(.in(decode_is_branch_B), .out(temp_execute_is_branch_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_control_insn_register_B(.in(decode_is_control_insn_B), .out(temp_execute_is_control_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // These assignments are necessary to flush X.B when X.A is a branch that is taken
    wire [15:0] execute_instruction_register_out_B = (is_flush_A) ? 0 : temp_execute_instruction_register_out_B;
    wire [2:0] execute_r1sel_B                     = (is_flush_A) ? 0 : temp_execute_r1sel_B;
    wire [2:0] execute_r2sel_B                     = (is_flush_A) ? 0 : temp_execute_r2sel_B; 
    wire [2:0] execute_wsel_B                      = (is_flush_A) ? 0 : temp_execute_wsel_B;
    wire execute_regfile_we_B                      = (is_flush_A) ? 0 : temp_execute_regfile_we_B; 
    wire execute_nzp_we_B                          = (is_flush_A) ? 0 : temp_execute_nzp_we_B; 
    wire execute_select_pc_plus_one_B              = (is_flush_A) ? 0 : temp_execute_select_pc_plus_one_B; 
    wire execute_is_load_B                         = (is_flush_A) ? 0 : temp_execute_is_load_B;
    wire execute_is_store_B                        = (is_flush_A) ? 0 : temp_execute_is_store_B;
    wire execute_is_branch_B                       = (is_flush_A) ? 0 : temp_execute_is_branch_B;
    wire execute_is_control_insn_B                 = (is_flush_A) ? 0 : temp_execute_is_control_insn_B;

    // TODO update for both registers
    wire [2:0] branch_instr_nzp_bits_A;
    wire [2:0] branch_instr_nzp_bits_B;
    assign branch_instr_nzp_bits_A = memory_nzp_we_B ? memory_nzp_bits_B 
                                   : memory_nzp_we_A ? memory_nzp_bits_A 
                                   : writeback_nzp_we_B ? writeback_nzp_bits_B 
                                   : writeback_nzp_we_A ? writeback_nzp_bits_A 
                                   : nzp;
    assign branch_instr_nzp_bits_B = branch_instr_nzp_bits_A;
    wire branch_is_taken_A = !((execute_instruction_register_out_A[11:9] & branch_instr_nzp_bits_A) == 3'b000);
    wire branch_is_taken_B = !((execute_instruction_register_out_B[11:9] & branch_instr_nzp_bits_B) == 3'b000);
    wire is_flush_A = ((execute_is_branch_A && branch_is_taken_A) || execute_is_control_insn_A);
    wire is_flush_B = ((execute_is_branch_B && branch_is_taken_B) || execute_is_control_insn_B);

    // Identify NZP bits upon reading the Execute Stage instruction and store these NZP bits into their own register (which will then be passed to the  
    // Memory/Writeback stages and, eventually, the NZP register itself)
    wire [2:0] execute_nzp_bits_A;
    assign execute_nzp_bits_A[2] = execute_output_result_A[15];
    assign execute_nzp_bits_A[1] = (execute_output_result_A == 16'h0000);
    assign execute_nzp_bits_A[0] = (!execute_nzp_bits_A[2]) & (!execute_nzp_bits_A[1]);

    wire [2:0] execute_nzp_bits_B;
    assign execute_nzp_bits_B[2] = execute_output_result_B[15];
    assign execute_nzp_bits_B[1] = (execute_output_result_B == 16'h0000);
    assign execute_nzp_bits_B[0] = (!execute_nzp_bits_B[2]) & (!execute_nzp_bits_B[1]);

    // Bypassing
    wire [15:0] possibly_bypassed_alu_rs_input_A = (execute_r1sel_A == memory_wsel_B && memory_regfile_we_B) ? memory_O_B
                                                 : (execute_r1sel_A == memory_wsel_A && memory_regfile_we_A) ? memory_O_A
                                                 : (execute_r1sel_A == writeback_wsel_B && writeback_regfile_we_B) ? register_file_write_input_B
                                                 : (execute_r1sel_A == writeback_wsel_A && writeback_regfile_we_A) ? register_file_write_input_A
                                                 : alu_rs_input_A;

    wire [15:0] possibly_bypassed_alu_rt_input_A = (execute_r2sel_A == memory_wsel_B && memory_regfile_we_B) ? memory_O_B
                                                 : (execute_r2sel_A == memory_wsel_A && memory_regfile_we_A) ? memory_O_A
                                                 : (execute_r2sel_A == writeback_wsel_B && writeback_regfile_we_B) ? register_file_write_input_B
                                                 : (execute_r2sel_A == writeback_wsel_A && writeback_regfile_we_A) ? register_file_write_input_A
                                                 : alu_rt_input_A;

    wire [15:0] possibly_bypassed_alu_rs_input_B = (execute_r1sel_B == memory_wsel_B && memory_regfile_we_B) ? memory_O_B
                                                 : (execute_r1sel_B == memory_wsel_A && memory_regfile_we_A) ? memory_O_A
                                                 : (execute_r1sel_B == writeback_wsel_B && writeback_regfile_we_B) ? register_file_write_input_B
                                                 : (execute_r1sel_B == writeback_wsel_A && writeback_regfile_we_A) ? register_file_write_input_A
                                                 : alu_rs_input_B;

    wire [15:0] possibly_bypassed_alu_rt_input_B = (execute_r2sel_B == memory_wsel_B && memory_regfile_we_B) ? memory_O_B
                                                 : (execute_r2sel_B == memory_wsel_A && memory_regfile_we_A) ? memory_O_A
                                                 : (execute_r2sel_B == writeback_wsel_B && writeback_regfile_we_B) ? register_file_write_input_B
                                                 : (execute_r2sel_B == writeback_wsel_A && writeback_regfile_we_A) ? register_file_write_input_A
                                                 : alu_rt_input_B;

 
    wire [15:0] alu_output_A;
    lc4_alu alu_A(.i_insn(execute_instruction_register_out_A), .i_pc(execute_pc_register_out_A), .i_r1data(possibly_bypassed_alu_rs_input_A), .i_r2data(possibly_bypassed_alu_rt_input_A), .o_result(alu_output_A));   
    wire [15:0] execute_output_result_A = execute_select_pc_plus_one_A ? execute_pc_plus_one_A : alu_output_A;

    wire [15:0] alu_output_B;
    lc4_alu alu_B(.i_insn(execute_instruction_register_out_B), .i_pc(execute_pc_register_out_B), .i_r1data(possibly_bypassed_alu_rs_input_B), .i_r2data(possibly_bypassed_alu_rt_input_B), .o_result(alu_output_B));   
    wire [15:0] execute_output_result_B = execute_select_pc_plus_one_B ? execute_pc_plus_one_B : alu_output_B;

    // DATA MEMORY
    // Registers
    wire [15:0] memory_O_A, unbypassed_memory_B_A;
    Nbit_reg #(16) memory_O_register_A(.in(execute_output_result_A), .out(memory_O_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_B_register_A(.in(possibly_bypassed_alu_rt_input_A), .out(unbypassed_memory_B_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] memory_wsel_A, memory_r2sel_A, memory_nzp_bits_A;
    Nbit_reg #(3) memory_wsel_register_A(.in(execute_wsel_A), .out(memory_wsel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) memory_r2sel_register_A(.in(execute_r2sel_A), .out(memory_r2sel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) memory_nzp_register_A(.in(execute_nzp_bits_A), .out(memory_nzp_bits_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire memory_is_load_A, memory_is_store_A, memory_regfile_we_A, memory_select_pc_plus_one_A, memory_nzp_we_A;
    Nbit_reg #(1) memory_is_load_register_A(.in(execute_is_load_A), .out(memory_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_is_store_register_A(.in(execute_is_store_A), .out(memory_is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_register_file_we_register_A(.in(execute_regfile_we_A), .out(memory_regfile_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_select_pc_plus_one_register_A(.in(execute_select_pc_plus_one_A), .out(memory_select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_nzp_we_register_A(.in(execute_nzp_we_A), .out(memory_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] memory_O_B, unbypassed_memory_B_B;
    Nbit_reg #(16) memory_O_register_B(.in(execute_output_result_B), .out(memory_O_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_B_register_B(.in(possibly_bypassed_alu_rt_input_B), .out(unbypassed_memory_B_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] memory_wsel_B, memory_r2sel_B, memory_nzp_bits_B;
    Nbit_reg #(3) memory_wsel_register_B(.in(execute_wsel_B), .out(memory_wsel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) memory_r2sel_register_B(.in(execute_r2sel_B), .out(memory_r2sel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) memory_nzp_register_B(.in(execute_nzp_bits_B), .out(memory_nzp_bits_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire memory_is_load_B, memory_is_store_B, memory_regfile_we_B, memory_select_pc_plus_one_B, memory_nzp_we_B;
    Nbit_reg #(1) memory_is_load_register_B(.in(execute_is_load_B), .out(memory_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_is_store_register_B(.in(execute_is_store_B), .out(memory_is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_register_file_we_register_B(.in(execute_regfile_we_B), .out(memory_regfile_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_select_pc_plus_one_register_B(.in(execute_select_pc_plus_one_B), .out(memory_select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_nzp_we_register_B(.in(execute_nzp_we_B), .out(memory_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] memory_B_A = (memory_is_store_A && writeback_regfile_we_B && (writeback_wsel_B == memory_r2sel_A)) ? register_file_write_input_B 
                           : (memory_is_store_A && writeback_regfile_we_A && (writeback_wsel_A == memory_r2sel_A)) ? register_file_write_input_A 
                           : unbypassed_memory_B_A;
    wire [15:0] memory_B_B = (memory_is_store_B && (memory_r2sel_B == memory_wsel_A) && memory_regfile_we_A) ? memory_O_A
                           : (memory_is_store_B && writeback_regfile_we_B && (writeback_wsel_B == memory_r2sel_B)) ? register_file_write_input_B 
                           : (memory_is_store_B && writeback_regfile_we_A && (writeback_wsel_A == memory_r2sel_B)) ? register_file_write_input_A 
                           : unbypassed_memory_B_B;

    wire        dmem_we_A = memory_is_store_A;
    wire [15:0] dmem_towrite_A = memory_is_load_A ? i_cur_dmem_data : memory_is_store_A ? memory_B_A : 16'b0;
    wire [15:0] dmem_addr_A = (memory_is_load_A | memory_is_store_A) ? memory_O_A : 16'b0;
    wire        dmem_we_B = memory_is_store_B;
    wire [15:0] dmem_towrite_B = memory_is_load_B ? i_cur_dmem_data : memory_is_store_B ? memory_B_B : 16'b0;
    wire [15:0] dmem_addr_B = (memory_is_load_B | memory_is_store_B) ? memory_O_B : 16'b0;

    assign o_dmem_we = dmem_we_A | dmem_we_B;
    assign o_dmem_towrite = memory_is_load_B || memory_is_store_B ? dmem_towrite_B : dmem_towrite_A;
    assign o_dmem_addr = memory_is_load_B || memory_is_store_B ? dmem_addr_B : dmem_addr_A;
  

    // WRITEBACK
    // Registers
    wire [15:0] writeback_O_A, writeback_D_A;
    Nbit_reg #(16) writeback_O_register_A(.in(memory_O_A), .out(writeback_O_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_D_register_A(.in(i_cur_dmem_data), .out(writeback_D_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] writeback_wsel_A, writeback_nzp_bits_A;
    Nbit_reg #(3) writeback_wsel_register_A(.in(memory_wsel_A), .out(writeback_wsel_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) writeback_nzp_register_A(.in(memory_nzp_bits_A), .out(writeback_nzp_bits_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire writeback_is_load_A, writeback_regfile_we_A, writeback_select_pc_plus_one_A, writeback_nzp_we_A;
    Nbit_reg #(1) writeback_is_load_register_A(.in(memory_is_load_A), .out(writeback_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_register_file_we_register_A(.in(memory_regfile_we_A), .out(writeback_regfile_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_select_pc_plus_one_register_A(.in(memory_select_pc_plus_one_A), .out(writeback_select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_nzp_we_register_A(.in(memory_nzp_we_A), .out(writeback_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] writeback_O_B, writeback_D_B;
    Nbit_reg #(16) writeback_O_register_B(.in(memory_O_B), .out(writeback_O_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_D_register_B(.in(i_cur_dmem_data), .out(writeback_D_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] writeback_wsel_B, writeback_nzp_bits_B;
    Nbit_reg #(3) writeback_wsel_register_B(.in(memory_wsel_B), .out(writeback_wsel_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) writeback_nzp_register_B(.in(memory_nzp_bits_B), .out(writeback_nzp_bits_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire writeback_is_load_B, writeback_regfile_we_B, writeback_select_pc_plus_one_B, writeback_nzp_we_B;
    Nbit_reg #(1) writeback_is_load_register_B(.in(memory_is_load_B), .out(writeback_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_register_file_we_register_B(.in(memory_regfile_we_B), .out(writeback_regfile_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_select_pc_plus_one_register_B(.in(memory_select_pc_plus_one_B), .out(writeback_select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_nzp_we_register_B(.in(memory_nzp_we_B), .out(writeback_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // Regfile Writeback
    wire [15:0] register_file_write_input_A;
    assign register_file_write_input_A = writeback_is_load_A ? writeback_D_A
                                       : writeback_O_A;

    wire [15:0] register_file_write_input_B;
    assign register_file_write_input_B = writeback_is_load_B ? writeback_D_B
                                       : writeback_O_B;

    // NZP
    wire n_bit_A = (writeback_is_load_A) ? register_file_write_input_A[15] : writeback_nzp_bits_A[2];
    wire z_bit_A = (writeback_is_load_A) ? ~(|register_file_write_input_A) : writeback_nzp_bits_A[1];
    wire p_bit_A = (writeback_is_load_A) ? ~(n_bit_A | z_bit_A) : writeback_nzp_bits_A[0];
    wire [2:0] new_nzp_A = {n_bit_A, z_bit_A, p_bit_A};

    wire n_bit_B = (writeback_is_load_B) ? register_file_write_input_B[15] : writeback_nzp_bits_B[2];
    wire z_bit_B = (writeback_is_load_B) ? ~(|register_file_write_input_B) : writeback_nzp_bits_B[1];
    wire p_bit_B = (writeback_is_load_B) ? ~(n_bit_B | z_bit_B) : writeback_nzp_bits_B[0];
    wire [2:0] new_nzp_B = {n_bit_B, z_bit_B, p_bit_B};

    wire [2:0] nzp;
    Nbit_reg #(3) nzp_register(.in(writeback_nzp_we_B ? new_nzp_B : new_nzp_A), .out(nzp), .clk(clk), .we(writeback_nzp_we_A | writeback_nzp_we_B), .gwe(gwe), .rst(rst));


    // TESTING
    assign test_regfile_data_A = register_file_write_input_A;
    assign test_cur_insn_A = writeback_instruction_register_out_A;
    assign test_cur_pc_A = writeback_pc_register_out_A;
    assign test_regfile_wsel_A = writeback_wsel_A;
    assign test_regfile_we_A = writeback_regfile_we_A;
    assign test_nzp_new_bits_A = new_nzp_A;
    assign test_nzp_we_A = writeback_nzp_we_A;
    assign test_stall_A = writeback_stall_register_out_A; 

    Nbit_reg #(1) test_o_dmem_we_register_A(.in(dmem_we_A), .out(test_dmem_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) test_o_dmem_data_register_A(.in(dmem_towrite_A), .out(test_dmem_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) test_o_dmem_addr_register_A(.in(dmem_addr_A), .out(test_dmem_addr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    assign test_regfile_data_B = register_file_write_input_B;
    assign test_cur_insn_B = writeback_instruction_register_out_B;
    assign test_cur_pc_B = writeback_pc_register_out_B;
    assign test_regfile_wsel_B = writeback_wsel_B;
    assign test_regfile_we_B = writeback_regfile_we_B;
    assign test_nzp_new_bits_B = new_nzp_B;
    assign test_nzp_we_B = writeback_nzp_we_B;
    assign test_stall_B = writeback_stall_register_out_B; 

    Nbit_reg #(1) test_o_dmem_we_register_B(.in(dmem_we_B), .out(test_dmem_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) test_o_dmem_data_register_B(.in(dmem_towrite_B), .out(test_dmem_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) test_o_dmem_addr_register_B(.in(dmem_addr_B), .out(test_dmem_addr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);
      // $display("D pc + 1 select B = %h", decode_select_pc_plus_one_B);
      // $display("D pc  A = %h", decode_pc_register_out_A);
      // $display("D pc  B = %h", decode_pc_register_out_B);
      // $display("D pc + 1 A = %h", decode_pc_plus_one_A);
      // $display("D pc + 1 B = %h", decode_pc_plus_one_B);

      // $display("X pc + 1 select A = %h", execute_select_pc_plus_one_A);
      // $display("X pc + 1 select B = %h", execute_select_pc_plus_one_B);
      // $display("X pc  A = %h", execute_pc_register_out_A);
      // $display("X pc  B = %h", execute_pc_register_out_B);
      // $display("X pc + 1 A = %h", execute_pc_plus_one_A);
      // $display("X pc + 1 B = %h", execute_pc_plus_one_B);
      // $display("X ALU out A = %h", execute_output_result_A);
      // $display("X ALU out B = %h", execute_output_result_B);
      // $display("memory_nzp_bits_A = %3b", memory_nzp_bits_A);
      // $display("writeback_nzp_bits_A = %3b", writeback_nzp_bits_A);
      // $display();
      // $display("memory_nzp_bits_B = %3b", memory_nzp_bits_B);
      // $display("writeback_nzp_bits_B = %3b", writeback_nzp_bits_B);
      // $display();
      // $display("nzp = %3b", nzp);
      // $display();
      // $display("execute_instruction_register_out_A[11:9] = %3b", execute_instruction_register_out_A[11:9]);
      // $display("branch_instr_nzp_bits_A = %3b", branch_instr_nzp_bits_A);
      // $display();
      // $display("execute_instruction_register_out_B[11:9] = %3b", execute_instruction_register_out_B[11:9]);
      // $display("branch_instr_nzp_bits_B = %3b", branch_instr_nzp_bits_B);
      // $display();
      // $display("branch_is_taken_A = %b", branch_is_taken_A);
      // $display("branch_is_taken_B = %b", branch_is_taken_B);
      // $display();
      // $display("execute_is_branch_A = %b", execute_is_branch_A);
      // $display("execute_is_branch_B = %b", execute_is_branch_B);
      // $display();
      // $display("is_flush_A = %h", is_flush_A);
      // $display("is_flush_B = %h", is_flush_B);
      // $display("stall_A = %h", stall_A);
      // $display("stall_B = %h", stall_B);
      // $display("is_load_use_XA_DA = %d", is_load_use_XA_DA);
      // $display("is_load_use_XA_DB = %d", is_load_use_XA_DB);
      // $display("is_load_use_XB_DB = %d", is_load_use_XB_DB);
      // $display("is_superscalar_stall = %d", is_superscalar_stall);
      // $display("both_decode_insns_are_memory_insns = %d", both_decode_insns_are_memory_insns);
      // $display("------------------------------");

      // $display("%h\t", writeback_pc_register_out_A);
      // pinstr(writeback_instruction_register_out_A);
      // $display();
      // $display("alu_output_A = %h", execute_output_result_A);

      // $display("%h\t", writeback_pc_register_out_B);
      // pinstr(writeback_instruction_register_out_B);
      // $display();
      // $display("alu_output_B = %h", execute_output_result_B);
      // $display();

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
