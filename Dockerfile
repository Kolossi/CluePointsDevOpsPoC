# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: builder
# Install dependencies into an isolated prefix so only they are copied across.
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

# Install dependencies first for layer-cache efficiency
COPY requirements.txt ./
RUN pip install --upgrade pip \
 && pip install --prefix=/install --no-cache-dir -r requirements.txt

# Copy application source
COPY . .

# ---------------------------------------------------------------------------
# Stage 2: runtime
# Minimal image — no build tooling, no pip cache.
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

# OCI standard image labels
ARG BUILD_VERSION=dev
LABEL org.opencontainers.image.title="helloworld-demo-python" \
      org.opencontainers.image.description="CluePoints DevOps PoC — helloworld demo app" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.source="https://github.com/dockersamples/helloworld-demo-python"

WORKDIR /app

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy application source from builder
COPY --from=builder /build .

EXPOSE 8080

# Run as non-root user for security
RUN adduser --disabled-password --gecos "" appuser
USER appuser

CMD ["python", "-W", "ignore", "app.py"]
