# ---------- Stage 1: builder - install dependencies into a virtual env ----------
FROM python:3.12-slim AS builder

WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .

# Optional extra CA certificate (e.g. a filtering proxy such as NetFree) - passed only on local builds:
#   docker build --secret id=extra_ca,src=certs/netfree-ca.pem ...
# It is a build secret, so it never ends up in the image; CI builds simply skip it.
RUN --mount=type=secret,id=extra_ca \
    if [ -f /run/secrets/extra_ca ]; then \
        cat "$(python -c 'import pip._vendor.certifi as c; print(c.where())')" /run/secrets/extra_ca > /tmp/ca-bundle.pem && \
        export PIP_CERT=/tmp/ca-bundle.pem; \
    fi && \
    pip install --no-cache-dir -r requirements.txt


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

# Run as a limited user instead of root
RUN useradd -u 10011 -m appuser && \
    mkdir -p /app/database && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
