/* TODO: name and PennKeys of all group members here */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk, // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory - assigned
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter - assigned
    output wire [15:0] test_cur_insn, // Testbench: instruction bits - assigned
    output wire        test_regfile_we, // Testbench: register file write enable - assigned
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file - assigned
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable - assigned
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   
    // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)

    // pc wires attached to the PC register's ports
    wire [15:0]   pc;      // Current program counter (read out from pc_reg)
    wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(!is_load_use), .gwe(gwe), .rst(rst));


    // PIPELINE REGISTERS

    // For branch prediction purposes, create a wire for decode_instruction_register.in that will select between i_cur_insn or 16'h0000 based on whether the 
    // register should be flushed
    wire [15:0] decode_instruction_register_in = (is_flush) ? (16'h0000) : i_cur_insn;

    // Instruction Registers
    wire [15:0] decode_instruction_register_out, execute_instruction_register_out, memory_instruction_register_out, writeback_instruction_register_out;
    Nbit_reg #(16) decode_instruction_register(.in(decode_instruction_register_in), .out(decode_instruction_register_out), .clk(clk), .we(!is_load_use), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_instruction_register(.in(decode_instruction), .out(execute_instruction_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_instruction_register(.in(execute_instruction_register_out), .out(memory_instruction_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_instruction_register(.in(memory_instruction_register_out), .out(writeback_instruction_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // PC Registers
    wire [15:0] decode_pc_register_out, execute_pc_register_out, memory_pc_register_out, writeback_pc_register_out;
    Nbit_reg #(16) decode_pc_register(.in(pc), .out(decode_pc_register_out), .clk(clk), .we(!(|stall)), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_pc_register(.in(decode_pc_register_out), .out(execute_pc_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_pc_register(.in(execute_pc_register_out), .out(memory_pc_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_pc_register(.in(memory_pc_register_out), .out(writeback_pc_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // PC plus one
    wire [15:0] decode_pc_plus_one, execute_pc_plus_one;
    Nbit_reg #(16) decode_pc_plus_one_register(.in(pc_plus_one), .out(decode_pc_plus_one), .clk(clk), .we(!(|stall)), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_pc_plus_one_register(.in(decode_pc_plus_one), .out(execute_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    // Stall Registers
    wire [1:0] decode_stall_register_out, execute_stall_register_out, memory_stall_register_out, writeback_stall_register_out;
    Nbit_reg #(2, 2'b10) decode_stall_register(.in(is_flush ? 2'b10 : 2'b0), .out(decode_stall_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) execute_stall_register(.in((|stall) ? stall : decode_stall_register_out), .out(execute_stall_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) memory_stall_register(.in(execute_stall_register_out), .out(memory_stall_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) writeback_stall_register(.in(memory_stall_register_out), .out(writeback_stall_register_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    // Stall Logic (load-to-use dependency handling)
    wire is_load_use = execute_is_load && (initial_decode_r1re && (initial_decode_r1sel == execute_wsel) || (initial_decode_r2re && (initial_decode_r2sel == execute_wsel) && (!initial_decode_is_store)) || initial_decode_is_branch);
    wire [1:0] stall = is_load_use ? 2'b11 
                     : is_flush ? 2'b10 
                     : 2'b00;

    // TODO (for next time i think hahahahahahah ! >:] )
    // PROGRAM COUNTER
    wire pc_internal_mux = | (i_cur_insn[11:9] & nzp);
    wire [15:0] pc_plus_one;
    cla16 pc_incrementer(.a(pc), .b(16'b0), .cin(1'b1), .sum(pc_plus_one));
    assign o_cur_pc = pc;
    assign next_pc = is_flush ? alu_output : pc_plus_one;


    // DECODE
    wire [2:0] initial_decode_r1sel, initial_decode_r2sel, initial_decode_wsel;
    wire initial_decode_r1re, initial_decode_r2re, initial_decode_regfile_we, initial_decode_nzp_we, initial_decode_select_pc_plus_one, initial_decode_is_load, initial_decode_is_store, initial_decode_is_branch, initial_decode_is_control_insn;
    lc4_decoder decoder(.insn(decode_instruction_register_out), .r1sel(initial_decode_r1sel), .r1re(initial_decode_r1re), .r2sel(initial_decode_r2sel), .r2re(initial_decode_r2re), .wsel(initial_decode_wsel), 
                        .regfile_we(initial_decode_regfile_we), .nzp_we(initial_decode_nzp_we), .select_pc_plus_one(initial_decode_select_pc_plus_one), 
                        .is_load(initial_decode_is_load), .is_store(initial_decode_is_store), .is_branch(initial_decode_is_branch), .is_control_insn(initial_decode_is_control_insn)); 

    wire [15:0] decode_instruction = (|stall) ? 0 : decode_instruction_register_out;
    wire [2:0] decode_r1sel        = (|stall) ? 0 : initial_decode_r1sel;
    wire [2:0] decode_r2sel        = (|stall) ? 0 : initial_decode_r2sel; 
    wire [2:0] decode_wsel         = (|stall) ? 0 : initial_decode_wsel;
    wire decode_r1re               = (|stall) ? 0 : initial_decode_r1re; 
    wire decode_r2re               = (|stall) ? 0 : initial_decode_r2re; 
    wire decode_regfile_we         = (|stall) ? 0 : initial_decode_regfile_we; 
    wire decode_nzp_we             = (|stall) ? 0 : initial_decode_nzp_we; 
    wire decode_select_pc_plus_one = (|stall) ? 0 : initial_decode_select_pc_plus_one; 
    wire decode_is_load            = (|stall) ? 0 : initial_decode_is_load;
    wire decode_is_store           = (|stall) ? 0 : initial_decode_is_store;
    wire decode_is_branch          = (|stall) ? 0 : initial_decode_is_branch;
    wire decode_is_control_insn    = (|stall) ? 0 : initial_decode_is_control_insn;

    // Register File
    wire [15:0] register_decode_rs_output, register_decode_rt_output;
    lc4_regfile #(16) regfile(.clk(clk), .gwe(gwe), .rst(rst), .i_rs(decode_r1sel), .o_rs_data(register_decode_rs_output), .i_rt(decode_r2sel), 
                              .o_rt_data(register_decode_rt_output), .i_rd(writeback_wsel), .i_wdata(register_file_write_input), .i_rd_we(writeback_regfile_we));

    // WD bypass
    wire [15:0] decode_rs_output = (decode_r1sel == writeback_wsel && writeback_regfile_we) ? register_file_write_input : register_decode_rs_output;
    wire [15:0] decode_rt_output = (decode_r2sel == writeback_wsel && writeback_regfile_we) ? register_file_write_input : register_decode_rt_output;

    // EXECUTE
    // Registers
    wire [15:0] alu_input_A, alu_input_B;
    Nbit_reg #(16) execute_alu_A_register(.in(decode_rs_output), .out(alu_input_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) execute_alu_B_register(.in(decode_rt_output), .out(alu_input_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] execute_r1sel, execute_r2sel, execute_wsel;
    Nbit_reg #(3) execute_r1sel_register(.in(decode_r1sel), .out(execute_r1sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) execute_r2sel_register(.in(decode_r2sel), .out(execute_r2sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) execute_wsel_register(.in(decode_wsel), .out(execute_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
    wire execute_is_load, execute_is_store, execute_regfile_we, execute_select_pc_plus_one, execute_nzp_we;
    Nbit_reg #(1) execute_is_load_register(.in(decode_is_load), .out(execute_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_store_register(.in(decode_is_store), .out(execute_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_register_file_we_register(.in(decode_regfile_we), .out(execute_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_select_pc_plus_one_register(.in(decode_select_pc_plus_one), .out(execute_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_nzp_we_register(.in(decode_nzp_we), .out(execute_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // We need execute_is_branch_register and execute_is_control_insn_register in order to properly implement branch logic
    wire execute_is_branch, execute_is_control_insn;
    Nbit_reg #(1) execute_is_branch_register(.in(decode_is_branch), .out(execute_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) execute_is_control_insn_register(.in(decode_is_control_insn), .out(execute_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    // We also need to check assign branch logic NZP bits to determine whether a branch instruction is taken
    wire [2:0] branch_instr_nzp_bits;
    assign branch_instr_nzp_bits = (memory_nzp_we) ? (memory_nzp_bits) : (writeback_nzp_we) ? writeback_nzp_bits : nzp;
    wire branch_is_taken = !((execute_instruction_register_out[11:9] & branch_instr_nzp_bits) == 3'b000);
    
    wire is_flush = ((execute_is_branch && branch_is_taken) | execute_is_control_insn);

    // Identify NZP bits upon reading the Execute Stage instruction and store these NZP bits into their own register (which will then be passed to the  
    // Memory/Writeback stages and, eventually, the NZP register itself)
    wire [2:0] execute_nzp_bits;
    assign execute_nzp_bits[2] = execute_output_result[15];
    assign execute_nzp_bits[1] = (execute_output_result == 16'h0000);
    assign execute_nzp_bits[0] = (!execute_nzp_bits[2]) & (!execute_nzp_bits[1]);

    // Bypassing
    wire [15:0] possibly_bypassed_alu_input_A = (execute_r1sel == memory_wsel && memory_regfile_we) ? memory_O
                                              : (execute_r1sel == writeback_wsel && writeback_regfile_we) ? register_file_write_input
                                              : alu_input_A;
    wire [15:0] possibly_bypassed_alu_input_B = (execute_r2sel == memory_wsel && memory_regfile_we) ? memory_O
                                              : (execute_r2sel == writeback_wsel && writeback_regfile_we) ? register_file_write_input
                                              : alu_input_B;
 
    wire [15:0] alu_output;
    lc4_alu alu(.i_insn(execute_instruction_register_out), .i_pc(execute_pc_register_out), .i_r1data(possibly_bypassed_alu_input_A), .i_r2data(possibly_bypassed_alu_input_B), .o_result(alu_output));   
    
    // This value will be used to determine the execute_nzp_bits
    wire [15:0] execute_output_result = execute_select_pc_plus_one ? execute_pc_plus_one : alu_output;

    // DATA MEMORY
    // Registers
    wire [15:0] memory_O, unbypassed_memory_B;
    Nbit_reg #(16) memory_O_register(.in(execute_output_result), .out(memory_O), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) memory_B_register(.in(possibly_bypassed_alu_input_B), .out(unbypassed_memory_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] memory_wsel, memory_r2sel;
    Nbit_reg #(3) memory_wsel_register(.in(execute_wsel), .out(memory_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3) memory_r2sel_register(.in(execute_r2sel), .out(memory_r2sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire memory_is_load, memory_is_store, memory_regfile_we, memory_select_pc_plus_one, memory_nzp_we;
    wire [2:0] memory_nzp_bits;
    Nbit_reg #(1) memory_is_load_register(.in(execute_is_load), .out(memory_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_is_store_register(.in(execute_is_store), .out(memory_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_register_file_we_register(.in(execute_regfile_we), .out(memory_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_select_pc_plus_one_register(.in(execute_select_pc_plus_one), .out(memory_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) memory_nzp_we_register(.in(execute_nzp_we), .out(memory_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) memory_nzp_register(.in(execute_nzp_bits), .out(memory_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [15:0] memory_B = (memory_is_store & writeback_is_load & (writeback_wsel == memory_r2sel)) ? register_file_write_input : unbypassed_memory_B;

    assign o_dmem_we = memory_is_store;
   
    assign o_dmem_towrite = memory_is_load ? i_cur_dmem_data : memory_is_store ? memory_B : 16'b0;

    assign o_dmem_addr = (memory_is_load | memory_is_store) ? memory_O : 16'b0;
 

    // WRITEBACK
    // Registers
    wire [15:0] writeback_O, writeback_D;
    Nbit_reg #(16) writeback_O_register(.in(memory_O), .out(writeback_O), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) writeback_D_register(.in(i_cur_dmem_data), .out(writeback_D), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire [2:0] writeback_wsel;
    Nbit_reg #(3) writeback_wsel_register(.in(memory_wsel), .out(writeback_wsel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    wire writeback_is_load, writeback_regfile_we, writeback_select_pc_plus_one, writeback_nzp_we;
    wire [2:0] writeback_nzp_bits;
    Nbit_reg #(1) writeback_is_load_register(.in(memory_is_load), .out(writeback_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_register_file_we_register(.in(memory_regfile_we), .out(writeback_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_select_pc_plus_one_register(.in(memory_select_pc_plus_one), .out(writeback_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1) writeback_nzp_we_register(.in(memory_nzp_we), .out(writeback_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b000) writeback_nzp_register(.in(memory_nzp_bits), .out(writeback_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    // Regfile Writeback
    wire [15:0] register_file_write_input;
    assign register_file_write_input = writeback_is_load ? writeback_D
                                     : writeback_O;

    // NZP - LDR insns will need data memory output, while JSRR/JSR/TRAP instructions will need PC + 1 output to properly
    // update NZP bits

    // Here, we must now mux between the NZP bits in writeback_nzp_register or, if the instruction is a LDR, the NZP bits as defined by 
    // register_file_write_input
    wire n_bit = (writeback_is_load) ? register_file_write_input[15] : writeback_nzp_bits[2];
    wire z_bit = (writeback_is_load) ? ~(|register_file_write_input) : writeback_nzp_bits[1];
    wire p_bit = (writeback_is_load) ? ~(n_bit | z_bit) : writeback_nzp_bits[0];
    wire [2:0] new_nzp = {n_bit, z_bit, p_bit};

    wire [2:0] nzp;
    Nbit_reg #(3) nzp_register(.in(new_nzp), .out(nzp), .clk(clk), .we(writeback_nzp_we), .gwe(gwe), .rst(rst));


    // TESTING
    assign test_regfile_data = register_file_write_input;
    assign test_cur_insn = writeback_instruction_register_out;
    assign test_cur_pc = writeback_pc_register_out;
    assign test_regfile_wsel = writeback_wsel;
    assign test_regfile_we = writeback_regfile_we;
    assign test_nzp_new_bits = new_nzp;
    assign test_nzp_we = writeback_nzp_we;
    assign test_stall = writeback_stall_register_out; 

    Nbit_reg #(1) test_o_dmem_we_register(.in(o_dmem_we), .out(test_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) test_o_dmem_data_register(.in(o_dmem_towrite), .out(test_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) test_o_dmem_addr_register(.in(o_dmem_addr), .out(test_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    /* Add $display(...) calls in the always block below to
     * print out debug information at the end of every cycle.
     * 
     * You may also use if statements inside the always block
     * to conditionally print out information.
     *
     * You do not need to resynthesize and re-implement if this is all you change;
     * just restart the simulation.
     */
`ifndef NDEBUG
      `include "print_points.v"
      `include "include/lc4_prettyprint_errors.v"
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.
      
      // pinstr(writeback_instruction_register_out);
      // $display();
      // $display("%d pc:initial_decode_r1re &&  %h stall: %b ins_nzp: %h is_flush: %h  pc+1_sel: %h alu_out: %h", $time, writeback_pc_register_out, stall, branch_instr_nzp_bits, is_flush, execute_select_pc_plus_one, execute_output_result || initial_decode_is_branch);
      // $display();
      

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
      // run it for that many nano-seconds, then set
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
`endif
endmodule
