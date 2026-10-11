# HiMorning — hồ sơ AI engineering

Tài liệu này mô tả công việc thực tế trong repository, phục vụ phỏng vấn và cải tiến quy trình. Đây là một **pilot đang phát triển**, có draft [PR #1](https://github.com/thanhdanh/HiMorning/pull/1); chưa phát hành, deploy Firebase hay benchmark nhận diện động tác với OpenAI thật.

## Vai trò của người phát triển và AI

Người phát triển xác định bài toán và các ràng buộc: phù hợp người Việt, dễ dùng, vàng nắng, nhiều mức cam kết, luôn có cách dừng, dùng OpenAI và Firebase, ưu tiên pilot iOS 26+. AI agent hỗ trợ nghiên cứu, viết kế hoạch/kiến trúc, tạo mockup, viết test trước, triển khai, đọc kết quả kiểm tra và sửa lỗi. Không nên kể rằng mọi dòng code/test đều được viết thủ công, hoặc rằng người phát triển đã review từng dòng nếu chưa làm việc đó.

Các quyết định kỹ thuật và test là bằng chứng có thể kiểm tra; số lượng prompt hay danh sách công cụ chỉ là thông tin phụ trợ.

## Từ yêu cầu đến code được kiểm chứng

| Giai đoạn | Cách dùng AI | Bằng chứng trong repo |
|---|---|---|
| Plan sản phẩm | Chuyển ý tưởng Erly thành các mức nhẹ nhàng/cân bằng/tập trung; tách xác minh hoàn thành và gợi ý tư thế | [Kiến trúc](ARCHITECTURE.md), [pose plan](POSE-FEEDBACK-PLAN.md) |
| Thiết kế | Định hướng giao diện Việt, vàng nắng, mockup tương tác trước native code | [UI design](UI-DESIGN.md), [prototype](../design/index.html) |
| Thiết kế hệ thống | Tách alarm offline, local pose/capture và xác minh cloud; backend giữ quyền quyết định | [Tech stack](TECH-STACK.md), [Firebase](FIREBASE.md), [plan triển khai](IMPLEMENTATION-PLAN.md) |
| Code bằng TDD | Viết test, chạy RED thật, commit checkpoint, sửa tối thiểu, chạy lại cùng test và commit GREEN | [TDD evidence](tdd/cost-optimized-pilot.tdd.md), lịch sử Git |
| Test nhiều lớp | Contract/unit → Firestore Emulator → Swift domain/file integration → hosted Xcode build/XCTest/UI | [Hướng dẫn chạy](RUNNING.md), [CI](../.github/workflows/ci.yml) |
| Đo và phản hồi | Trích xuất token thật, đối chiếu cumulative snapshot, lưu baseline; lỗi CI được giữ làm evidence | [Báo cáo số liệu](metrics/README.md), [collector](../scripts/lib/ai-usage.mjs) |

## MCPs, skills và plugins thực sự dùng

**MCP** cung cấp giao diện để agent gọi công cụ. **Skill** là hướng dẫn quy trình. **Plugin** đóng gói skill/công cụ; cài một plugin không chứng minh đã dùng mọi chức năng của nó.

| Thành phần | Vai trò thực tế | Giới hạn của bằng chứng |
|---|---|---|
| `codebase-memory` skill + `codebase-memory-mcp` | Kiểm tra project/index, lấy kiến trúc, kiểm tra coverage/freshness theo đường dẫn; re-index khi graph cũ | Không phải bộ nhớ cá nhân. Graph có thể thiếu symbol; không chứng minh toàn bộ call graph đúng |
| ECC 2.2.3: plan-orchestrate, architecture-decision-records, frontend-design-direction | Hướng dẫn các giai đoạn plan, kiến trúc và mockup; đường dẫn SKILL xuất hiện trong tool trace của cuộc hội thoại | Không tuyên bố có nhiều agent chạy song song; phiên này không dùng subagent |
| ECC `tdd-workflow` | RED/GREEN thật, checkpoint Git, evidence và coverage | Native adapter ban đầu là integration spike; không có local native TDD đầy đủ vì thiếu Xcode |
| `openai-docs` | Tra cứu tài liệu OpenAI chính thức cho Responses, ảnh, structured output và data controls | Docs lookup không thay thế benchmark model |
| ECC `cost-tracking` | Kiểm tra nguồn chi phí và nguyên tắc không cộng các cumulative snapshots | Hook của skill dành cho Claude Code; file `~/.claude/metrics/costs.jsonl` không tồn tại khi kiểm tra. Không dùng nó làm nguồn token Codex |
| Codex app tools | Mở artifact và gắn PR với cuộc hội thoại | GitHub thao tác chủ yếu qua `gh`/Git; không gọi một công cụ là MCP chỉ vì agent chạy CLI |
| Computer-use/CUA | Xem và thao tác prototype trong các lượt thiết kế | Không phải chứng cứ native camera/AlarmKit đã hoạt động trên iPhone |
| Shell + npm/Swift/Firebase CLI + GitHub Actions | Thực thi test, emulator, build, checkpoint, push và hosted validation | Test SDK mock không phải inference thật; emulator không phải production Firebase |

### Memory MCP: ví dụ phát hiện dữ liệu cũ

Index ban đầu ở `2026-10-11T05:21:54Z` có 162 nodes/359 edges. Khi code native/backend mới đã có, `check_index_coverage` trả `freshness: not_tracked` cho các file mới, dù status là `no_recorded_issue`. Agent không xem đó là bằng chứng code đã được index; đã đọc source và re-index ở chế độ `fast`, không thêm semantic embedding.

Lần refresh `2026-10-11T10:26:33Z` có 632 nodes/1.920 edges. Coverage của `functions/src/service.ts`, `openai.ts`, camera và cloud core khớp metadata. `ChallengeView.swift:66` có parse_partial; đoạn source quanh dòng đó được đọc trực tiếp. Fast index còn loại một số docs/scripts/tests theo cấu hình. Các con số này là một snapshot, không phải benchmark token tiết kiệm.

Quy trình dùng lại: kiểm tra index → truy vấn phạm vi hẹp → kiểm tra coverage/freshness → đọc source ở phần thiếu → refresh khi cần. Không nạp cả repository vào prompt và không suy ra “không tồn tại” từ một kết quả graph rỗng.

## Những kỹ thuật có thể giải thích sâu khi phỏng vấn

1. **Hybrid inference có ngân sách.** Vision/capture tại máy chỉ tạo evidence và đếm tạm. OpenAI đánh giá tối đa 25 JPEG; backend kiểm tra schema và các chu kỳ có thứ tự trước khi trả `verified`. Local count không tự biến thành thành công AI. Một paid attempt/session, không tự retry, quota theo user/toàn hệ thống, output 800 tokens, reasoning `none`, AI tắt mặc định. Đây là kiểm soát chi phí đã test; chưa phải bằng chứng độ chính xác hay số USD tiết kiệm.
2. **Idempotency và concurrency là phần của cost engineering.** Request ID, payload hash, atomic transaction và lease ngăn hai worker cùng gọi model. Paid call nằm ngoài transaction callback vì Firestore có thể chạy lại callback. Test mới bắt được repeated consent tạo hai session và repeated cancel ghi thêm DB.
3. **State machine chống kết quả đến muộn.** Stop/expiry có quyền ưu tiên; generation của client loại response cũ. Alarm native và quyền dừng không phụ thuộc network. Background suspension hủy cloud nhưng không dừng OS alarm.
4. **Evidence có thể audit.** RED phải là lỗi do behavior thiếu/sai, không tính thiếu Java/XCTest là RED. Checkpoint được giữ, test guarantees được mô tả bằng ngôn ngữ người dùng. Native SDK compilation được kiểm tra riêng trên hosted Xcode.
5. **Context có phạm vi và nguồn.** Graph trước, source fallback, đọc docs chính thức đúng chỗ, gom các read độc lập trong một tool batch. Compaction/handoff giữ trạng thái đang làm và không lấy summary thay kết quả test thật. Chưa có đối chứng để quy đổi các lựa chọn này thành phần trăm tiết kiệm.
6. **Đo token mà không đếm trùng.** Collector chỉ đọc rollout được chỉ định, lọc đúng thread, deduplicate `response_id`, cộng `usage` từng response và so với cumulative thread snapshot cuối. Cached input thuộc input; reasoning thuộc output. Không cộng lại các phần con hoặc cumulative event.

## Hooks và quality gates

Thêm hook Git **cục bộ cho repository** tại [.githooks/pre-push](../.githooks/pre-push), kích hoạt bằng `git config --local core.hooksPath .githooks`. Hook kiểm tra whitespace trên branch, TypeScript và unit/contract/metrics tests trước push. Nó không gọi OpenAI, không gửi transcript và không chạy emulator/Xcode. Full emulator/native checks nằm trong CI. Bản clone mới cần tự kích hoạt lại; config local không theo Git.

Không tạo global hook hoặc agent Stop hook. Không tuyên bố ECC Claude cost hook đã chạy trên Codex. Collector chạy thủ công để tạo snapshot, vì phiên này có log Codex thực; CI không có log chat local và không được truy cập chúng. Muốn bỏ local hook: `git config --local --unset core.hooksPath`.

## Đo hiệu quả thay vì chỉ đếm tokens

[Bảng baseline](metrics/README.md) phân biệt ba lớp:

- **Agent:** input/cached/output/reasoning theo lượt và nhóm việc, reconciliation, phần chưa phân loại; chi phí USD chưa biết.
- **Chất lượng phát triển:** behavior có test, coverage đúng phạm vi, RED/GREEN, CI pass/fail/cancel và thời gian từng job. Coverage cao không chứng minh AI nhận diện đúng.
- **Inference của app:** event `verification_token_usage` ghi số tokens/model; chưa có paid call. Cần thêm latency, provider request ID để dedup, outcome, lượng ảnh và bảng giá có ngày hiệu lực trước khi tính cost/verified session.

Lần benchmark tiếp theo nên cố định cùng task/acceptance criteria, commit gốc, runner và budget; so sánh graph-first với source-only trên các task tương đương. Thu thập uncached input, output, tool calls, wall-clock, acceptance lần đầu và lỗi còn lại. Chỉ nói tiết kiệm khi có baseline đối chứng, đồng thời giữ chất lượng không giảm. Không dùng “tokens/LOC” làm KPI chính vì khuyến khích sinh nhiều code.

Tách lượt `[phase:planning]`, `[phase:coding]`, `[phase:testing]`, `[phase:review]` và thêm turn ID vào phase-map sẽ giúp phân bổ các lần sau rõ hơn. Lượt lịch sử trộn code và test được giữ chung; không suy diễn tỉ lệ từ số dòng code. Model labels trong log là quan sát thực tế, không đủ chứng minh có model routing tối ưu.

## Cách kể trong phỏng vấn

> Tôi xây HiMorning theo hướng AI-assisted engineering: tự đặt yêu cầu UX và chọn pilot iOS, dùng agent để biến chúng thành architecture, test contracts và implementation. Tôi giữ RED/GREEN commits, kiểm thử concurrency/idempotency và cancellation trước khi tin vào luồng OpenAI. Tôi còn xây collector token có test để tách cached input, đối chiếu tổng phiên và gắn chi phí phát triển với kết quả kỹ thuật. Hiện đây là pilot: SDK build/UI được kiểm tra trên CI, còn độ chính xác động tác và trải nghiệm alarm thực tế cần benchmark trên iPhone.

Có thể demo: mở một RED commit → xem assertion/import failure → chuyển GREEN commit → chạy lại test → mở coverage và CI → giải thích cost caps → mở token ledger. Nếu chưa review một phần code, nói rõ agent thực hiện và chỉ ra cách bạn đã kiểm chứng; không biến giới hạn thành thành tích.
