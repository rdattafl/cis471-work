`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

    // We need 8 different register wires
    wire [n-1:0] registers_0;
    wire [n-1:0] registers_1;
    wire [n-1:0] registers_2;
    wire [n-1:0] registers_3;
    wire [n-1:0] registers_4;
    wire [n-1:0] registers_5;
    wire [n-1:0] registers_6;
    wire [n-1:0] registers_7;

    lc4_single_register #(n) r0(.register_number(3'b000), .read_data(registers_0), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r1(.register_number(3'b001), .read_data(registers_1), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r2(.register_number(3'b010), .read_data(registers_2), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r3(.register_number(3'b011), .read_data(registers_3), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r4(.register_number(3'b100), .read_data(registers_4), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r5(.register_number(3'b101), .read_data(registers_5), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r6(.register_number(3'b110), .read_data(registers_6), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    lc4_single_register #(n) r7(.register_number(3'b111), .read_data(registers_7), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
 
    lc4_register_fetch #(n) rsA(.read_port(i_rs_A), .read_data(o_rs_data_A), .registers_0(registers_0), .registers_1(registers_1), .registers_2(registers_2), .registers_3(registers_3), .registers_4(registers_4), .registers_5(registers_5), .registers_6(registers_6), .registers_7(registers_7), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));
    lc4_register_fetch #(n) rtA(.read_port(i_rt_A), .read_data(o_rt_data_A), .registers_0(registers_0), .registers_1(registers_1), .registers_2(registers_2), .registers_3(registers_3), .registers_4(registers_4), .registers_5(registers_5), .registers_6(registers_6), .registers_7(registers_7), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));
    lc4_register_fetch #(n) rsB(.read_port(i_rs_B), .read_data(o_rs_data_B), .registers_0(registers_0), .registers_1(registers_1), .registers_2(registers_2), .registers_3(registers_3), .registers_4(registers_4), .registers_5(registers_5), .registers_6(registers_6), .registers_7(registers_7), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));
    lc4_register_fetch #(n) rtB(.read_port(i_rt_B), .read_data(o_rt_data_B), .registers_0(registers_0), .registers_1(registers_1), .registers_2(registers_2), .registers_3(registers_3), .registers_4(registers_4), .registers_5(registers_5), .registers_6(registers_6), .registers_7(registers_7), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));

endmodule

module lc4_register_fetch #(parameter n = 16)
   (input  wire [  2:0] read_port,

    input  wire [  2:0] i_rd_A,
    input  wire [n-1:0] i_wdata_A,
    input  wire         i_rd_we_A,

    input  wire [  2:0] i_rd_B,
    input  wire [n-1:0] i_wdata_B,
    input  wire         i_rd_we_B,
 
    input  wire [n-1:0] registers_0,
    input  wire [n-1:0] registers_1,
    input  wire [n-1:0] registers_2,
    input  wire [n-1:0] registers_3,
    input  wire [n-1:0] registers_4,
    input  wire [n-1:0] registers_5,
    input  wire [n-1:0] registers_6,
    input  wire [n-1:0] registers_7,
 
    output wire [n-1:0] read_data
    );

    wire [n-1:0] register_data = read_port == 0 ? registers_0
                               : read_port == 1 ? registers_1
                               : read_port == 2 ? registers_2
                               : read_port == 3 ? registers_3
                               : read_port == 4 ? registers_4
                               : read_port == 5 ? registers_5
                               : read_port == 6 ? registers_6
                               : registers_7;

    assign read_data = (i_rd_B == read_port & i_rd_we_B) ? i_wdata_B
                     : (i_rd_A == read_port & i_rd_we_A) ? i_wdata_A
                     : register_data;

endmodule

module lc4_single_register #(parameter n = 16)
   (input wire          clk,
    input wire          gwe,
    input wire          rst,

    input  wire [  2:0] register_number,

    input  wire [  2:0] i_rd_A,
    input  wire [n-1:0] i_wdata_A,
    input  wire         i_rd_we_A,

    input  wire [  2:0] i_rd_B,
    input  wire [n-1:0] i_wdata_B,
    input  wire         i_rd_we_B,
 
    output wire [n-1:0] read_data
    );

    wire [n-1:0] in = (i_rd_B == register_number & i_rd_we_B) ? i_wdata_B 
                    : (i_rd_A == register_number & i_rd_we_A) ? i_wdata_A 
                    : register_number;

    wire we = (i_rd_B == register_number & i_rd_we_B) | (i_rd_A == register_number & i_rd_we_A);

    Nbit_reg #(n) register(.in(in), .out(read_data), .we(we), .clk(clk), .gwe(gwe), .rst(rst));

endmodule