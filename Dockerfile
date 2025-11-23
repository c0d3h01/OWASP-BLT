# Stage 1: Builder
FROM python:3.11.2 AS builder
WORKDIR /blt

# Install system deps + Chromium in one layer
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        postgresql-client libpq-dev \
        libmemcached11 libmemcachedutil2 libmemcached-dev libz-dev \
        dos2unix chromium && \
    ln -sf /usr/bin/chromium /usr/local/bin/google-chrome && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Stage 2: Runtime
FROM python:3.11.2-slim AS runtime

# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.5.0 /uv /uvx /bin/

WORKDIR /blt

ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONDONTWRITEBYTECODE=1

# Install lean runtime deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-client libpq5 \
        libmemcached11 libmemcachedutil2 dos2unix && \
    rm -rf /var/lib/apt/lists/*

# Mount deps + source together → single sync
COPY . /blt
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen && \
    rm -rf /blt/.venv

# Copy needed binary from builder
COPY --from=builder /usr/local/bin/google-chrome /usr/local/bin/google-chrome

# Final prep
RUN dos2unix docker-compose.yml /blt/scripts/entrypoint.sh ./blt/settings.py && \
    ([ ! -f /blt/.env ] || dos2unix /blt/.env) && \
    chmod +x /blt/scripts/entrypoint.sh

ENTRYPOINT ["/blt/scripts/entrypoint.sh"]
CMD ["uv", "run", "python", "manage.py", "runserver", "0.0.0.0:8000"]
