# -------- Build Stage --------
FROM rust:1.77-bullseye AS build

WORKDIR /app

# Copy your source code
COPY . .

# Install necessary tools for cross-compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# Build for x86_64 (amd64)
RUN cargo build --release --target x86_64-unknown-linux-gnu

# Build for aarch64 (arm64)
RUN rustup target add aarch64-unknown-linux-gnu
RUN cargo build --release --target aarch64-unknown-linux-gnu

# -------- Runtime Stage --------
FROM debian:bookworm-slim

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl1.1 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copy correct binary for the architecture
COPY --from=build /app/target/x86_64-unknown-linux-gnu/release/spoticord /tmp/x86_64
COPY --from=build /app/target/aarch64-unknown-linux-gnu/release/spoticord /tmp/aarch64

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        cp /tmp/x86_64 /usr/local/bin/spoticord; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        cp /tmp/aarch64 /usr/local/bin/spoticord; \
    fi

# Clean temp binaries
RUN rm -rf /tmp/x86_64 /tmp/aarch64

ENTRYPOINT ["/usr/local/bin/spoticord"]
