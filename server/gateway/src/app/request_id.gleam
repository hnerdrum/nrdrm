import gleam/bit_array
import gleam/http/request.{type Request}
import wisp

pub const header = "x-request-id"

pub fn from_request(req: Request(a)) -> String {
  case request.get_header(req, header) {
    Ok(id) ->
      case is_valid(id) {
        True -> id
        False -> generate()
      }
    Error(Nil) -> generate()
  }
}

/// 1 to 64 characters of `[A-Za-z0-9._-]`.
pub fn is_valid(id: String) -> Bool {
  let bits = bit_array.from_string(id)
  let size = bit_array.byte_size(bits)
  size >= 1 && size <= 64 && allowed_bytes(bits)
}

fn allowed_bytes(bits: BitArray) -> Bool {
  case bits {
    <<>> -> True
    <<byte, rest:bytes>>
      if byte >= 0x30
      && byte <= 0x39
      || byte >= 0x41
      && byte <= 0x5A
      || byte >= 0x61
      && byte <= 0x7A
      || byte == 0x2D
      || byte == 0x2E
      || byte == 0x5F
    -> allowed_bytes(rest)
    _ -> False
  }
}

fn generate() -> String {
  wisp.random_string(16)
}

pub fn propagate(to: Request(b), from: Request(a)) -> Request(b) {
  case request.get_header(from, header) {
    Ok(id) -> request.set_header(to, header, id)
    Error(Nil) -> to
  }
}
