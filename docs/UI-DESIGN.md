# UI/UX · Nắng mới, nhịp riêng

**Concept:** HiMorning cho người dùng Việt Nam; tham khảo UI Erly. **Ngày:** 11/10/2026.

## Mục tiêu thiết kế

Dễ đặt, dễ hiểu, đủ linh hoạt cho người thích kỷ luật và người hay chần chừ. Khi vừa thức dậy, người dùng phải nhận ra ngay cần làm gì và có thể dừng ở đâu. Giao diện tham khảo cấu trúc screenshot Erly; dùng bảng màu, copy và chính sách tiến độ mới theo yêu cầu.

## Hệ màu và hình ảnh

| Token | Light | Dark |
|---|---|---|
| Canvas | #FFFCF6 | #201F1A |
| Surface | #FFFFFF | #2C2A24 |
| Primary | #F5C842 | #F5C842 |
| Primary text | #29251D | #29251D |
| Text | #29251D | #F8F4EA |
| Muted text | #756F63 | #C2BBAE |
| Border | #E9E5DC | #49463D |
| Success text | #44634A | #BDD6BF |

Vàng là màu hành động, dùng có khoảng thở trên nền kem. Mặt trời được vẽ hình học, không sao chép asset của Erly. Cam đất và xanh lá dịu chỉ hỗ trợ. Chữ tối trên vàng; không dùng chữ trắng nhỏ trên nền vàng.

Typography dùng system font để tiếng Việt sắc nét, dễ chuyển sang SF Pro/Roboto khi native. Giờ chính 64–72px, title 24–28px, nội dung 14–16px, metadata 12–13px. Mục tiêu tap 44pt+ trên native. Mock desktop hiển thị phone frame; trên mobile thành prototype một màn, không có horizontal overflow.

## Màn hình

1. **Báo thức:** logo nhỏ, next alarm, giờ lớn, nút sửa, trạng thái đã bật, thẻ alarm phụ, nút thêm. Tiến độ tuần chỉ một dòng; settings/progress ở navigation.
2. **Đặt báo thức:** giờ, label, ngày lặp, ba preset trong một segmented control; mission và sound là hàng chọn. Advanced mở theo yêu cầu. Nút lưu luôn dễ thấy.
3. **Âm thanh:** 6 lựa chọn theo nhóm; nút chọn tách với nút play; một âm mỗi lần. Slider chỉ điều chỉnh nghe thử, có nhãn rõ. Các mẫu tổng hợp trong prototype là sketch.
4. **Nhiệm vụ:** chọn none/push-up/QR và target, luôn có thử trước. Không hỏi quyền camera trong lúc tạo báo thức thường.
5. **Thức dậy:** giờ hiện tại, một CTA chính, snooze đúng budget, dừng rõ ràng. Không có quảng cáo/prompt trả tiền.
6. **Thực hiện:** vùng camera ở trên, counter lớn, chỉ dẫn ngắn; không nhận diện được thì không cộng. Counter local là tạm thời; đủ mục tiêu chuyển sang “Đang xác minh động tác…”, chỉ cloud verdict hợp lệ mới ghi AI completion. Prototype dùng minh họa, nút cộng rep và các kết quả AI giả lập ở bên ngoài phone.

   Bổ sung tùy chọn “Gợi ý động tác” ở màn chọn nhiệm vụ. Camera có ba trường hợp riêng: khung hình kém, động tác chưa trọn vẹn, gợi ý tư thế. Một cue mỗi lúc; form cue không tự chặn rep, tăng mục tiêu hay chụp mũ gian lận. Trong prototype, nút “Mô phỏng gợi ý tư thế” nằm ngoài phone. Nội dung kỹ thuật chưa được coi là đã thẩm định để phát hành; xem [kế hoạch gợi ý động tác](POSE-FEEDBACK-PLAN.md).
7. **Hoàn thành:** mặt trời vàng, thời gian, kết quả đúng loại và tuần hoàn thành. Ngày nghỉ trung tính. Câu chữ không khẳng định AI biết người dùng vẫn thức.
8. **Tiến độ:** đếm phiên hoàn thành trên số buổi có lịch; phân biệt tự xác nhận, verified, dừng và chưa có dữ liệu.

## Quy tắc nội dung

- “Buổi sáng, theo nhịp của bạn.”
- “Bạn muốn thức dậy thế nào?”
- “Thử trước cho yên tâm.”
- “Đặt máy xa hơn một chút.”
- “Hôm nay mình dừng ở đây.”
- “Một khởi đầu thật tốt.”
- Camera lỗi: “Chưa nhìn rõ động tác. Thử đặt lại điện thoại hoặc dừng nhiệm vụ.”

Không dùng nội dung phán xét khi dừng hoặc bỏ lỡ. Không gắn label tính cách cho người dùng. Không mất toàn bộ lịch sử vì một ngày nghỉ. Prompt gợi ý thêm khó phải opt-in và có thể bỏ qua.

## Preset và dữ liệu mẫu

Báo thức mới mặc định Nhẹ nhàng, none, âm Nắng sớm, snooze 2 × 5 phút. Màn home hiển thị một alarm mẫu 06:30 Đi làm, Cân bằng, push-up 3 lần, đã được luyện trước; alarm cuối tuần 07:30 dùng Nhẹ nhàng. Thời gian và tiến độ trong gallery là dữ liệu minh họa.

Preset balance/strict gợi ý 3/5 rep khi chưa tự chỉnh. QR hoặc nhiệm vụ none vẫn có thể được người dùng chọn; active session dùng snapshot. Thay đổi mode không tự đổi âm. Luồng camera hoặc cloud không dùng được phải có lối dừng hoặc lựa chọn khác. Trước challenge AI có consent gửi khung hình qua backend tới OpenAI; từ chối vẫn dùng QR/local hoặc báo thức thường. Trang privacy giải thích retention, không ghi toàn bộ ảnh ở lại máy.

## Âm thanh

Sáu tên làm việc: Nắng sớm, Chuông ấm, Ban mai, Trong veo, Nhịp sáng, Rõ nhịp. Preview tổng hợp bằng Web Audio, chỉ khởi chạy khi click; tự tắt khi chuyển màn hình, hết đoạn hoặc tab ẩn. Không tải audio bên ngoài.

Trước phát hành: lựa chọn/sáng tác asset có quyền sử dụng; kiểm tra độ rõ, âm sắc, mức loudness tương đương, peak, vòng lặp, speaker và audio routing. Đo khả năng đánh thức và ảnh hưởng người cùng phòng. Không dùng mức volume của web preview để suy ra âm lượng AlarmKit. Control volume/ramp-up của app native còn phụ thuộc spike.

## Tương tác của mockup

- “Bộ màn hình”: tổng quan 6 màn chính, mỗi màn có thể mở vào prototype.
- “Bấm thử”: home → edit/create → mode/mission/sound → save → alarm preview → snooze/mission/stop → completion.
- Nút “Mô phỏng đến giờ” thuộc thanh review ngoài app. Không có alarm nền thực tế.
- Nút cộng rep, khung hình kém, khôi phục và xác nhận QR nằm ngoài phone, là công cụ mô phỏng sự kiện camera. Đủ rep mới xuất hiện controls giả lập AI xác nhận / chưa rõ / lỗi kết nối. Không có API thật trong mockup.
- “Kiến trúc”: bản đồ module tương tác và đường dẫn sang đặc tả đầy đủ.
- Toggle sáng/tối áp dụng vào phone; trạng thái ngoài app giữ trung tính. Reset đưa toàn bộ dữ liệu về mẫu.

## Acceptance cho review

- Văn bản tiếng Việt đủ dấu, không tràn ở 390px và 360px.
- Controls có label; nút chọn/play khác nhau; keyboard focus rõ; reduced motion được tôn trọng.
- Lưu giờ/ngày/mode/sound phản ánh lại trên home; cancel không commit draft.
- Snooze hoạt động đúng budget và không tự tăng độ khó.
- Dừng, camera lỗi hoặc API chưa xác minh không nhận nhầm AI completion; rehearsal không cộng progress. Trạng thái chờ AI vẫn có đường thoát, thử lại không tự tăng mục tiêu.
- Rời sound screen, reset hoặc ẩn tab đều dừng âm.
- Gallery/phone không hứa có native alarm/camera thật; hạn chế mô phỏng được ghi ở review shell và README.

Tham khảo: [App Store Erly](https://apps.apple.com/us/app/erly-wake-up-early/id6751428380), [Google Play Erly](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en), [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).
