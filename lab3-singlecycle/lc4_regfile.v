/* TODO: Names of all group members
 * Riju Datta
 * Aidan Barr Bono
 * TODO: PennKeys of all group members
 * 45039816 
 * 
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );

    wire [n-1:0] r0v, r1v, r2v, r3v, r4v, r5v, r6v, r7v;

   /***********************
    * TODO YOUR CODE HERE *
    ***********************/

    Nbit_reg #(16) r0(.in(i_wdata), .out(r0v), .clk(clk), .we((i_rd == 3'd0) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r1(.in(i_wdata), .out(r1v), .clk(clk), .we((i_rd == 3'd1) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r2(.in(i_wdata), .out(r2v), .clk(clk), .we((i_rd == 3'd2) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r3(.in(i_wdata), .out(r3v), .clk(clk), .we((i_rd == 3'd3) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r4(.in(i_wdata), .out(r4v), .clk(clk), .we((i_rd == 3'd4) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r5(.in(i_wdata), .out(r5v), .clk(clk), .we((i_rd == 3'd5) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r6(.in(i_wdata), .out(r6v), .clk(clk), .we((i_rd == 3'd6) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16) r7(.in(i_wdata), .out(r7v), .clk(clk), .we((i_rd == 3'd7) & i_rd_we), .gwe(gwe), .rst(rst));
    
    assign o_rs_data = (i_rs == 3'd0) ? r0v : 
                       (i_rs == 3'd1) ? r1v : 
                       (i_rs == 3'd2) ? r2v : 
                       (i_rs == 3'd3) ? r3v : 
                       (i_rs == 3'd4) ? r4v : 
                       (i_rs == 3'd5) ? r5v : 
                       (i_rs == 3'd6) ? r6v : 
                       r7v; // This is the 8-to-1 mux that will select the value to be stored in register file Rs

    assign o_rt_data = (i_rt == 3'd0) ? r0v : 
                       (i_rt == 3'd1) ? r1v : 
                       (i_rt == 3'd2) ? r2v : 
                       (i_rt == 3'd3) ? r3v : 
                       (i_rt == 3'd4) ? r4v : 
                       (i_rt == 3'd5) ? r5v : 
                       (i_rt == 3'd6) ? r6v : 
                       r7v ; // This is the 8-to-1 mux that will select the value to be stored in register file Rt

endmodule

