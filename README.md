# HiMorning

Ứng dụng báo thức dành cho người dùng Việt Nam, màu vàng nắng và trải nghiệm thức dậy vừa sức. Pilot iOS 26+ đã được người dùng chọn. Mã nguồn ở `~/Projects/HiMorning`; repository GitHub riêng tư: [thanhdanh/HiMorning](https://github.com/thanhdanh/HiMorning).

## Đã triển khai

- `functions/src/`: Firebase Callable Functions, kiểm tra Auth/App Check, session có hạn dùng, Firestore transactions, idempotency, quota và OpenAI Responses adapter.
- `ios/HiMorningCore/`: Swift domain, lịch theo múi giờ/ngày lặp, lưu lịch cục bộ, journal trước khi đặt native alarm, phục hồi, capture theo năm pha và kiểm soát consent/cancel/response đến muộn.
- `ios/HiMorning/`: SwiftUI pilot tiếng Việt, AlarmKit, AVFoundation/Vision và Firebase client adapters. XcodeGen tạo project từ `ios/project.yml`.
- `tests/`, `ios/HiMorningCore/TestsPortable/`: unit/integration tests; Firestore Emulator/rules tests và portable Swift tests. `.github/workflows/ci.yml` kiểm tra backend và native build/UI.
- `design/`: mockup tương tác độc lập, không mở camera, không hẹn alarm và không gọi cloud.

Cloud AI **tắt mặc định**. Ảnh chỉ xử lý trong bộ nhớ, không lưu vào Firestore/Storage. Giới hạn 25 JPEG 512px, 50KB/ảnh, một paid attempt/session, không tự retry OpenAI; quota mặc định 3/user/ngày UTC và 100 toàn hệ thống/ngày. Output tối đa 800 tokens, reasoning `none`, verbosity thấp, metrics chỉ chứa số tokens/model. Model/ảnh giới hạn là ứng viên cần đánh giá, chưa chứng minh đủ chính xác cho release.

## Chạy và kiểm thử

Node 22, npm, Java 21:

```sh
npm ci --ignore-scripts
npm run typecheck
npm run build
npm test
npm run test:coverage
```

Swift domain với Command Line Tools:

```sh
sh scripts/test-swift.sh
```

Native iOS cần Xcode 26+ và XcodeGen:

```sh
xcodegen generate --spec ios/project.yml
open ios/HiMorning.xcodeproj
```

Xem [hướng dẫn chạy, cấu hình và giới hạn pilot](docs/RUNNING.md) và [bằng chứng TDD](docs/tdd/cost-optimized-pilot.tdd.md). Chưa tạo Firebase project, bật cloud billing, deploy hay gọi OpenAI tính phí. Native alarm/camera/audio cần kiểm tra trên iPhone thật trước phát hành. QR, native snooze/countdown, chỉnh sửa alarm và lịch sử tuần vẫn là các phần tiếp theo của kế hoạch; không được mô tả là đã hoàn thành.

## Hồ sơ AI engineering

Xem [cách dùng AI để plan/code/test, MCPs, skills, hooks và evidence phỏng vấn](docs/AI-ENGINEERING.md), cùng [baseline tokens và hiệu quả](docs/metrics/README.md). Token phát triển được đo từ đúng phiên Codex; không quy đổi thành hóa đơn OpenAI của app.

## Thiết kế và kiến trúc

- [Firebase](docs/FIREBASE.md), [tech stack/OpenAI](docs/TECH-STACK.md), [kiến trúc sản phẩm](docs/ARCHITECTURE.md).
- [UI/UX](docs/UI-DESIGN.md), [gợi ý tư thế](docs/POSE-FEEDBACK-PLAN.md), [kế hoạch triển khai pilot](docs/IMPLEMENTATION-PLAN.md).

`python3 scripts/preview.py` mở mockup tại http://127.0.0.1:4173/design/. Các âm web là sketch tổng hợp. Native pilot có hai chime tự tổng hợp và âm hệ thống; âm lượng nghe thử tách biệt với âm báo hệ thống.

Tham khảo UI công khai: [Erly trên App Store](https://apps.apple.com/us/app/erly-wake-up-early/id6751428380), [Erly trên Google Play](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en). HiMorning là dự án riêng; Erly chỉ là nguồn tham khảo.
