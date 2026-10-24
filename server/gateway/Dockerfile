FROM ghcr.io/gleam-lang/gleam:v1.19.2-erlang-alpine

COPY . /app

RUN cd /app \
  && gleam export erlang-shipment

WORKDIR /app

ENTRYPOINT ["/app/build/erlang-shipment/entrypoint.sh"]

EXPOSE 8080

CMD ["run"]
