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

    wire [7:0][n-1:0] registers;
    for (genvar i = 0; i < 8; i = i + 1) begin
        lc4_single_register #(n) r(.register_number(i[2:0]), .read_data(registers[i]), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B), .clk(clk), .gwe(gwe), .rst(rst));
    end
 
    lc4_register_fetch #(n) rsA(.read_port(i_rs_A), .read_data(o_rs_data_A), .registers(registers), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));
    lc4_register_fetch #(n) rtA(.read_port(i_rt_A), .read_data(o_rt_data_A), .registers(registers), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));
    lc4_register_fetch #(n) rsB(.read_port(i_rs_B), .read_data(o_rs_data_B), .registers(registers), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));
    lc4_register_fetch #(n) rtB(.read_port(i_rt_B), .read_data(o_rt_data_B), .registers(registers), .i_rd_A(i_rd_A), .i_wdata_A(i_wdata_A), .i_rd_we_A(i_rd_we_A), .i_rd_B(i_rd_B), .i_wdata_B(i_wdata_B), .i_rd_we_B(i_rd_we_B));

endmodule

module lc4_register_fetch #(parameter n = 16)
   (input  wire [  2:0] read_port,

    input  wire [  2:0] i_rd_A,
    input  wire [n-1:0] i_wdata_A,
    input  wire         i_rd_we_A,

    input  wire [  2:0] i_rd_B,
    input  wire [n-1:0] i_wdata_B,
    input  wire         i_rd_we_B,
 
    input  wire [7:0][n-1:0] registers,
 
    output wire [n-1:0] read_data
    );

    wire [n-1:0] register_data = read_port == 0 ? registers[0]
                               : read_port == 1 ? registers[1]
                               : read_port == 2 ? registers[2]
                               : read_port == 3 ? registers[3]
                               : read_port == 4 ? registers[4]
                               : read_port == 5 ? registers[5]
                               : read_port == 6 ? registers[6]
                               : registers[7];

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