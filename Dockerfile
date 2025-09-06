# -------- Build Stage --------
FROM rust:1.81-bullseye AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    libpq-dev \
    libpq5 \
    cmake \
    nasm \
 && rm -rf /var/lib/apt/lists/*

COPY . .

# Build only for the host target
RUN cargo build --release

# -------- Runtime Stage --------
FROM debian:bookworm-slim AS runtime
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl3 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/spoticord /usr/local/bin/spoticord

ENTRYPOINT ["/usr/local/bin/spoticord"]
