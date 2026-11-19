`ifndef RS_PARAMS_VH
`define RS_PARAMS_VH

// Tham so he thong Reed-Solomon RS(5,3) tren GF(8)
`define RS_M             3
`define GF_SIZE          8
`define GF_ORDER         7
`define GF_PRIM_POLY     4'b1011
`define GF_ALPHA         3'd2

`define RS_N             5
`define RS_K             3
`define RS_R             2
`define RS_T             1

`define RS_FIRST_ROOT    0
`define RS_ROOT_STEP     1

`endif
