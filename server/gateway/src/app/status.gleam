import app/clock
import app/request_id
import app/transport.{type Transport}
import config/config.{type Config}
import config/routing.{type Upstream}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type Check {
  Check(
    upstream: String,
    up: Bool,
    status: Option(Int),
    duration_ms: Int,
    boot_time: Option(String),
    api_version: Option(String),
  )
}

pub fn check_all(
  transport: Transport,
  upstreams: List(Upstream),
  incoming: Request(a),
  timeout_ms: Int,
) -> List(Check) {
  let results = process.new_subject()
  let started = clock.monotonic_ms()
  let workers =
    list.map(upstreams, fn(upstream) {
      process.start(linked: False, running: fn() {
        process.send(results, check(transport, upstream, incoming, timeout_ms))
      })
    })

  let checks =
    collect(results, list.length(upstreams), started + timeout_ms, [])
  list.each(workers, process.kill)
  drain(results)

  list.map(upstreams, fn(upstream) {
    list.find(checks, fn(check) { check.upstream == upstream.name })
    |> result.unwrap(Check(
      upstream: upstream.name,
      up: False,
      status: None,
      duration_ms: clock.monotonic_ms() - started,
      boot_time: None,
      api_version: None,
    ))
  })
}

pub fn to_json(config: Config, checks: List(Check)) -> Json {
  json.object([
    #(
      "gateway",
      json.object([
        #("boot_time", json.string(config.boot_time)),
        #("api_version", json.string(config.api_version)),
      ]),
    ),
    #(
      "upstreams",
      json.object(
        list.map(checks, fn(check) { #(check.upstream, check_to_json(check)) }),
      ),
    ),
  ])
}

fn check(
  transport: Transport,
  upstream: Upstream,
  incoming: Request(a),
  timeout_ms: Int,
) -> Check {
  let req =
    routing.upstream_request(upstream, ["health"])
    |> request_id.propagate(incoming)
  let started = clock.monotonic_ms()
  let response = transport(req, timeout_ms)
  let duration_ms = clock.monotonic_ms() - started
  case response {
    Ok(response) -> {
      let #(boot_time, api_version) =
        json.parse_bits(response.body, version_decoder())
        |> result.unwrap(#(None, None))
      Check(
        upstream: upstream.name,
        up: response.status >= 200 && response.status < 300,
        status: Some(response.status),
        duration_ms: duration_ms,
        boot_time: boot_time,
        api_version: api_version,
      )
    }
    Error(_) ->
      Check(
        upstream: upstream.name,
        up: False,
        status: None,
        duration_ms: duration_ms,
        boot_time: None,
        api_version: None,
      )
  }
}

fn collect(
  results: Subject(Check),
  remaining: Int,
  deadline: Int,
  acc: List(Check),
) -> List(Check) {
  let wait = deadline - clock.monotonic_ms()
  case remaining > 0 && wait > 0 {
    False -> acc
    True ->
      case process.receive(results, wait) {
        Ok(check) -> collect(results, remaining - 1, deadline, [check, ..acc])
        Error(Nil) -> acc
      }
  }
}

/// A worker can finish between the deadline and being killed. Its result must
/// not stay behind in the mailbox of the connection process, which lives on
/// across keep-alive requests.
fn drain(results: Subject(Check)) -> Nil {
  case process.receive(results, 0) {
    Ok(_) -> drain(results)
    Error(Nil) -> Nil
  }
}

fn check_to_json(check: Check) -> Json {
  let version =
    [
      option.map(check.boot_time, fn(value) {
        #("boot_time", json.string(value))
      }),
      option.map(check.api_version, fn(value) {
        #("api_version", json.string(value))
      }),
    ]
    |> option.values
  json.object([
    #("up", json.bool(check.up)),
    #("status", json.nullable(check.status, json.int)),
    #("duration_ms", json.int(check.duration_ms)),
    ..version
  ])
}

fn version_decoder() -> decode.Decoder(#(Option(String), Option(String))) {
  use boot_time <- decode.optional_field(
    "boot_time",
    None,
    decode.optional(decode.string),
  )
  use api_version <- decode.optional_field(
    "api_version",
    None,
    decode.optional(decode.string),
  )
  decode.success(#(boot_time, api_version))
}
