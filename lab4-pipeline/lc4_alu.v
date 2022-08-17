/* INSERT NAME AND PENNKEY HERE 

Riju Datta - 45039816
Aidan Barr Bono

*/

`timescale 1ns / 1ps
`default_nettype none

// NOTE: MOD is in the shift op-code space, so I count it as a shift and not 
// an arithmetic op just to make things a little bit easier coding wise

module lc4_alu(input wire [15:0] i_insn,
               input wire [15:0] i_pc,
               input wire [15:0] i_r1data,
               input wire [15:0] i_r2data,
               output wire [15:0] o_result);

    // op code flags
    wire [3:0] op_code = i_insn[15:12];
    wire is_branch  = op_code == 4'b0000;
    wire is_mem     = op_code == 4'b0110 | op_code == 4'b0111;
    wire is_arith   = op_code == 4'b0001;
    wire is_cmp     = op_code == 4'b0010;
    wire is_logic   = op_code == 4'b0101;
    wire is_rti     = op_code == 4'b1000;
    wire is_const   = op_code == 4'b1001;
    wire is_shift   = op_code == 4'b1010;
    wire is_hiconst = op_code == 4'b1101;
    wire is_trap    = op_code == 4'b1111;

    wire is_jsrr = i_insn[15:11] == 5'b01000;
    wire is_jsr  = i_insn[15:11] == 5'b01001;
    wire is_jmpr = i_insn[15:11] == 5'b11000;
    wire is_jmp  = i_insn[15:11] == 5'b11001;
    
    // sub op code flags
    wire is_add  = i_insn[5:3] == 3'b000;
    wire is_mul  = i_insn[5:3] == 3'b001;
    wire is_sub  = i_insn[5:3] == 3'b010;
    wire is_div  = i_insn[5:3] == 3'b011;
    wire is_addi = i_insn[5] == 1'b1;
    wire is_and  = is_add;
    wire is_not  = is_mul;
    wire is_or   = is_sub;
    wire is_xor  = is_div;
    wire is_andi = is_addi;
    
    wire is_cmp_sgn = i_insn[7] == 1'b0;
    wire is_cmp_imm = i_insn[8] == 1'b1;
    
    wire is_shl = i_insn[5:4] == 2'b00;
    wire is_sra = i_insn[5:4] == 2'b01;
    wire is_srl = i_insn[5:4] == 2'b10;
    wire is_mod = i_insn[5:4] == 2'b11;
    
    // CLA OPS
    wire [15:0] aluin1, aluin2, aluout;
    wire alucin;

    assign aluin1 = is_branch | is_jmp ? i_pc 
                  : is_mem | is_arith  ? i_r1data 
                  : 0;

    assign aluin2 = is_branch ? {{7{i_insn[8]}}, i_insn[8:0]} 
                  : is_jmp    ? {{5{i_insn[10]}}, i_insn[10:0]}
                  : is_mem    ? {{10{i_insn[5]}}, i_insn[5:0]}
                  : is_arith  ? (
                      is_add  ? i_r2data
                    : is_sub  ? ~i_r2data  
                    : is_addi ? {{11{i_insn[4]}}, i_insn[4:0]}
                    : 0
                  )
                  : 0;

    assign alucin = (is_branch | is_jmp | (is_arith & is_sub));

    cla16 add(.a(aluin1), .b(aluin2), .cin(alucin), .sum(aluout));
    
    // MUL, DIV, MOD
    wire [15:0] mul_out, div_out, mod_out;
    assign mul_out = i_r1data * i_r2data;
    lc4_divider div(.i_dividend(i_r1data), .i_divisor(i_r2data), .o_remainder(mod_out), .o_quotient(div_out));
    
    // COMPARISONS
    wire [15:0] cmp_lhs, cmp_rhs, cmp_out;
    assign cmp_lhs = i_r1data;
    assign cmp_rhs = is_cmp_imm ? (
                       is_cmp_sgn ? {{10{i_insn[6]}}, i_insn[6:0]}
                     : {10'b0, i_insn[6:0]}
                   )
                   : i_r2data;
    
    assign cmp_out = is_cmp_sgn ? (
                       $signed(cmp_lhs) < $signed(cmp_rhs) ? 16'hffff
                     : $signed(cmp_lhs) > $signed(cmp_rhs) ? 16'h0001
                     : 16'h0000
                     )
                   : (
                       cmp_lhs < cmp_rhs ? 16'hffff
                     : cmp_lhs > cmp_rhs ? 16'h0001
                     : 16'h0000
                     );
    
    // LOGICAL OPS
    wire [15:0] logical_out = is_and ? i_r1data & i_r2data
                            : is_not ? ~i_r1data
                            : is_or  ? i_r1data | i_r2data
                            : is_xor ? i_r1data ^ i_r2data
                            : i_r1data & {{11{i_insn[4]}}, i_insn[4:0]};
    
    // SHIFTS
    wire [15:0] shift_out = is_shl ? i_r1data << i_insn[3:0]
                          : is_sra ? $signed($signed(i_r1data) >>> i_insn[3:0])
                          : is_srl ? i_r1data >> i_insn[3:0]
                          : mod_out;
                    
    // final mux
    assign o_result = is_branch | is_jmp | is_mem | (is_arith & (is_add | is_sub | is_addi)) ? aluout
                    : (is_arith & is_mul) ? mul_out
                    : (is_arith & is_div) ? div_out
                    : is_cmp ? cmp_out
                    : is_jsrr | is_jmpr ? i_r1data
                    : is_jsr ? (i_pc & 16'h8000) | ({1'b0, i_insn[10:0], 4'b0000})
                    : is_logic ? logical_out
                    : is_rti ? i_r1data
                    : is_const ? {{7{i_insn[8]}}, i_insn[8:0]}
                    : is_shift ? shift_out                            // MOD counts as a shift op
                    : is_hiconst ? {i_insn[7:0], i_r1data[7:0]}
                    : is_trap ? {8'h80 , i_insn[7:0]}
                    : 16'b0;

endmodule
