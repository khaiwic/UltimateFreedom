Giới thiệu mã Reed-Solomon

Các khái niệm liên quan cần phải biết:

* Mã khối tuyến tính  
* Trường Galois  
* Đa thức sinh  
* Mã hoá RS hệ thống

Khác với các loại mã hoá tuyến tính khác xử lí trực tiếp trên bit, mã RS biến các bit thông tin thành các ký tự để xử lí việc truyền nhận tin và sửa tin, đặc trưng của loại này là có thể sửa chùm lỗi liên tiếp khác so với mã hamming thông thường chỉ sửa được lẻ 1 bit.

Để hiểu sâu hơn cách nó hoạt động ta cần làm rõ nguyên lí hoạt động và toán học đằng sau nó:  
\-Trường Galois là 1 trường hữu hạn có p^n phần tử, p là số nguyên tố, n là số nguyên dương,việc cộng trừ nhân chia trong trường này sẽ luôn là kết quả bên trong trường đó, không bị tràn số.

* Tại sao lại dùng 1 trường có hữu hạn phần tử: do phần cứng giới hạn, ví dụ nếu cộng 2 giá trị được kết quả lớn hơn 256 ta phải dùng thêm 1 thanh ghi 8bit để lưu giá trị. 

* Vì là trường hữu hạn nên các phép cộng trừ nhân chia có khác biệt so với trường khác, ví dụ phép cộng trừ có tính XOR (không nhé), 1 \+ 1 \= 0; phép nhân chia phức tạp hơn chút, ta phải dùng đa thức sinh, ví dụ: ta đa thức hoá 2 số mình sẽ nhân, khi nhân vào kết quả là đa thức có bậc vượt quá giới hạn trường, ta sẽ phải chia module cho 1 đa thức quy chuẩn của trường từ đó tìm được kết quả nằm trong giới hạn của trường đồng thời bảo mật được thông tin.

\-Nguyên lí mã hoá: Dùng từ điển( đa thức sinh), biến bản tin gốc thông qua toán tử là phép chia đa thức.

1. Bản tin gốc: Thông điệp bao gồm $k$ ký tự thông tin ban đầu được biểu diễn dưới dạng một đa thức $M(x)$ có bậc $k-1$.  
2. Đa thức sinh (Code Generator Polynomial): Để tạo ra mã RS $(n,k)$, bộ mã hóa xây dựng đa thức sinh $g(x)$ bao gồm $n-k=2t$ nhân tử. Các nghiệm của những nhân tử này phải là các phần tử liên tiếp trong Trường Galois nhằm đảm bảo tối đa hóa khoảng cách (distance properties) giữa các từ mã.  
3. Phép toán mã hóa thực chất là việc chia đa thức bản tin cho đa thức sinh (dictionary). Phần dư thu được sau phép chia đa thức này chính là các byte bảo vệ, được gắn vào sau bản tin gốc.

\-Nguyên lí giải mã:

1. Tính đa thức hội chứng (Syndromes polynomial): Bước này cho phép đánh giá nhanh xem bản tin đầu vào có bị hỏng hay không, đồng thời phân tích xem các ký tự nào đang bị lỗi thông qua các thuật toán như Berlekamp-Massey.  
2. Tính đa thức định vị lỗi (Locator polynomial): Dựa vào các hội chứng, thuật toán Berlekamp-Massey tính toán ra một đa thức đóng vai trò như thiết bị dò tìm, chỉ ra chính xác vị trí của các ký tự bị hỏng trong chuỗi dữ liệu.  
3. Tính đa thức đánh giá lỗi (Evaluator polynomial): Được tạo ra từ đa thức hội chứng và đa thức định vị lỗi. Đa thức này là thành phần bắt buộc để đánh giá mức độ sai lệch của các ký tự lỗi (từ đó hỗ trợ tính toán biên độ).  
4. Tính đa thức biên độ lỗi (Magnitude polynomial): Khối này tổng hợp dữ liệu từ 3 đa thức trên để tạo ra đa thức biên độ (hay còn gọi là đa thức nhiễu). Nó lưu trữ chính xác các giá trị độ lệch cần phải trừ đi khỏi thông điệp nhận được để lấy lại dữ liệu nguyên bản. Tại bước này, hệ thống đã trích xuất thành công lớp nhiễu và lưu nó vào một đa thức độc lập.  
5. Sửa lỗi (Repair the input message): Việc sửa lỗi diễn ra bằng cách lấy thông điệp đầu vào trừ đi đa thức biên độ lỗi.