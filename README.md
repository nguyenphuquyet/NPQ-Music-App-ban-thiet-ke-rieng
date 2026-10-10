# NPQ Music — Flutter mobile / tablet

App Flutter dùng API của dự án Next.js ở `http://localhost:3000`. UI dùng **TDesign + Lucide**, có layout điện thoại và tablet/iPad. Chrome là môi trường chạy thử dev.

## Chạy dev

Giữ backend cổng 3000 đang chạy:

```powershell
cd E:\npqmusic\flutter_app
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000
```

Nhấn `r` hot reload, `R` hot restart, `q` dừng. Không cần build release. Có thể chạy `powershell -ExecutionPolicy Bypass -File .\run-chrome.ps1`.

Mở bằng **localhost:5000**, không đổi sang 127.0.0.1 để khớp cookie và CORS của backend. Trong Chrome DevTools, bật Device Toolbar để thử 390×844 hoặc 375×812. Từ chiều rộng 760px, app chuyển sang sidebar cho tablet.

## Giao diện và tính năng

- Điện thoại: 4 tab Trang chủ / Khám phá / Thư viện / Cá nhân. Tablet: sidebar và player ngang.
- Header gọn, icon mở trang tìm kiếm riêng. Tìm bài hát/nghệ sĩ, lọc thể loại và phân trang.
- Trang chi tiết bài hát: ảnh bìa, nghệ sĩ, thời lượng, thể loại, lượt nghe, người đăng, lời bài hát, gợi ý nghe tiếp. Bấm thẻ hoặc tên bài để mở.
- Player phẳng, ảnh vuông, không bo góc/bóng đổ; chạm mở trình phát đầy đủ bằng CupertinoPageRoute trượt phải sang trái, hỗ trợ vuốt quay lại.
- Phát/tạm dừng, tua, trước/sau, âm lượng, ngẫu nhiên, lặp tắt/tất cả/một bài, hàng đợi.
- Đăng ký / đăng nhập / đăng xuất theo CSRF + cookie HttpOnly NextAuth; khôi phục phiên trên web.
- Yêu thích và lịch sử đồng bộ. `increment-play` tự ghi lịch sử trên server, không gửi trùng POST history.
- Tạo/đổi tên/xóa playlist, công khai/riêng tư, thêm/gỡ bài.
- Hồ sơ, đổi tên, tải audio/ảnh bìa, danh sách và xóa bài của chính mình có xác nhận.
- Theme sáng/tối: dùng cả theme TDesign tương ứng; thông báo lỗi và trạng thái trống.

Không dùng giao diện Material (AppBar, Scaffold, Card, Chip, NavigationBar, dialog hay menu Material). Theme/Material trong root chỉ cung cấp hạ tầng inherited mà chính TDesign cần cho input; control hiển thị dùng TDesign hoặc layout Flutter tùy chỉnh. Animation mở player dùng CupertinoPageRoute.

## Cấu trúc

- `lib/main.dart`: app state, tài khoản, danh sách, playlist, tải nhạc.
- `lib/mobile_ui.dart`: layout điện thoại/tablet, header, tìm kiếm, player.
- `lib/song_detail.dart`: trang chi tiết bài hát và lời nhạc.
- `lib/design.dart`: control TDesign, dialog, sheet, chuyển cảnh.
- `lib/api.dart`: HTTP, NextAuth, URL media.
- `lib/network_web.dart`, `network_native.dart`: cookie theo nền tảng.
- `lib/player.dart`: audio và hàng đợi.
- `vendor/tdesign_flutter/PATCH.md`: bản vá TDesign 0.2.7 cho Flutter 3.47.6; không sửa SDK hoặc pub cache toàn máy.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Smoke test Chrome khi dev đang chạy:

```powershell
npm.cmd install --prefix tooling
node tooling/smoke.cjs
```

Ảnh kiểm tra nằm ở `tooling/artifacts/` (gitignored).

## Chạy trên thiết bị

Đã có project Android/iOS. Android emulator dùng:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Điện thoại/iPad thật dùng IP LAN của backend. Debug Android cho phép HTTP local; production dùng HTTPS. iOS cần macOS/Xcode và cấu hình mạng phù hợp. Chưa kiểm thử trên thiết bị Android/iOS thật; chưa tích hợp phát nền qua notification/lock screen. Native hiện giữ cookie trong bộ nhớ, cần đăng nhập lại sau khi khởi động app.

Phạm vi là app nghe nhạc người dùng. Quản trị vẫn dùng web Next.js. Sửa avatar, tìm user/playlist công khai chưa có màn hình riêng. Audio phải thuộc định dạng thiết bị hỗ trợ; lỗi được hiện trên player.
