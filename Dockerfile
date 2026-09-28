# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Production-ready multi-stage Dockerfile:
# - Stage builder: cài đặt dependencies vào /install
# - Stage runtime: python:3.11-slim, copy dependencies từ builder
# - Chạy non-root với appuser
# - Có HEALTHCHECK kiểm tra /health
# - Đọc PORT từ biến môi trường
# ═══════════════════════════════════════════════════════════════════

FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim AS runtime

WORKDIR /app

RUN useradd --create-home --uid 10001 appuser

COPY --from=builder /install /usr/local

COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import os, urllib.request; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
