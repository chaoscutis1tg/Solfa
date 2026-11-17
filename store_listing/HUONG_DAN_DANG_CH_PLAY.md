# Hướng Dẫn Đưa Ứng Dụng ChaoNote (Cháo Nhạc) Lên Google Play Store (CH Play) Từ A → Z

Tài liệu này tổng hợp sẵn **toàn bộ tệp cài đặt (`.aab`), hình ảnh chuẩn kích thước và nội dung chữ (Song ngữ Việt – Anh cho 174+ quốc gia)** để bạn đăng ứng dụng **ChaoNote (`vn.chaonote.app`)** lên [Google Play Console](https://play.google.com/console) không bị trùng tên với bất kỳ ứng dụng nào khác.

---

## 1. Danh sách các Tệp đã chuẩn bị sẵn cho bạn

| Hạng mục trên CH Play | Đường dẫn tệp trong dự án `D:\Solfa` | Yêu cầu kỹ thuật của Google |
| :--- | :--- | :--- |
| **1. Gói ứng dụng sản xuất (`.aab`)** | `D:\Solfa\build\app\outputs\bundle\release\app-release.aab` *(và `D:\Solfa\chaonote-release-v1.8.4-b16.aab`)* | Mã gói `vn.chaonote.app`, đã ký số bằng `upload-keystore.jks`, `targetSdk = 36` |
| **2. Biểu tượng ứng dụng (App Icon)** | `D:\Solfa\store_listing\app_icon_512x512.png` | Chuẩn `512 x 512 px` PNG 32-bit |
| **3. Ảnh nổi bật (Feature Graphic)** | `D:\Solfa\store_listing\feature_graphic_1024x500.png` | Chuẩn `1024 x 500 px` PNG |
| **4. Bộ 4 Ảnh chụp màn hình (Screenshots)** | - `D:\Solfa\store_listing\screenshot_1_bang_diem_sang.png`<br>- `D:\Solfa\store_listing\screenshot_2_cai_dat_am_thanh.png`<br>- `D:\Solfa\store_listing\screenshot_3_che_do_toi_dark_mode.png`<br>- `D:\Solfa\store_listing\screenshot_4_dau_truong_1v1_split.png` | Chuẩn `1080 x 1920 px` Full HD (Tỷ lệ 9:16) |
| **5. Khóa ký số bản quyền (Keystore)** | `D:\Solfa\android\app\upload-keystore.jks` *(Mật khẩu: `Solfa2026!`, Alias: `upload`)* | Lưu giữ cẩn thận để dùng cho các bản cập nhật về sau |
| **6. Link Chính sách Quyền riêng tư** | `https://github.com/chaoscutis1tg/Solfa/blob/main/PRIVACY_POLICY.md` | Hoạt động công khai 24/7 (Tuân thủ GDPR, EU 2018/302 & Nghị định 13) |

---

## 2. Nội dung Copy-Paste vào "Trang thông tin chính trên cửa hàng" (Tiếng Việt – `vi-VN`)

### A. Tên ứng dụng (App name – tối đa 30 ký tự)
```text
ChaoNote: Học Piano & Guitar
```

### B. Mô tả ngắn (Short description – tối đa 80 ký tự)
```text
Cháo Nhạc: Học Piano, Guitar, đọc khuông nhạc, đấu trường 1v1 & máy đếm nhịp cơ.
```

### C. Mô tả đầy đủ (Full description – tối đa 4.000 ký tự)
```text
ChaoNote (Cháo Nhạc) là ứng dụng học Piano, Guitar, luyện cảm âm (Ear Training), đọc khuông nhạc và máy đếm nhịp cơ học (Mechanical Metronome) từ Cơ bản đến Nâng cao, hoạt động 100% Ngoại tuyến (Offline-First).

🌟 TÍNH NĂNG NỔI BẬT CỦA CHAONOTE STUDIO:

1. Lộ Trình 7 Chủ Đề Piano & Nhạc Lý (Cơ Bản → Nâng Cao)
• Nhận biết nốt & Đọc khuông nhạc (Staff & Ledger Lines): Làm chủ Khóa Sol (𝄞), Khóa Fa (𝄢) và toàn bộ Dòng kẻ phụ từ C3 đến C6 kèm nút bật/tắt "Mốc chuẩn" trực quan và đàn Piano C3–C5 đa âm 4 kênh.
• Cảm âm Quãng, Hợp âm, Giọng, Giai điệu & Nhịp điệu: Luyện nghe mẫu âm thanh phòng thu 44.1kHz PCM cho Quãng 2 đến Quãng 8, Hợp âm Trưởng/Thứ/7/Sus4, vòng hòa thanh I–V–vi–IV, ii–V–I và chép nhạc giai điệu.

2. Phòng Học Guitar & Bản Đồ Cần Đàn 6 Dây (E2–E5)
• Bản đồ Cần đàn 6 dây × 12 ngăn: Chuẩn tần số vật lý từ dây 6 buông (E2 - 82.4Hz) đến dây 1 ngăn 12 (E5 - 659.3Hz) kèm mẹo tìm Quãng 8 chéo.
• Thư viện Hợp âm & Rải dây sáng đèn: Học thế bấm C, G, Am, Em, Dm, F, D, E kèm tính năng "Rải từ Bass xuống (Strum)" và "Rải Ballad (Bass-3-2-3-1-3-2-3)" sáng đèn chạy theo từng dây.
• Bản đồ Scale Pentatonic, Đọc Tab 6 dây, bài luyện ngón Spider Walk 1–2–3–4 và quy tắc dịch giọng bằng Capo.

3. Đấu Trường Âm Nhạc 1v1 & Chia Đôi Màn Hình 180°
• Đấu Hạng 1v1, Đấu Máy AI (4 cấp độ) hoặc Đấu 2 Người Trên 1 Máy (hỗ trợ xoay ngược 180° ngồi đối diện qua bàn).
• Cơ chế giải đề độc lập theo tốc độ riêng của từng người và hiệu ứng Sét Đánh Bạo Kích + Rung Haptic khi dồn chuỗi Combo.

4. Máy Đếm Nhịp Cơ Học Chuẩn Xác (< 10ms)
• 4 âm sắc (Tempo Lite, Cơ học, Gỗ trầm, Chuông), dải tốc độ 30–300 BPM, Tap Tempo, Chia nhỏ phách (1x–4x) và Tự động tăng tốc (Speed Trainer).

5. Hoạt Động 100% Offline, Đa Ngôn Ngữ (Việt – Anh) & Không Quảng Cáo Làm Phiền
• Tự động nhận diện quốc gia/vùng thiết bị và hỗ trợ song ngữ Tiếng Việt (Đô–Rê–Mi) & Tiếng Anh Quốc tế (C–D–E–F–G–A–B).
• Không yêu cầu đăng ký tài khoản, không thu thập dữ liệu cá nhân, tuân thủ Quy định (EU) 2018/302, GDPR và Nghị định 13/2023/NĐ-CP.
```

---

## 3. Nội dung Copy-Paste cho Ngôn ngữ Quốc tế (English – `en-US` cho 174+ Quốc gia)

### A. App name (max 30 chars)
```text
ChaoNote: Piano & Guitar Lab
```

### B. Short description (max 80 chars)
```text
Learn Piano, Guitar fretboard, staff sight-reading, 1v1 arena & pro metronome.
```

### C. Full description
```text
ChaoNote Studio is a 100% Offline-First Piano, Guitar, Sight-Reading, Ear Training, and Mechanical Metronome app designed to take learners from Basic to Advanced levels.

🌟 KEY FEATURES OF CHAONOTE STUDIO:
• 7 Piano & Music Theory Topics: Pitch recognition, Treble & Bass Clef sight-reading with Ledger Lines (C3–C6), Intervals, Chords, Key Signatures, Melodic Dictation, and Rhythm with a 4-voice polyphonic Piano studio.
• Interactive 6-String Guitar Studio: Full E2–E5 fretboard map, Open & Barre chords with real-time visual Strum & Ballad Arpeggio lighting, Am/C Scale maps, 6-line Tab reader, and 1-2-3-4 Spider Walk finger exercises.
• 1v1 Music Battle Arena: Ranked 1v1, 4-tier AI Bots, and 2-Player 180° Tabletop Split-Screen with independent question streams and Lightning Combo strikes.
• Precision Mechanical Metronome: 30–300 BPM, Tap Tempo, beat subdivisions, and Auto Speed Trainer.
• 100% Offline & Privacy-First: Compliant with EU Regulation 2018/302, GDPR, and CCPA across 174+ countries.
```
