# Ứng dụng của mã Reed–Solomon
 
Mã Reed–Solomon (RS) được dùng ở bất cứ đâu dữ liệu có thể bị hỏng thành từng cụm ký tự. Nhờ sửa lỗi **theo ký tự**, RS xử lý lỗi chùm (burst) rất tốt.
 
## 1. Lưu trữ
 
- **CD, DVD, Blu-ray:** vết xước hoặc bụi làm hỏng cả một đoạn liền nhau. CD dùng hai tầng RS ghép (CIRC) nên vẫn đọc được dù đĩa xước nhẹ.
- **Ổ cứng, băng từ:** RS dùng làm mã sửa lỗi cho các sector dữ liệu.
- **RAID 6:** ý tưởng gần với RS. Hệ thống chịu được hỏng 2 ổ đĩa cùng lúc nhờ các khối parity tính trong GF(2^8).
## 2. Mã vạch và mã QR
 
- **QR code:** có 4 mức sửa lỗi (khoảng 7%, 15%, 25%, 30% dữ liệu). Đó là lý do mã vẫn quét được khi bị rách, bẩn hoặc dán logo lên giữa.
- **Data Matrix, Aztec, PDF417:** cũng dùng RS.
## 3. Truyền thông và phát sóng
 
- **Truyền hình số:** DVB (mặt đất, vệ tinh, cáp) dùng RS(204,188), thường ghép với mã chập (convolutional code) rồi giải mã bằng Viterbi.
- **Internet cáp (DOCSIS), ADSL/VDSL:** dùng RS để chống nhiễu đường truyền.
- **Truyền dẫn quang:** các chuẩn mạng quang tốc độ cao dùng RS làm mã sửa lỗi tiến (FEC), ví dụ RS(255,239).
- **Phát thanh số, một số chuẩn di động và vệ tinh:** dùng RS ở các mức khác nhau.
## 4. Không gian và vệ tinh
 
- Tàu thăm dò như Voyager, và các chuẩn truyền thông không gian của CCSDS, dùng RS(255,223) kết hợp mã chập. Tín hiệu rất yếu và nhiễu, nên sửa lỗi gần như bắt buộc.
## 5. Phục hồi dữ liệu trên mạng và hệ thống phân tán
 
- **Erasure coding:** hệ thống lưu trữ đám mây và hệ thống tệp phân tán chia dữ liệu thành nhiều mảnh cộng thêm mảnh parity theo kiểu RS. Mất một số mảnh vẫn khôi phục được toàn bộ dữ liệu.
- **Truyền file qua mạng mất gói:** RS cho phép người nhận ghép lại dữ liệu mà không cần gửi lại gói đã mất.
## 6. Mật mã và chia sẻ bí mật
 
- Cùng nền toán học với Shamir secret sharing: chia bí mật thành n phần, chỉ cần đủ k phần là khôi phục được.
## Vì sao RS phù hợp
 
- Sửa lỗi theo ký tự, nên lỗi chùm chỉ tính là vài ký tự sai.
- Là mã MDS: tối ưu về lượng parity cần thêm cho khả năng sửa lỗi cho trước.
- Sửa được cả **lỗi** và **xoá** (biết trước vị trí hỏng), nên rất hợp với ổ đĩa và truyền gói.
- Giải mã triển khai hiệu quả bằng phần cứng, kể cả FPGA, vì chỉ dùng các phép toán trong trường Galois..