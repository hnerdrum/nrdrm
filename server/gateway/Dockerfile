FROM ghcr.io/gleam-lang/gleam:v1.0.0-erlang-alpine

# Add project code
COPY . /app

# Compile the project
RUN cd /app \
  && gleam export erlang-shipment

# Run the server
WORKDIR /app
ENTRYPOINT ["/app/build/erlang-shipment/entrypoint.sh"]
CMD ["run"]