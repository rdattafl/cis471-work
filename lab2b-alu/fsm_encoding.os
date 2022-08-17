
 add_fsm_encoding \
       {SpiCtrl.state} \
       { }  \
       {{000 000} {001 001} {010 010} {011 011} {111 100} }

 add_fsm_encoding \
       {delay_ms.state} \
       { }  \
       {{00 0001} {01 0010} {10 0100} {11 1000} }

 add_fsm_encoding \
       {lc4_system_alu.state} \
       { }  \
       {{000 110} {001 000} {010 001} {011 010} {101 100} {110 011} {111 101} }
