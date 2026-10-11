# Baseline đo AI engineering

Snapshot token đến **2026-10-11T10:32:34.654Z** (UTC; giờ Việt Nam +07:00), 178 response có usage. Đây là điểm chụp giữa phiên, không phải tổng cuối cùng của mọi công việc về sau.

Nguồn: [agent usage JSON](ai-usage-baseline.json), [phân nhóm lượt](phase-map.json), [quality JSON](quality-baseline.json), [CI JSON](ci-baseline.json). Raw transcript, prompts, ảnh, API keys và đường dẫn rollout cá nhân không được commit. Collector chỉ đọc một file được chỉ định của đúng thread; file local dùng schema quan sát ngày 11/10/2026, không phải public API ổn định.

## Token đã đo

- Input: **25,283,416**; trong đó cached input **23,766,272** và uncached input **1,517,144**.
- Output: **205,159**, đã bao gồm **55,721** reasoning tokens.
- Tổng input + output: **25,488,575**. Cached input ratio: **94.00%**.
- Tổng từng response khớp cumulative thread snapshot: **true**; delta mọi trường bằng 0. Usage của response được dedup theo ID; không cộng các snapshot tích lũy.
- USD: **chưa có dữ liệu hóa đơn**, giữ `null`. Tokens của Codex không được chuyển thành chi phí OpenAI API của app.

Input là tổng token context được xử lý qua nhiều request, có thể đọc lại cùng context nhiều lần; không phải số từ duy nhất của code/prompt. Cached ratio không đồng nghĩa phần trăm tiền hoặc thời gian tiết kiệm. Không cộng cached input lần nữa vào input, hoặc reasoning lần nữa vào output.

## Theo hạng mục

Phân nhóm bằng turn ID và yêu cầu của lượt; tổng tokens đo được, còn nhãn nhóm do người/agent gán. Không thể tách chính xác code/test/research trong một lượt trộn nếu lúc đó chưa đánh dấu phase. Các lượt không có usage record không được giả lập bằng số 0; tổng quan sát vẫn được đối chiếu snapshot phiên.

| Hạng mục | Input | Cached (thuộc input) | Uncached | Output | Tổng |
|---|---:|---:|---:|---:|---:|
| Plan sản phẩm/UX | 861,800 | 766,720 | 95,080 | 7,042 | 868,842 |
| Tham khảo Erly | 693,121 | 655,744 | 37,377 | 1,838 | 694,959 |
| Kiến trúc + UI mock | 727,018 | 688,512 | 38,506 | 38,616 | 765,634 |
| Plan góp ý tư thế | 3,326,351 | 3,282,176 | 44,175 | 9,807 | 3,336,158 |
| Kiến trúc OpenAI | 2,562,602 | 2,232,832 | 329,770 | 19,693 | 2,582,295 |
| Mô tả tech stack | 281,577 | 139,776 | 141,801 | 1,207 | 282,784 |
| Di chuyển repo + GitHub/Firebase | 2,772,336 | 2,583,424 | 188,912 | 10,822 | 2,783,158 |
| Chuẩn bị triển khai/TDD | 1,029,067 | 1,000,192 | 28,875 | 2,120 | 1,031,187 |
| Triển khai + test (lượt trộn) | 11,346,403 | 11,032,320 | 314,083 | 84,250 | 11,430,653 |
| Sửa lỗi + metrics/docs (lượt hiện tại) | 1,683,141 | 1,384,576 | 298,565 | 29,764 | 1,712,905 |

## Theo model được log ghi nhận

| Model | Input | Cached | Output | Tổng |
|---|---:|---:|---:|---:|
| gpt-6-astra | 8,170,892 | 7,625,984 | 76,996 | 8,247,888 |
| gpt-6.1-sol | 16,666,457 | 15,907,200 | 113,883 | 16,780,340 |
| unknown | 446,067 | 233,088 | 14,280 | 460,347 |

`unknown` nghĩa là record không có turn context khớp để gán model; vẫn tính tokens và giữ nguyên phần chưa biết. Đây không phải bằng chứng agent tự chọn model tối ưu. Phần lớn planning ban đầu dùng label `gpt-6-astra`, triển khai dùng `gpt-6.1-sol` theo trace.

## Chất lượng và CI

| Chỉ số | Baseline đã quan sát | Cách diễn giải |
|---|---|---|
| Vitest | 50/50 đạt: 42 backend + 8 collector | Có real Firestore Emulator; OpenAI dùng mock |
| Backend coverage | 97.54% statements; 95.86% branches; 92.50% functions; 100% lines | Chỉ backend TypeScript |
| Collector library | 100% statements/functions/lines; 98.14% branches | CLI wrapper không nằm trong instrumented scope |
| Swift core | 13 portable journeys đạt; 83.67% regions; 98.55% functions; 97.76% lines | Native adapters ngoài scope; không có branch counters |
| Hosted native | Swift XCTest, SDK build và gentle-default UI test đạt | Không chứng nhận alarm/camera/audio trên iPhone thật |
| TDD | 9 chu kỳ có mapping RED/GREEN trong evidence | Không đếm native integration spike thành native runtime TDD |
| Production audit | 0 advisories | Full dev audit còn 16; xem TDD report |
| Paid inference thật | 0 call trong quá trình này | Chưa có accuracy/latency/cost benchmark |

CI baseline trước push docs/metrics: **5 runs**, gồm **1 success / 2 failure / 2 cancelled**. Hai failure phát hiện lỗi compile native. Hai cancelled có một manual dispatch trùng push, là chi phí orchestration cần tránh. Không giấu các lần thất bại để làm đẹp pass rate. Mẫu nhỏ này không phải đánh giá năng suất dài hạn.

[Run xanh 38131960302](https://github.com/thanhdanh/HiMorning/actions/runs/38131960302) ở commit `39ecc17`: elapsed toàn run **236 giây**; job backend **56 giây**, iOS **230 giây**. Hai job chạy song song nên không cộng job duration thành elapsed. Runner billing minutes/chi phí USD chưa thu thập; thời gian chờ review/tool cũng không được coi là thời gian model tính toán.

## Cập nhật lại số liệu

Trong repo, chỉ định đường dẫn rollout của cuộc hội thoại hiện tại và cập nhật `threadID`/`phaseByTurn` nếu dùng phiên mới:

```sh
node scripts/collect-ai-usage.mjs --log /absolute/path/to/current-rollout.jsonl > /private/tmp/ai-usage.json
npm test -- tests/engineering-metrics.test.ts
```

Review JSON rồi chép snapshot đã lọc vào `docs/metrics/ai-usage-baseline.json`, cập nhật bảng trong tài liệu cùng thời điểm cutoff. Không commit raw rollout. `sourceSHA256` xác định bytes đã đọc tại thời điểm chụp; log tiếp tục append sẽ có hash mới. Collector từ chối số token không hợp lệ, duplicate xung đột hoặc JSONL hỏng ở dòng hoàn chỉnh; chỉ bỏ dòng cuối chưa ghi xong và báo cờ tương ứng. Snapshot thiếu usage hoặc thiếu reconciliation được giữ `null`, không biến thành “0 token”.

Agent Stop cost hook của ECC dành cho Claude Code không được bật ở đây. Git pre-push hook chỉ làm quality gate, không phải token meter. CI hiện chạy test/coverage và lưu log; các JSON baseline được xuất chủ động, chưa có lịch tự cập nhật.

## Các KPI nên theo dõi tiếp

| KPI | Công thức / cách lấy | Trạng thái |
|---|---|---|
| Token theo phase | Unique response usage, phase map theo lượt riêng | Có baseline; lịch sử code/test còn trộn |
| Acceptance lần đầu | Task đạt toàn acceptance trong lần review đầu / tổng task | Chưa có review ledger độc lập |
| Rework | Uncached + output tokens các lượt sửa / tổng cùng đơn vị | Chưa phân loại đủ, không gán mọi token test là rework |
| CI waste | Cancelled/duplicate runs, job durations, runner billing | Có lịch sử run; chưa có hóa đơn |
| Cost/accepted behavior | Chi phí agent thực / behavior được chấp nhận | Chưa đủ hóa đơn và denominator |
| App cost/verified session | Chi phí provider thực / session verified, kèm tỷ lệ uncertain | Chưa có real inference |
| Accuracy theo điều kiện | False accept/reject, uncertain, latency p50/p95 theo ánh sáng/góc máy/nhóm người | Cần bộ video có consent, ground truth và holdout |
| Lợi ích memory MCP | So task tương đương graph-first/source-only cùng chất lượng | Chưa chạy đối chứng; không tuyên bố tiết kiệm X% |

Khi đánh giá app, đo uncertainty và false acceptance cùng chi phí. Chỉ giảm tokens mà làm xác minh kém đi thì chưa phải tối ưu thành công. Khi đánh giá agent, ưu tiên behavior được chấp nhận và lỗi còn lại; số dòng code và số công cụ dùng không đại diện năng lực.
