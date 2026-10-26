import app/context.{type Context}
import app/forward
import app/route.{type Match}
import app/transport.{type Transport}
import config/path_pattern
import config/service.{type Scheme, type Service, Bearer, Cookie}
import gleam/bit_array
import gleam/dynamic/decode
import gleam/http.{type Method}
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import wisp.{type Request}

pub type TokenValidation {
  TokenValidation(valid: Bool)
}

pub type Introspection {
  Introspection(
    active: Bool,
    audience: Option(String),
    client_name: Option(String),
  )
}

pub fn auth_middleware(
  req: wisp.Request,
  ctx: Context,
  route: Match,
  handler: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case required_scheme(route, req.method) {
    Error(_) -> handler(req)
    Ok(Cookie) -> {
      case validate_auth(ctx.transport, ctx.identity_service, req) {
        TokenValidation(valid: True) -> handler(req)
        TokenValidation(valid: False) -> unauthorized()
      }
    }
    Ok(Bearer(audience)) -> {
      case introspect(ctx.transport, ctx.identity_service, req) {
        Ok(introspection) ->
          case bearer_permitted(introspection, audience) {
            True -> handler(attach_client(req, introspection.client_name))
            False -> unauthorized()
          }
        Error(_) -> unauthorized()
      }
    }
  }
}

pub fn required_scheme(route: Match, method: Method) -> Result(Scheme, Nil) {
  list.find(route.service.security.auth, fn(auth) {
    path_pattern.matches(auth.path, route.path)
    && list.contains(auth.methods, method)
  })
  |> result.map(fn(auth) { auth.scheme })
}

pub fn identity_path(scheme: Scheme) -> List(String) {
  case scheme {
    Cookie -> ["validate-token"]
    Bearer(_) -> ["oauth", "introspect"]
  }
}

pub fn bearer_permitted(
  introspection: Introspection,
  audience: String,
) -> Bool {
  introspection.active && introspection.audience == Some(audience)
}

/// `x-nrdrm-*` headers carry identity the gateway vouches for, so callers
/// must never be able to supply them.
pub fn strip_reserved_headers(req: Request) -> Request {
  let headers =
    list.filter(req.headers, fn(header) {
      !string.starts_with(string.lowercase(header.0), "x-nrdrm-")
    })
  request.Request(..req, headers: headers)
}

pub fn attach_client(req: Request, client_name: Option(String)) -> Request {
  case client_name {
    Some(name) -> request.set_header(req, "x-nrdrm-client", name)
    None -> req
  }
}

fn unauthorized() -> wisp.Response {
  wisp.string_body(wisp.response(401), "Unauthorized")
}

fn validate_auth(
  transport: Transport,
  identity_service: Service,
  incoming_request: Request,
) -> TokenValidation {
  let req =
    service.upstream_request(identity_service, identity_path(Cookie))
    |> forward.set_request_headers(incoming_request, identity_service)
  case transport(req) {
    Ok(response) -> {
      case parse_validation_response(response) {
        Ok(token_validation) -> token_validation
        Error(_) -> TokenValidation(valid: False)
      }
    }
    Error(_) -> TokenValidation(valid: False)
  }
}

fn introspect(
  transport: Transport,
  identity_service: Service,
  incoming_request: Request,
) -> Result(Introspection, Nil) {
  use token <- result.try(bearer_token(incoming_request))
  let body =
    json.object([#("token", json.string(token))])
    |> json.to_string
    |> bit_array.from_string
  let req =
    service.upstream_request(identity_service, identity_path(Bearer("")))
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)
  use response <- result.try(result.replace_error(transport(req), Nil))
  parse_introspection(response)
}

fn bearer_token(req: Request) -> Result(String, Nil) {
  use header <- result.try(request.get_header(req, "authorization"))
  use #(scheme, token) <- result.try(string.split_once(string.trim(header), " "))
  case string.lowercase(scheme), string.trim(token) {
    "bearer", "" -> Error(Nil)
    "bearer", token -> Ok(token)
    _, _ -> Error(Nil)
  }
}

fn parse_validation_response(
  response: response.Response(BitArray),
) -> Result(TokenValidation, String) {
  case response.status {
    200 -> {
      case json.parse_bits(response.body, token_validation_decoder()) {
        Ok(validation) -> Ok(validation)
        Error(_) -> Error("Failed to parse JSON into token validator type")
      }
    }
    _ ->
      Error(
        "Validation service returned status " <> int.to_string(response.status),
      )
  }
}

fn parse_introspection(
  response: response.Response(BitArray),
) -> Result(Introspection, Nil) {
  case response.status {
    200 ->
      result.replace_error(
        json.parse_bits(response.body, introspection_decoder()),
        Nil,
      )
    _ -> Error(Nil)
  }
}

fn token_validation_decoder() -> decode.Decoder(TokenValidation) {
  use valid <- decode.field("valid", decode.bool)
  decode.success(TokenValidation(valid))
}

fn introspection_decoder() -> decode.Decoder(Introspection) {
  use active <- decode.field("active", decode.bool)
  use audience <- decode.optional_field(
    "aud",
    None,
    decode.optional(decode.string),
  )
  use client_name <- decode.optional_field(
    "client_name",
    None,
    decode.optional(decode.string),
  )
  decode.success(Introspection(active, audience, client_name))
}
