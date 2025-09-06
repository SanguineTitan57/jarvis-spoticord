# Runtime stage
FROM debian:bookworm-slim

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

# TLS + Postgres runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl1.1 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

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
RUN rm -rf /tmp/x86_64 /tmp/aarch64

ENTRYPOINT ["/usr/local/bin/spoticord"]
