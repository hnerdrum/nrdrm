import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/string

pub type Transport =
  fn(Request(BitArray)) -> Result(Response(BitArray), TransportError)

pub type TransportError {
  FailedToConnect(detail: String)
  Timeout
  InvalidResponse
}

pub fn new(timeout_ms timeout_ms: Int) -> Transport {
  let config = httpc.configure() |> httpc.timeout(timeout_ms)
  fn(req) { send(config, req) }
}

fn send(
  config: httpc.Configuration,
  req: Request(BitArray),
) -> Result(Response(BitArray), TransportError) {
  case httpc.dispatch_bits(config, req) {
    Ok(response) -> Ok(response)
    Error(httpc.FailedToConnect(ip4, ip6)) ->
      Error(FailedToConnect(string.inspect(#(ip4, ip6))))
    Error(httpc.ResponseTimeout) -> Error(Timeout)
    Error(httpc.InvalidUtf8Response) -> Error(InvalidResponse)
  }
}
