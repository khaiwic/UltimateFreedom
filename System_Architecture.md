ReedSolomon_DE10Lite/
├── rtl/                             # Mã phần cứng được tổng hợp lên FPGA
│   ├── include/
│   │   └── rs_params.vh             # Tham số và quy ước chung của mã RS
│   │
│   ├── gf_arithmetic/
│   │   ├── gf256_add.v              # Cộng GF: XOR, có thể viết trực tiếp
│   │   ├── gf256_mul.v              # Nhân trong GF(256)
│   │   └── gf256_inv.v              # Nghịch đảo phần tử khác 0
│   │
│   ├── rs_encoder/
│   │   └── rs_encoder.v             # Mã hóa 11 byte thành 15 byte
│   │
│   ├── rs_decoder/
│   │   ├── rs_decoder.v             # Tích hợp và điều khiển decoder
│   │   ├── syndrome.v              # Tính syndrome
│   │   ├── berlekamp_massey.v       # Tìm đa thức định vị lỗi Lambda
│   │   ├── error_evaluator.v        # Tính đa thức đánh giá lỗi Omega
│   │   ├── chien_search.v           # Tìm vị trí symbol lỗi
│   │   ├── forney.v                 # Tính giá trị lỗi
│   │   └── error_corrector.v        # XOR sửa lỗi vào từ mã nhận
│   │
│   ├── memory/
│   │   └── data_buffer.v            # Lưu dữ liệu và các phiên bản từ mã
│   │
│   ├── controller/
│   │   └── rs_controller.v          # Điều phối toàn bộ giao dịch demo
│   │
│   ├── demo/
│   │   ├── error_injector.v         # Tạo lỗi theo địa chỉ và mặt nạ XOR
│   │   ├── result_checker.v         # So sánh kết quả với từ mã chuẩn
│   │   └── cycle_counter.v          # Đếm chu kỳ xử lý
│   │
│   └── board/
│       ├── reset_sync.v            # Xử lý reset, nhả reset đồng bộ
│       ├── input_control.v         # Đồng bộ KEY/SW và tạo xung xác nhận
│       ├── hex_decoder.v           # Đổi nibble thành mẫu LED 7 đoạn
│       ├── display_control.v       # Chọn nội dung HEX và trạng thái LED
│       └── top_de10_lite.v          # Kết nối toàn bộ hệ thống với board
│
├── tb/                              # Testbench, không tổng hợp lên FPGA
│   ├── tb_gf256_mul.v
│   ├── tb_gf256_inv.v
│   ├── tb_rs_encoder.v
│   ├── tb_syndrome.v
│   ├── tb_berlekamp_massey.v
│   ├── tb_error_evaluator.v
│   ├── tb_chien_search.v
│   ├── tb_forney.v
│   ├── tb_rs_decoder.v              # Kiểm tra decoder hoàn chỉnh
│   └── tb_top.v                     # Kiểm tra giao dịch và ngoại vi
│
├── model/                           # Mô hình tham chiếu chạy trên máy tính
│   ├── gf256_model.py
│   ├── rs_reference.py
│   ├── generate_vectors.py
│   └── README.md                    # Cách chạy và các quy ước tham số
│
├── vectors/                         # Dữ liệu kiểm thử dùng cho mô phỏng
│   ├── README.md                    # Định dạng file và kết quả mong đợi
│   │
│   ├── no_error/
│   │   ├── input_data.hex
│   │   ├── encoded_data.hex
│   │   ├── corrupted_data.hex
│   │   └── expected_codeword.hex
│   │
│   ├── one_error/
│   │   ├── input_data.hex
│   │   ├── encoded_data.hex
│   │   ├── corrupted_data.hex
│   │   └── expected_codeword.hex
│   │
│   ├── two_errors/
│   │   ├── input_data.hex
│   │   ├── encoded_data.hex
│   │   ├── corrupted_data.hex
│   │   └── expected_codeword.hex
│   │
│   ├── parity_error/
│   │   ├── input_data.hex
│   │   ├── encoded_data.hex
│   │   ├── corrupted_data.hex
│   │   └── expected_codeword.hex
│   │
│   └── beyond_capacity/
│       ├── input_data.hex
│       ├── encoded_data.hex         # Bản chuẩn để đánh giá kết quả
│       ├── corrupted_data.hex
│       └── case_info.json           # Mô tả lỗi; không bảo đảm sửa được
│
├── quartus/                         # Project tổng hợp và nạp FPGA
│   ├── ReedSolomon.qpf
│   ├── ReedSolomon.qsf              # Danh sách RTL, include và gán chân
│   ├── timing.sdc                  # Ràng buộc clock và timing
│   └── output_files/               # Quartus tự sinh, không đưa lên Git
│
├── sim/                             # Script và cấu hình mô phỏng
│   ├── rtl_files.f                  # Danh sách file RTL cần biên dịch
│   ├── run.do                       # Biên dịch và chạy testbench
│   └── wave.do                      # Cấu hình các tín hiệu waveform
│
├── docs/
│   ├── architecture.md              # Kiến trúc và trách nhiệm từng module
│   ├── rs_parameters.md             # Cấu hình RS và quy ước toán học
│   ├── interfaces.md                # Giao tiếp, bắt tay, start/done/fail
│   ├── gf256.md                     # Phép toán trong GF(256)
│   ├── rs_algorithm.md              # Các bước mã hóa và giải mã
│   ├── pin_assignment.md            # Bảng chân DE10-Lite
│   ├── demo_guide.md                # Cách nhập, tạo lỗi và xem kết quả
│   ├── verification_plan.md         # Trường hợp kiểm thử và tiêu chí đạt
│   └── implementation_results.md    # Tài nguyên, timing và chu kỳ đo được
│
├── README.md                        # Tổng quan và hướng dẫn bắt đầu
└── .gitignore                       # Loại bỏ file sinh tự động