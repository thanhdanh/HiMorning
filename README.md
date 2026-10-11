# HiMorning

HiMorning là dự án ứng dụng báo thức dành cho người dùng Việt Nam. Repository hiện chứa bản kiến trúc đề xuất và mockup tương tác để review trước khi xây app native. Ngày cập nhật: 11/10/2026.

- [Kiến trúc Firebase được đề xuất](docs/FIREBASE.md)
- [Tech stack và luồng xác minh bằng OpenAI](docs/TECH-STACK.md)
- [Kiến trúc và các quyết định đề xuất](docs/ARCHITECTURE.md)
- [Đặc tả UI/UX, màu sắc và âm thanh](docs/UI-DESIGN.md)
- [Kế hoạch gợi ý động tác](docs/POSE-FEEDBACK-PLAN.md)
- [Mở mockup](design/index.html)

## Xem thử

Mở `design/index.html` trực tiếp bằng trình duyệt, hoặc chạy từ thư mục dự án:

```sh
python3 scripts/preview.py
```

Sau đó mở http://127.0.0.1:4173/design/.

Mockup không cần cài dependency và không gửi dữ liệu ra mạng. Có thể chuyển màn hình, đổi chế độ thức dậy, đặt giờ/ngày lặp, nghe sáu mẫu âm tổng hợp, lưu báo thức mẫu và chạy thử luồng nhiệm vụ. Dữ liệu nằm trong bộ nhớ và được đặt lại khi tải lại trang.

Đây là prototype thiết kế, chưa phải app native: không hẹn báo thức hệ thống, không truy cập camera, không nhận diện người thật và không gọi OpenAI. Kiến trúc app phát hành có gửi khung hình đến OpenAI sau consent; trạng thái AI trong mock chỉ được giả lập. Các âm thanh là bản phác thảo để so sánh tính cách âm; chưa phải tài sản âm thanh phát hành.

Tham khảo UI công khai: [Erly trên App Store](https://apps.apple.com/us/app/erly-wake-up-early/id6751428380), [Erly trên Google Play](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en). HiMorning là tên của dự án; Erly chỉ là nguồn tham khảo UI công khai.

## Vị trí và trạng thái mã nguồn

- Thư mục phát triển: `~/Projects/HiMorning`.
- `design/index.html`, `design/styles.css`, `design/app.js`: prototype HTML/CSS/JavaScript, có sound preview và AI simulation.
- `scripts/preview.py`: preview server cục bộ, không phải backend app phát hành.
- `docs/`: đặc tả kiến trúc, Firebase, UI và posture feedback.

Stack mục tiêu: SwiftUI/AlarmKit/Vision trên iOS; Kotlin/Compose/AlarmManager/CameraX trên Android; Firebase Authentication, Cloud Firestore, Cloud Functions for Firebase (TypeScript) và OpenAI Responses API.

App native, Firebase Functions và kết nối OpenAI thật chưa được triển khai. Chưa tạo Firebase project, bật billing hoặc deploy cloud services.
