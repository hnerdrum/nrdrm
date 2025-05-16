FROM rust:1.86-slim as builder

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    libpq-dev \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock ./

RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

COPY . .

# Force a rebuild with the real source code by touching a file
RUN touch src/main.rs && cargo build --release

RUN cargo install diesel_cli --no-default-features --features postgres

FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/identity /app/identity
COPY --from=builder /usr/local/cargo/bin/diesel /usr/local/bin/
COPY --from=builder /app/migrations /app/migrations

COPY ./docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/app/docker-entrypoint.sh"]
