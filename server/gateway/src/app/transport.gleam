import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/string

pub type Transport =
  fn(Request(String)) -> Result(Response(String), TransportError)

pub type TransportError {
  FailedToConnect(detail: String)
  InvalidUtf8Response
}

pub fn new() -> Transport {
  send
}

fn send(req: Request(String)) -> Result(Response(String), TransportError) {
  case httpc.send(req) {
    Ok(response) -> Ok(response)
    Error(httpc.FailedToConnect(ip4, ip6)) ->
      Error(FailedToConnect(string.inspect(#(ip4, ip6))))
    Error(httpc.InvalidUtf8Response) -> Error(InvalidUtf8Response)
  }
}
