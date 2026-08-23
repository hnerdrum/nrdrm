FROM haskell:9.2.8 AS build

WORKDIR /usr/src/app

COPY orm/ orm/
COPY orm-codegen/ orm-codegen/
COPY recipes/ recipes/

WORKDIR /usr/src/app/recipes
RUN stack setup --install-ghc && stack build --copy-bins

# Runtime stage
FROM debian:bullseye-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libgmp10 \
    libtinfo6 \
    libpq5 && \
    apt-get clean && \
    # Clean up to reduce image size
    rm -rf /var/lib/apt/lists/*

# /root/.local/bin/* is the default directory where Stack places compiled binaries
COPY --from=build /root/.local/bin/* /usr/local/bin/

COPY --from=build /usr/src/app/recipes/migrations /app/migrations

EXPOSE 8000

CMD ["server-exe"]
