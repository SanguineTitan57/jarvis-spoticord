# Builder stage
FROM --platform=linux/amd64 rust:1.80.1-slim AS builder

WORKDIR /app

# Build dependencies with TLS
RUN apt-get update && apt-get install -yqq \
    cmake gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    libpq-dev libssl-dev ca-certificates curl bzip2

# Manually compile arm64 libpq (optional, for multi-arch)
ENV PGVER=16.4
RUN curl -o postgresql.tar.bz2 https://ftp.postgresql.org/pub/source/v${PGVER}/postgresql-${PGVER}.tar.bz2 && \
    tar xjf postgresql.tar.bz2 && \
    cd postgresql-${PGVER} && \
    ./configure --host=aarch64-linux-gnu --enable-shared --disable-static --without-readline --without-zlib --without-icu && \
    cd src/interfaces/libpq && \
    make

COPY . .

RUN rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu

# Build binaries
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release --target=x86_64-unknown-linux-gnu && \
    RUSTFLAGS="-L /app/postgresql-${PGVER}/src/interfaces/libpq -C linker=aarch64-linux-gnu-gcc" \
        cargo build --release --target=aarch64-unknown-linux-gnu && \
    cp /app/target/x86_64-unknown-linux-gnu/release/spoticord /app/x86_64 && \
    cp /app/target/aarch64-unknown-linux-gnu/release/spoticord /app/aarch64

# Runtime stage
FROM debian:bookworm-slim

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

# TLS + Postgres dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev libssl-dev ca-certificates

# Copy binaries from builder
COPY --from=builder /app/x86_64 /tmp/x86_64
COPY --from=builder /app/aarch64 /tmp/aarch64

# Select correct binary for architecture
RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        cp /tmp/x86_64 /usr/local/bin/spoticord; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        cp /tmp/aarch64 /usr/local/bin/spoticord; \
    fi

# Clean temp binaries
RUN rm -rvf /tmp/x86_64 /tmp/aarch64

ENTRYPOINT ["/usr/local/bin/spoticord"]
