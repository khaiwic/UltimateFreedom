UltimateFreedom/
├── rtl/                             # Mã nguồn Verilog HDL tổng hợp lên FPGA
│   ├── include/
│   │   └── rs_params.vh             # Tham số hệ thống RS(5,3) trên GF(8)
│   │
│   ├── gf_arithmetic/
│   │   ├── gf8_mul.v                # Nhân trong GF(8) với p(x) = x^3 + x + 1
│   │   └── gf8_inv.v                # Nghịch đảo 3-bit trong GF(8)
│   │
│   ├── rs_encoder/
│   │   └── rs_encoder.v             # Mã hóa 3 symbol thành 5 symbol (15-bit)
│   │
│   ├── rs_decoder/
│   │   ├── rs_decoder.v             # Điều phối giải mã RS(5,3) sửa tối đa T=1 lỗi
│   │   ├── syndrome.v               # Tính 2 syndrome S0, S1
│   │   ├── berlekamp_massey.v       # Tìm đa thức định vị lỗi Lambda(z)
│   │   ├── error_evaluator.v        # Tính đa thức giá trị lỗi Omega(z)
│   │   ├── chien_search.v           # Tìm vị trí symbol lỗi trong 5 vị trí
│   │   └── forney.v                 # Tính độ lớn giá trị lỗi
│   │
│   ├── controller/
│   │   └── rs_controller.v          # Điều phối nhập thông tin, nhập tối đa 3 lỗi, LEDR & HEX
│   │
│   ├── demo/
│   │   └── error_injector.v         # Tiêm lỗi vào 3 symbol cuối của từ mã
│   │
│   └── board/
│       ├── input_control.v          # Lọc dội KEY[1] và đồng bộ SW[9:0]
│       ├── hex_decoder.v            # Giải mã 0..7 ra LED 7 đoạn
│       └── top_de10_lite.v          # Top-level DE10-Lite (LEDR[9:0], HEX2:HEX0)
│
├── tb/                              # 10 Testbench Verilog
│   ├── tb_gf8_mul.v
│   ├── tb_gf8_inv.v
│   ├── tb_rs_encoder.v
│   ├── tb_syndrome.v
│   ├── tb_berlekamp_massey.v
│   ├── tb_error_evaluator.v
│   ├── tb_chien_search.v
│   ├── tb_forney.v
│   ├── tb_rs_decoder.v
│   └── tb_top.v
│
├── model/                           # Mô hình tham chiếu Python
│   ├── gf8_model.py
│   ├── gf256_model.py               # Tương thích import sang gf8_model
│   ├── rs_reference.py
│   ├── generate_vectors.py
│   └── README.md
│
├── vectors/                         # Vector kiểm thử sinh từ Python
│   ├── README.md
│   ├── no_error/
│   ├── one_error/
│   ├── two_errors/
│   ├── parity_error/
│   └── beyond_capacity/
│
├── quartus/                         # Project Quartus Prime
│   ├── ReedSolomon.qpf
│   ├── ReedSolomon.qsf
│   └── timing.sdc
│
├── sim/                             # Kịch bản mô phỏng ModelSim / QuestaSim
│   ├── rtl_files.f
│   ├── run.do
│   └── wave.do
│
├── docs/                            # Tài liệu kỹ thuật
├── README.md
├── README_RS_DE10_Lite.md
├── Step_to_step.md
└── System_Architecture.md
