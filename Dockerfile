# ---------- Stage 1: builder - install dependencies into a virtual env ----------
FROM python:3.12-slim AS builder

WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# ---------- Stage 2: runner - only what is needed to run the app ----------
FROM python:3.12-slim AS runner

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_PATH=/app/database/db.json

WORKDIR /app

# The venv lives in /opt (not /root/.local), so the non-root user can read it
COPY --from=builder /opt/venv /opt/venv
COPY app.py .
COPY templates/ templates/

# Run as a limited user instead of root
RUN useradd -u 10011 -m appuser && \
    mkdir -p /app/database && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
