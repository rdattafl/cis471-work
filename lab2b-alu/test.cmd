 rem Create an empty .set_testcase.v to satisfy `include statements. Set all `defines below.
 fsutil file createnew .set_testcase.v 0

rem NB: iverilog v11, perhaps only on windows?, needs verilog files specified in topological dependence order
rem If iverilog.exe and vvp.exe are not in your PATH, add their absolute path for the two lines below. For example, iverilog.exe might become C:\iverilog\bin\iverilog.exe
iverilog.exe -g2012 -W all -I include -D GENERATE_VCD=1 -DINPUT_FILE=\"test_data/%1.ctrace\" -DOUTPUT_FILE=\"test_data/%1.output\" -DMEMORY_IMAGE_FILE=\"test_data/%1.hex\" -DVCD_FILE=\"%1.vcd\" -o %1.out testbench_lc4_alu.v lc4_alu.v lc4_divider.v lc4_cla.v
vvp.exe %1.out
