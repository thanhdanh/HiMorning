# HiMorning App Store submission draft

This draft is for the iPhone Release candidate built from HiMorning main with
bundled challenge content. Use the matching record in App Store Connect.

| Field | Draft value |
| --- | --- |
| Name | HiMorning |
| Bundle ID | `com.himorning.HiMorning` |
| Version and candidate build | `1.0 (1)` |
| Primary language | English (U.S.) |
| Additional localization | Vietnamese |
| Proposed category | Lifestyle |
| SKU for a new app record | `himorning-ios` |
| Public support email | `danhvt0109@gmail.com` |
| Release after approval | Manual |

## Listing copy

**Subtitle (en-US)** — A small start to your day

Set an alarm and choose a short activity for when you wake up. Try a
reading challenge or a movement challenge before adding it to your morning.
Build a routine over seven mornings and see the steps you've completed.

HiMorning uses your iPhone's alarm system. Basic alarms and wake recovery
work offline. Some activities ask for camera or microphone permission.

**Phụ đề (vi)** — Bắt đầu ngày mới nhẹ nhàng

Đặt báo thức và chọn một hoạt động ngắn khi thức dậy. Bạn có thể thử đọc
hoặc vận động trước khi đưa hoạt động vào lịch buổi sáng. Tạo thói quen
qua bảy buổi sáng và xem lại những bước đã hoàn thành.

HiMorning sử dụng hệ thống báo thức của iPhone. Báo thức cơ bản và các
lựa chọn xử lý khi thức dậy hoạt động khi không có mạng. Một số hoạt động
cần quyền camera hoặc micro.

## Review and TestFlight

1. Set an alarm a few minutes ahead and grant alarm permission.
2. Lock the iPhone and verify the main ring. Use system Stop and check
   the scheduled backup ring. Complete the activity in the app and verify
   that pending backup rings are cancelled.
3. Try the camera-free Read & Choose activity. Check on-device speech and
   movement on a real iPhone with permissions granted and denied.
4. Open HiMorning Pro from the sun icon. Verify localized price, purchase,
   restore, and expiry for the sandbox plans.

No HiMorning account is needed for the local app flows. The no-card preview
starts when the first alarm is successfully saved. A subscription purchase
is a separate action. The initial auto-renewable products are
`com.himorning.pro.monthly` and `com.himorning.pro.annual`.

## Before submitting

- Publish the [privacy and support copy](HIMORNING-PRIVACY-AND-SUPPORT.md) at
  a public HTTPS URL. Confirm users can reach the policy within the app.
- Verify App Privacy against the shipped package and its SDK manifests.
  The ordinary movement and speech paths process camera and audio on the
  device. Apple processes StoreKit purchases. Confirm the final disclosure
  against the archived app before submitting.
- Capture screenshots from the signed candidate with synthetic data and
  complete age rating and the initial storefront selection.
- Complete the [real-device matrix](RELEASE-READINESS.md) and
  [subscription lifecycle checks](SUBSCRIPTIONS.md). Submit the first
  subscription group and its products with the first app version.

References: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds),
[Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase).
