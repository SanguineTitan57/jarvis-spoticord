# -------- Build Stage --------
FROM rust:1.81-bullseye AS build

WORKDIR /app

# Install system dependencies for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    libpq-dev \
    cmake \
    nasm \
    aarch64-linux-gnu-gcc \
    gcc-multilib \
 && rm -rf /var/lib/apt/lists/*

# Copy your source code
COPY . .

# Add targets for multi-arch builds
RUN rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu

# Build binaries for both architectures
RUN cargo build --release --target x86_64-unknown-linux-gnu
RUN cargo build --release --target aarch64-unknown-linux-gnu

# -------- Runtime Stage --------
FROM debian:bookworm-slim AS runtime

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl3 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copy correct binary based on the platform
COPY --from=build /app/target/x86_64-unknown-linux-gnu/release/spoticord /tmp/x86_64
COPY --from=build /app/target/aarch64-unknown-linux-gnu/release/spoticord /tmp/aarch64

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        cp /tmp/x86_64 /usr/local/bin/spoticord; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        cp /tmp/aarch64 /usr/local/bin/spoticord; \
    else \
        echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1; \
    fi

# Clean temp binaries
RUN rm -rf /tmp/x86_64 /tmp/aarch64

# Final entrypoint
ENTRYPOINT ["/usr/local/bin/spoticord"]
