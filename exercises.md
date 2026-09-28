# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `dòng hướng dẫn` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Trọng Chinh  Mã học viên: 2A202602720

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu để mặc định là `"changeme"`, khi deploy lên Cloud mà quên cấu hình biến môi trường `AGENT_API_KEY`, ứng dụng vẫn sẽ khởi động thành công và báo trạng thái Healthy. Khi đó, kẻ tấn công hoặc bot quét tự động có thể gọi API bằng key mặc định `"changeme"`, làm rò rỉ dữ liệu hoặc gọi LLM tiêu tốn tiền mà không bị chặn, và ta chỉ phát hiện ra khi hóa đơn tăng vọt. Ngược lại, với cơ chế Fail-fast (không có giá trị mặc định), ứng dụng sẽ ném ra lỗi `ValidationError` và crash ngay trong lúc khởi động, giúp kỹ sư phát hiện và bổ sung secret ngay lập tức trước khi traffic của người dùng được điều hướng vào.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

- Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T08:16:24.123456+00:00", "user_id": "sv-test", "tokens_in": 12, "tokens_out": 25, "cost_usd": 0.000185}`

- Hai việc làm được với log có cấu trúc (Structured Logging) mà `print()` thông thường không làm được:
1. **Lọc, tổng hợp và phân tích theo trường dữ liệu (Aggregation & Filtering):** Các hệ thống log management (Datadog, CloudWatch, Loki, Elasticsearch) có thể parse JSON tự động để thực hiện truy vấn như: tính tổng chi phí `cost_usd` của từng `user_id` trong ngày, hoặc đếm tổng lượng token tiêu thụ.
2. **Thiết lập cảnh báo tự động (Alerting & Metrics):** Có thể đặt ngưỡng cảnh báo thời gian thực khi có user tiêu thụ bất thường (ví dụ: `tokens_out > 2000` hoặc `cost_usd > 1.0`), hoặc tạo dashboard biểu đồ latency, token rate mà không cần viết regex để bóc tách chuỗi text không đồng nhất.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1.02 GB |
| Multi-stage | ~185 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~800MB) bao gồm:
1. Base image: `python:3.11` đầy đủ chứa hệ điều hành Debian hoàn chỉnh kèm toàn bộ công cụ phát triển, trình biên dịch C/C++ (`gcc`, `g++`, `make`), các thư viện phát triển header (`python3-dev`, `libc-dev`, package managers mở rộng). Trong khi đó, `python:3.11-slim` chỉ giữ lại runtime tối thiểu để chạy Python.
2. Multi-stage build tách riêng stage `builder` để cài đặt thư viện vào thư mục `/install`, stage runtime chỉ copy các package đã cài sang `/usr/local` mà không mang theo cache của pip (`--no-cache-dir`) hay các công cụ biên dịch tạm thời.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Khi sửa một ký tự trong `app/main.py`:
  - Các layer trước đó (`FROM`, `WORKDIR`, `COPY requirements.txt .`, `RUN pip install`, `RUN useradd`, `COPY --from=builder`) đều được tận dụng hoàn toàn từ Docker cache (`CACHED`).
  - Chỉ các layer từ `COPY app ./app` trở về sau mới phải chạy lại.
- Nếu đặt `COPY . .` lên trước `RUN pip install`:
  - Mỗi khi sửa bất kỳ file nào trong source code (dù chỉ 1 ký tự), Docker cache của layer `COPY . .` sẽ bị mất hiệu lực (cache miss).
  - Kéo theo tất cả các layer tiếp theo — đặc biệt là `RUN pip install` — sẽ bị buộc phải tải và cài đặt lại toàn bộ thư viện từ đầu, làm tăng thời gian build từ vài giây lên vài phút mỗi lần build.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện:
  1. Ứng dụng Python có một lỗ hổng bảo mật (ví dụ: Remote Code Execution - RCE qua `eval`, deserialization, hoặc command injection).
  2. Kẻ tấn công khai thác lỗ hổng để thực thi shellcode trong container. Vì container mặc định chạy bằng UID 0 (`root`), tiến trình của kẻ tấn công có quyền cao nhất bên trong container.
  3. Kẻ tấn công khai thác tiếp các lỗ hổng container escape (ví dụ lỗ hổng kernel Linux, misconfigured capabilities, hoặc đọc ghi vào socket `/var/run/docker.sock`, mount volume nhầm) để leo thang ra máy host. Vì UID 0 trong container thường map với UID 0 (root) trên máy host (nếu không bật user namespace), kẻ tấn công chiếm toàn quyền kiểm soát máy host.
- Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay từ bước 2: Tiến trình chạy dưới quyền một user không có đặc quyền (non-root, UID 10001, không có quyền `sudo`). Dù có chèn được mã độc, kẻ tấn công không thể ghi vào các file hệ thống, không thể cài gói mã độc, và không có đủ đặc quyền để khai thác các kỹ thuật container breakout ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Số request tối đa gửi được: **20 request**.
- Giải thích:
  - Với cơ chế fixed window (reset theo phút đồng hồ lúc :00), khoảng thời gian được chia cố định từng phút (ví dụ 10:00:00 - 10:00:59 và 10:01:00 - 10:01:59).
  - Kẻ tấn công có thể gửi 10 request vào giây cuối cùng của phút trước (10:00:59). Lúc này quota của phút đó vừa đủ 10.
  - Ngay sang giây tiếp theo (10:01:00), bộ đếm bị reset về 0. Kẻ tấn công gửi tiếp 10 request nữa.
  - Tổng cộng hệ thống phải chịu 20 request chỉ trong vòng 2 giây (10:00:59 - 10:01:00), gấp đôi hạn mức tối đa cho phép trong 1 phút, có nguy cơ làm sập backend (traffic burst).

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Sự khác nhau:
  - **Rate Limit:** Kiểm soát **tần suất / số lượng request** trong một khoảng thời gian ngắn (ví dụ: tối đa 10 requests / phút) nhằm chống DDoS, spam, và làm nghẽn tài nguyên CPU/mạng.
  - **Cost Guard:** Kiểm soát **ngân sách tài chính / chi phí thực tế** theo tháng (USD hoặc token) nhằm tránh phát sinh hóa đơn LLM khổng lồ.
- Tình huống Rate Limit cho qua nhưng Cost Guard chặn:
  - Một user chỉ gửi 1 request trong 10 phút (rất thấp so với rate limit 10 req/phút), nhưng tài khoản của user đó đã chạm trần ngân sách tháng ($10.00). Khi gửi request tiếp theo, Rate Limiter cho qua nhưng Cost Guard sẽ chặn lại và trả về lỗi 402 Payment Required.
- Tình huống Cost Guard cho qua nhưng Rate Limit chặn:
  - Một user mới đăng ký đầu tháng, ngân sách còn nguyên $10.00 (chưa tiêu đồng nào). User này viết script gửi 50 câu hỏi ngắn chỉ trong 5 giây. Chi phí tiền chỉ mất vài cent (vẫn nằm trong ngân sách), nhưng Rate Limiter sẽ lập tức chặn từ request thứ 11 và trả về mã lỗi 429 Too Many Requests để bảo vệ hệ thống khỏi bị quá tải.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

1. Redis gặp sự cố mạng tạm thời hoặc restart, không thể kết nối trong 30 giây.
2. Orchestrator (Docker/Kubernetes/Cloud Load Balancer) định kỳ gọi Liveness probe (vốn bị gộp chung với readiness).
3. Vì probe ping Redis thất bại, cả 3 container đồng loạt trả về lỗi 500/503.
4. Orchestrator nhận định cả 3 process container đã bị crash/treo, lập tức kích hoạt lệnh tiêu diệt (SIGKILL) và khởi động lại (restart) toàn bộ 3 container.
5. Các container khởi động lại trong khi Redis vẫn chưa hồi phục, tiếp tục fail healthcheck và lại bị restart liên tục (hiện tượng CrashLoopBackOff / restart storm).
6. Toàn bộ các request đang xử lý dở dang của người dùng bị đứt gãy, tài nguyên CPU/RAM máy chủ bị tiêu tốn lãng phí vào việc restart container liên tục.
7. Thay vì chỉ tạm thời ngừng nhận request mới (nếu tách riêng `/ready`), hệ thống biến một sự cố nhỏ của Redis thành sự cố tê liệt hoàn toàn dịch vụ.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Nếu lưu trong Redis (Stateless): `history_length` sẽ tăng tuần tự liên tục (0, 2, 4, 6...) bất kể request được load balancer phân phối tới container nào trong 3 container, vì cả 3 đều chia sẻ chung một cơ sở dữ liệu Redis.
- Nếu lưu trong dict Python trong RAM (Stateful):
  - Mỗi instance container sở hữu một vùng nhớ RAM tách biệt hoàn toàn.
  - Khi load balancer điều hướng request theo thuật toán round-robin tới luân phiên 3 container (A, B, C):
    - Request 1 vào container A: `history_length` = 0 (A ghi nhớ câu hỏi 1).
    - Request 2 vào container B: `history_length` = 0 (B chưa từng thấy user này, coi như người lạ).
    - Request 3 vào container C: `history_length` = 0.
    - Request 4 quay lại container A: `history_length` = 2.
  - Kết quả là `history_length` nhảy lộn xộn, agent bị "mất trí nhớ", không duy trì được ngữ cảnh hội thoại mạch lạc của người dùng.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Lỗi gặp phải:** Health check timeout / Service unreachable do app hardcode cổng 8000 và không đọc biến môi trường `$PORT`.
- **Thông báo lỗi:** Platform log báo: `Port check failed: Service failed to bind to $PORT (10000) within 60s. Deployment failed.`
- **Cách tìm ra nguyên nhân:** Đọc runtime log trên Dashboard của nền tảng cloud (Render/Railway), thấy Uvicorn báo `Uvicorn running on http://0.0.0.0:8000`, trong khi platform quy định cấp ngẫu nhiên một cổng qua biến môi trường `$PORT` (ví dụ 10000) và gửi health check probe vào cổng đó.
- **Cách khắc phục:** Cập nhật lại lệnh CMD trong `Dockerfile` và script chạy để đọc giá trị `${PORT:-8000}` thay vì cố định 8000:
  `CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`
  và trong `Settings` cấu hình `port: int = 8000` tự động ánh xạ từ biến môi trường `PORT`. Sau khi commit và deploy lại, container khởi động và bind đúng cổng do platform chỉ định.
