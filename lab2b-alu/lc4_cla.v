/* TODO: INSERT NAME AND PENNKEY HERE 
Riju Datta
45039816 
*/


`timescale 1ns / 1ps
`default_nettype none

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);

  assign pout = (& pin);

  wire [3:0] g = {
    gin[3],
    gin[2] & (pin[3]),
    gin[1] & (& pin[3:2]),
    gin[0] & (& pin[3:1])
  };

  assign gout = |g;
  
  assign cout[0] = gin[0] | (pin[0] & cin);
  assign cout[1] = gin[1] | (pin[1] & gin[0]) | (& pin[1:0] & cin);
  assign cout[2] = gin[2] | (pin[2] & gin[1]) | (& pin[2:1] & gin[0]) | (& pin[2:0] & cin);

   
endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);

  wire [15:0] p_in;
  wire [15:0] g_in;
  wire [3:0] g_out;
  wire [3:0] p_out;
  wire [16:0] c_out;

  assign c_out[0] = cin;

  // Instantiate the 16 gp1 modules required for the 16-bit CLA adder
  for (genvar i = 0; i < 16; i = i + 1) begin
    gp1 zeroth_level(.a(a[i]), .b(b[i]), .p(p_in[i]), .g(g_in[i]));
  end

  // Create the four first-level gp4 modules and create the multiples of 4 carry out bits 
  // that would come from the second-level gp4 module
  for (genvar i = 0; i < 4; i = i + 1) begin
    localparam low = 4 * i;
    localparam high = 4 * i + 3;
    gp4 g(.gout(g_out[i]), .pout(p_out[i]), .cout(c_out[high:low + 1]),
          .gin(g_in[high:low]), .pin(p_in[high:low]), .cin(c_out[low]));
  end

  for (genvar i = 0; i < 4; i = i + 1) begin
    assign c_out[4 * (i + 1)] = (c_out[4 * i] & p_out[i]) | g_out[i];
  end

  // Calculate sum
  assign sum = a ^ b ^ c_out;

endmodule


/** Lab 2 Extra Credit, see details at
  https://github.com/upenn-acg/cis501/blob/master/lab2-alu/lab2-cla.md#extra-credit
 If you are not doing the extra credit, you should leave this module empty.
 */
module gpn
  #(parameter N = 4)
  (input wire [N-1:0] gin, pin,
   input wire  cin,
   output wire gout, pout,
   output wire [N-2:0] cout);
 
endmodule
