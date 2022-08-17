/* 
 * Adder testbench
 */

`timescale 1ns / 1ps

// change this to adjust how many errors are printed out
`define MAX_ERRORS_TO_DISPLAY 15

// set this to 1 to create a waveform file for easier debugging
`define GENERATE_VCD 1


module test_adders; 

`include "print_points.v"
   
   // status variables
   integer     errors, tests, i;
   
   reg         a, b;
   wire        actual_ha_sum, actual_ha_cout;
   
   // instantiate the Units Under Test (UUTs)
   
   halfadder ha(.a(a), .b(b), .s(actual_ha_sum), .cout(actual_ha_cout));

   reg         cin; 
   wire         exp_fa_cout, exp_fa_sum; 
   wire        actual_fa_sum, actual_fa_cout;
   fulladder fa(.cin(cin), .a(a), .b(b), .s(actual_fa_sum), .cout(actual_fa_cout));
   assign {exp_fa_cout,exp_fa_sum} =  a + b + cin;

   reg [1:0]   a2, b2;
   wire [1:0]   exp_fa2_sum;
   wire         exp_fa2_cout; 
   wire [1:0]  actual_fa2_sum;
   wire        actual_fa2_cout; 
   fulladder2 fa2(.cin(cin), .a(a2), .b(b2), .s(actual_fa2_sum), .cout(actual_fa2_cout));
   assign {exp_fa2_cout,exp_fa2_sum} =  a2 + b2 + cin;

   reg [3:0]   a4, b4;
   wire [3:0] exp_rca4_sum;
   wire [7:0]  actual_rca4_sum; 
   rca4 r0(.SWITCH({b4,a4}), .LED(actual_rca4_sum));
   assign {exp_rca4_sum} =  a4 + b4;
   
   
   initial begin // start testbench block

      if (`GENERATE_VCD) begin
         $dumpfile("rca.vcd");
         $dumpvars;
      end
      
      // initialize inputs
      a = 0;
      b = 0;
      errors = 0;
      tests = 0; 

      // wait for global reset to finish
      #100;

      // HALF-ADDER TESTS
      
      for (i = 0; i <= 3; i = i+1) begin
         a = i[0];
         b = i[1];

         #6; // wait for half adder to produce result
         tests = tests + 2; // test sum and cout 

         case (i)
           0, 3: begin
              if (0 !== actual_ha_sum) begin
                 if (errors < `MAX_ERRORS_TO_DISPLAY) begin
                    $display("[halfadder] ERROR: %b + %b should produce sum=0 but was %b instead", a, b, actual_ha_sum);
                 end
                 errors = errors + 1;
              end
           end
           1, 2: begin if (1 !== actual_ha_sum) begin
              if (errors < `MAX_ERRORS_TO_DISPLAY) begin
                 $display("[halfadder] ERROR: %b + %b should produce sum=1 but was %b instead", a, b, actual_ha_sum);
              end
              errors = errors + 1; 
           end
           end
         endcase
         
         if ((i < 3) && 0 !== actual_ha_cout) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[halfadder] ERROR: %b + %b should produce cout=0 but was %b instead", a, b, actual_ha_cout);
            end
            errors = errors + 1; 
         end         
         if ((i == 3) && 1 !== actual_ha_cout) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[halfadder] ERROR: %b + %b should produce cout=1 but was %b instead", a, b, actual_ha_cout);
            end
            errors = errors + 1; 
         end
      end


      
      // FULL ADDER TESTS

      for (i = 0; i <= 7; i = i + 1) begin
         a = i[0];
         b = i[1];
         cin = i[2]; 

         #6; // wait for full adder to produce result
         tests = tests + 2; // test sum and cout

         if (exp_fa_cout !== actual_fa_cout) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[fulladder] ERROR: %b + %b should produce cout=%b but was %b instead", a, b, exp_fa_cout, actual_fa_cout);
            end
            errors = errors + 1; 
         end
         if (exp_fa_sum !== actual_fa_sum) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[fulladder] ERROR: %b + %b should produce sum=%b but was %b instead", a, b, exp_fa_sum, actual_fa_sum);
            end
            errors = errors + 1; 
         end 
      end


      // FULL ADDER2 TESTS
      
      for (i = 0; i <= 31; i = i + 1) begin
         a2 = i[1:0];
         b2 = i[3:2];
         cin = i[4];

         #6; // wait for fulladder2 to produce result
         tests = tests + 2; // test sum and cout
         
         if (exp_fa2_cout !== actual_fa2_cout) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[fulladder2] ERROR: %b + %b should produce cout=%b but was %b instead", a2, b2, exp_fa2_cout, actual_fa2_cout);
            end
            errors = errors + 1; 
         end
         if (exp_fa2_sum !== actual_fa2_sum) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[fulladder2] ERROR: %b + %b should produce sum=%b but was %b instead", a2, b2, exp_fa2_sum, actual_fa2_sum);
            end
            errors = errors + 1; 
         end 
      end



      // RCA4 TESTS
      
      for (i = 0; i <= 255; i = i + 1) begin
         a4 = i[3:0];
         b4 = i[7:4];

         #6; // wait for rca4 to produce result
         tests = tests + 1; // test sum
         
         if (exp_rca4_sum !== actual_rca4_sum) begin
            if (errors < `MAX_ERRORS_TO_DISPLAY) begin
               $display("[rca4] ERROR: %b + %b should produce sum=%b but was %b instead", a4, b4, exp_rca4_sum, actual_rca4_sum);
            end
            errors = errors + 1; 
         end 
      end

      if (errors > `MAX_ERRORS_TO_DISPLAY) begin
         $display("Additional %d errors NOT printed.", errors - `MAX_ERRORS_TO_DISPLAY);
      end      
      $display("Simulation finished: %d test cases %d errors", tests, errors);
      printPoints(tests, tests - errors);
      $finish;
   end

endmodule
