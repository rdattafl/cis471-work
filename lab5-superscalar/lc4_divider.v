/* TODO: INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

    wire [15:0] remainders [16:0];
    wire [15:0] quotients  [16:0];
    wire [15:0] dividends  [16:0];

    assign remainders[0] = 16'b0;
    assign quotients [0] = 16'b0;
    assign dividends [0] = i_dividend;

    assign o_remainder = i_divisor == 0 ? 0 : remainders[16];
    assign o_quotient  = i_divisor == 0 ? 0 : quotients [16];
    
    for (genvar i = 0; i < 16; i = i + 1) begin
        lc4_divider_one_iter div(.i_divisor(i_divisor), 
            .i_dividend (dividends [i]), .o_dividend (dividends [i+1]),
            .i_remainder(remainders[i]), .o_remainder(remainders[i+1]),
            .i_quotient (quotients [i]), .o_quotient (quotients [i+1]));
    end

endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

    wire [15:0] start_remainder = (i_remainder << 1) | (i_dividend >> 15);
    assign o_remainder = start_remainder >= i_divisor ? start_remainder - i_divisor : start_remainder;
    assign o_quotient  = start_remainder >= i_divisor ? (i_quotient << 1) | 1'b1    : i_quotient << 1;
    assign o_dividend  = i_dividend << 1;

endmodule

