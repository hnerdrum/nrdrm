import gleam/dynamic.{type Dynamic}
import wisp

pub fn configure() -> Nil {
  wisp.configure_logger()
  use_json_formatter()
}

@external(erlang, "gateway_log_ffi", "configure")
fn use_json_formatter() -> Nil

@external(erlang, "gateway_log_ffi", "info")
pub fn info(msg: String, fields: List(#(String, Dynamic))) -> Nil

@external(erlang, "gateway_log_ffi", "set_request_id")
pub fn set_request_id(id: String) -> Nil

@external(erlang, "gateway_log_ffi", "clear_request_id")
pub fn clear_request_id() -> Nil
