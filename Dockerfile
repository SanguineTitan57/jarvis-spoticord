# -------- Build Stage --------
FROM rust:1.81-bullseye AS builder

# Set working directory
WORKDIR /app

# Install only necessary build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    libpq-dev \
    cmake \
    nasm \
 && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . .

# Add Rust targets for multi-arch builds
RUN rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu

# Build binaries for both architectures
# x86_64
RUN cargo build --release --target x86_64-unknown-linux-gnu
# ARM64
RUN cargo build --release --target aarch64-unknown-linux-gnu

# -------- Runtime Stage --------
FROM debian:bookworm-slim AS runtime

WORKDIR /app

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl3 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copy the correct binary based on target platform
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/spoticord /tmp/x86_64
COPY --from=builder /app/target/aarch64-unknown-linux-gnu/release/spoticord /tmp/aarch64

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        cp /tmp/x86_64 /usr/local/bin/spoticord; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        cp /tmp/aarch64 /usr/local/bin/spoticord; \
    else \
        echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1; \
    fi

# Clean temporary binaries
RUN rm -rf /tmp/x86_64 /tmp/aarch64

# Entrypoint
ENTRYPOINT ["/usr/local/bin/spoticord"]
