import app/clock
import app/status.{type Check, Check}
import app/transport
import fixture
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import wisp/testing

fn check_all(
  respond: fixture.Responder,
  timeout_ms: Int,
) -> #(List(Check), Int) {
  let started = clock.monotonic_ms()
  let checks =
    status.check_all(
      fn(req, _timeout_ms) { respond(req) },
      [fixture.recipes(), fixture.identity(), fixture.agents()],
      testing.get("/_gateway/status", []),
      timeout_ms,
    )
  #(
    list.map(checks, fn(check) { Check(..check, duration_ms: 0) }),
    clock.monotonic_ms() - started,
  )
}

pub fn any_2xx_counts_as_up_test() {
  let #(checks, _) =
    check_all(
      fn(req: Request(BitArray)) {
        case req.host {
          "recipes.test" ->
            fixture.json(200, "{\"boot_time\":\"t0\",\"api_version\":\"v1\"}")
          "identity.test" -> fixture.json(204, "")
          _ -> fixture.json(200, "{\"status\":\"ok\"}")
        }
      },
      1000,
    )

  checks
  |> should.equal([
    Check("recipes", True, Some(200), 0, Some("t0"), Some("v1")),
    Check("identity", True, Some(204), 0, None, None),
    Check("agents", True, Some(200), 0, None, None),
  ])
}

pub fn non_2xx_and_unreachable_upstreams_are_down_test() {
  let #(checks, _) =
    check_all(
      fn(req: Request(BitArray)) {
        case req.host {
          "recipes.test" -> fixture.json(503, "{\"boot_time\":\"t0\"}")
          "identity.test" -> Error(transport.FailedToConnect("econnrefused"))
          _ -> Error(transport.Timeout)
        }
      },
      1000,
    )

  checks
  |> should.equal([
    Check("recipes", False, Some(503), 0, Some("t0"), None),
    Check("identity", False, None, 0, None, None),
    Check("agents", False, None, 0, None, None),
  ])
}

pub fn slow_upstream_counts_as_down_without_holding_up_the_rest_test() {
  let #(checks, elapsed_ms) =
    check_all(
      fn(req: Request(BitArray)) {
        case req.host {
          "agents.test" -> process.sleep(2000)
          _ -> Nil
        }
        fixture.json(200, "{}")
      },
      100,
    )

  checks
  |> should.equal([
    Check("recipes", True, Some(200), 0, None, None),
    Check("identity", True, Some(200), 0, None, None),
    Check("agents", False, None, 0, None, None),
  ])
  { elapsed_ms < 1000 } |> should.be_true
}

pub fn upstreams_are_checked_concurrently_test() {
  let #(checks, elapsed_ms) =
    check_all(
      fn(_) {
        process.sleep(150)
        fixture.json(200, "{}")
      },
      1000,
    )

  list.all(checks, fn(check) { check.up }) |> should.be_true
  { elapsed_ms < 400 } |> should.be_true
}
