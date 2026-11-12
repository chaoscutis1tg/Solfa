# Hướng Dẫn Đưa Ứng Dụng Solfa Lên Google Play Store (CH Play) Từ A → Z

Tài liệu này tổng hợp sẵn **toàn bộ tệp cài đặt (`.aab`), hình ảnh chuẩn kích thước và nội dung chữ (Copy-Paste)** để bạn đăng ứng dụng **Solfa** lên [Google Play Console](https://play.google.com/console) nhanh chóng nhất.

---

## 1. Danh sách các Tệp đã chuẩn bị sẵn cho bạn

| Hạng mục trên CH Play | Đường dẫn tệp trong dự án `D:\Solfa` | Yêu cầu kỹ thuật của Google |
| :--- | :--- | :--- |
| **1. Gói ứng dụng sản xuất (`.aab`)** | `D:\Solfa\build\app\outputs\bundle\release\app-release.aab` | Đã ký số bằng khóa `upload-keystore.jks`, `targetSdk = 35` |
| **2. Biểu tượng ứng dụng (App Icon)** | `D:\Solfa\store_listing\app_icon_512x512.png` | Chuẩn `512 x 512 px` PNG 32-bit |
| **3. Ảnh nổi bật (Feature Graphic)** | `D:\Solfa\store_listing\feature_graphic_1024x500.png` | Chuẩn `1024 x 500 px` PNG |
| **4. Khóa ký số bản quyền (Keystore)** | `D:\Solfa\android\app\upload-keystore.jks` *(Mật khẩu: `Solfa2026!`, Alias: `upload`)* | **Lưu giữ cẩn thận** để dùng cho các bản cập nhật về sau (khi gắn AdMob `v1.0.1`) |
| **5. Link Chính sách Quyền riêng tư** | `https://github.com/chaoscutis1tg/Solfa/blob/main/PRIVACY_POLICY.md` | Sau khi bạn chạy `git push`, đường link này hoạt động công khai 24/7 |

---

## 2. Nội dung Copy-Paste vào mục "Trang thông tin chính trên cửa hàng" (Main Store Listing)

### A. Tên ứng dụng (App name – tối đa 30 ký tự)
```text
Solfa: Luyện Cảm Âm & Nhịp Cơ
```

### B. Mô tả ngắn (Short description – tối đa 80 ký tự)
```text
Luyện nghe nốt nhạc Piano, phân biệt quãng, hợp âm và máy đếm nhịp cơ học 100%.
```

### C. Mô tả đầy đủ (Full description – tối đa 4.000 ký tự)
```text
Solfa Studio là ứng dụng luyện cảm âm (Ear Training), trắc nghiệm nhạc lý thực hành và máy đếm nhịp cơ học (Mechanical Metronome) được thiết kế tối ưu cho người học nhạc cụ (Piano, Guitar, Violin, Thanh nhạc) tại Việt Nam.

🌟 TÍNH NĂNG NỔI BẬT CỦA SOLFA:

1. Luyện Cảm Âm Theo Cấp Độ (Cơ bản → Trung bình → Nâng cao)
• Nhận biết nốt nhạc (Note Recognition): Nghe cao độ thực tế (44.1kHz) từ Đô (C) đến Si (B), bao gồm cả các nốt có dấu hóa (#/b) và đa quãng tám, kết hợp bàn phím Piano trực quan để đối chiếu ngay lập tức.
• Nhận biết quãng (Interval Recognition): Phân biệt chính xác khoảng cách từ Quãng 2 đến Quãng 8 (cả quãng giai điệu đi lên/đi xuống và quãng hòa thanh vang đồng thời).
• Nhận biết giọng & Hòa âm (Key & Cadence Recognition): Cảm nhận màu sắc Giọng Trưởng (Major) tươi sáng, Giọng Thứ (Minor) trầm lắng và nắm vững hóa biểu thông qua chuỗi hòa âm I – IV – V – I.

2. Phòng Luyện Tập Linh Hoạt & Bảng Điểm Trực Tiếp
• Chọn chế độ thời gian phù hợp với quỹ thời gian của bạn: 60 giây phản xạ nhanh, 15 phút, 1 tiếng hoặc Luyện tập tự do không giới hạn.
• Hệ thống chấm điểm nốt Đúng / Sai theo thời gian thực và tự động chuyển câu mượt mà.

3. Cơ Chế Ôn Tập Thông Minh (Spaced Mastery)
• Tự động ghi nhớ các nốt hoặc quãng bạn từng nghe nhầm vào danh sách "Ôn câu sai".
• Áp dụng quy tắc "Đúng 2 lần liên tiếp" giúp bạn khắc phục triệt để điểm yếu thính giác.

4. Máy Đếm Nhịp Cơ Học Chuẩn Xác (< 10ms Jitter)
• Âm thanh mô phỏng chân thực tiếng búa gõ hộp gỗ máy đếm nhịp cơ truyền thống, tiếng Phách gỗ trầm ấm và tiếng Chuông đồng ở phách mạnh.
• Hỗ trợ dải tốc độ rộng từ 30 – 240 BPM, tính năng Chạm dò nhịp (Tap Tempo) lọc nhiễu thông minh và các loại nhịp phổ biến (2/4, 3/4, 4/4, 6/8).

5. Hoạt Động 100% Ngoại Tuyến (Offline-First) & Không Quảng Cáo Làm Phiền
• Toàn bộ bài học, âm thanh chất lượng phòng thu và máy đếm nhịp hoạt động hoàn toàn không cần Internet.
• Không yêu cầu tạo tài khoản, không thu thập dữ liệu cá nhân và tuyệt đối không có quảng cáo tự động bật lên làm gián đoạn lúc bạn đang tập đàn.
```

---

## 3. Hướng dẫn trả lời nhanh mục "Nội dung ứng dụng" (App Content) trên Google Play Console

Khi tạo ứng dụng mới, ở menu **Chính sách → Nội dung ứng dụng (App content)**, bạn chọn như sau:

1. **Chính sách quyền riêng tư (Privacy Policy)**:
   - Dán URL: `https://github.com/chaoscutis1tg/Solfa/blob/main/PRIVACY_POLICY.md`
2. **Quyền truy cập ứng dụng (App access)**:
   - Chọn: *"Tất cả chức năng đều dùng được mà không cần quyền truy cập đặc biệt"* (Vì app không bắt đăng nhập).
3. **Quảng cáo (Ads)**:
   - Ở bản đầu tiên này (nếu chưa gắn SDK AdMob): Chọn *"Không, ứng dụng của tôi không chứa quảng cáo"* (Hoặc khi gắn AdMob ở bản sau thì đổi thành *"Có, ứng dụng có chứa quảng cáo"*).
4. **Phân loại nội dung (Content rating / IARC)**:
   - Danh mục: **Giáo dục / Tham khảo (Reference, News, or Educational)**.
   - Tích **"Không (No)"** cho tất cả câu hỏi về bạo lực, ngôn từ kích động, cờ bạc, mua hàng... → Ứng dụng sẽ đạt nhãn **3+ (Phù hợp với mọi lứa tuổi)**.
5. **Đối tượng mục tiêu (Target audience)**:
   - Chọn các nhóm tuổi từ **13–15, 16–17, 18 trở lên** *(Mẹo quan trọng: Không nên tích dưới 13 tuổi ở lần đầu để tránh phải xét duyệt thêm biểu mẫu Chương trình Gia đình khắt khe của Google)*.
6. **An toàn dữ liệu (Data safety)**:
   - Câu hỏi *"Ứng dụng của bạn có thu thập hoặc chia sẻ bất kỳ loại dữ liệu người dùng bắt buộc nào không?"*:
     - Ở bản đầu tiên (chưa gắn SDK AdMob): Chọn **"Không (No)"** → Bấm Lưu (Xong ngay trong 5 giây!).

---

## 4. Tải gói `.aab` lên CH Play

1. Vào mục **Phát hành (Release) → Sản xuất (Production)** (hoặc **Thử nghiệm nội bộ / Khép kín** nếu tài khoản cá nhân mới lập).
2. Bấm **"Tạo bản phát hành mới" (Create new release)**.
3. Tại ô **App bundles**, kéo thả file sau vào:
   `D:\Solfa\build\app\outputs\bundle\release\app-release.aab`
4. Đặt tên bản phát hành: `1.0.0 (1)` → Bấm **Tiếp theo** → **Lưu và Xuất bản**!

