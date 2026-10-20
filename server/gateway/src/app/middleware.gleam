import app/context.{type Context}
import app/forward
import config/service.{type Scheme, type Service, Bearer, Cookie}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import utils
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
  handler: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case wisp.path_segments(req) {
    [service_name, ..path_segments] -> {
      case service.find(ctx.services, service_name) {
        Ok(service) -> {
          let path = string.join(path_segments, "/")
          case
            required_scheme(service, path, http.method_to_string(req.method))
          {
            Error(_) -> handler(req)
            Ok(Cookie) -> {
              case validate_auth(ctx.identity_service, req) {
                TokenValidation(valid: True) -> handler(req)
                TokenValidation(valid: False) -> unauthorized()
              }
            }
            Ok(Bearer(audience)) -> {
              case introspect(ctx.identity_service, req) {
                Ok(introspection) ->
                  case bearer_permitted(introspection, audience) {
                    True ->
                      handler(attach_client(req, introspection.client_name))
                    False -> unauthorized()
                  }
                Error(_) -> unauthorized()
              }
            }
          }
        }
        Error(_) -> handler(req)
      }
    }
    _ -> handler(req)
  }
}

pub fn required_scheme(
  service: Service,
  path: String,
  method: String,
) -> Result(Scheme, Nil) {
  list.find(service.security.auth, fn(auth) {
    utils.glob_match(auth.path, path, "/")
    && list.contains(auth.methods, string.lowercase(method))
  })
  |> result.map(fn(auth) { auth.scheme })
}

pub fn identity_path(scheme: Scheme) -> String {
  case scheme {
    Cookie -> "validate-token"
    Bearer(_) -> "oauth/introspect"
  }
}

pub fn bearer_permitted(introspection: Introspection, audience: String) -> Bool {
  introspection.active && introspection.audience == Some(audience)
}

pub fn attach_client(req: Request, client_name: Option(String)) -> Request {
  let headers =
    list.filter(req.headers, fn(header) { header.0 != "x-nrdrm-client" })
  let req = request.Request(..req, headers: headers)
  case client_name {
    Some(name) -> request.set_header(req, "x-nrdrm-client", name)
    None -> req
  }
}

fn unauthorized() -> wisp.Response {
  wisp.string_body(wisp.response(401), "Unauthorized")
}

fn validate_auth(
  identity_service: Service,
  incoming_request: Request,
) -> TokenValidation {
  let url = service.create_url(identity_service, identity_path(Cookie))
  case request.to(url) {
    Ok(req) -> {
      case
        httpc.send(forward.set_request_headers(
          req,
          incoming_request,
          identity_service,
        ))
      {
        Ok(response) -> {
          case parse_validation_response(response) {
            Ok(token_validation) -> token_validation
            Error(_) -> TokenValidation(valid: False)
          }
        }
        Error(_) -> TokenValidation(valid: False)
      }
    }
    Error(_) -> TokenValidation(valid: False)
  }
}

fn introspect(
  identity_service: Service,
  incoming_request: Request,
) -> Result(Introspection, Nil) {
  use token <- result.try(bearer_token(incoming_request))
  let url = service.create_url(identity_service, identity_path(Bearer("")))
  use req <- result.try(result.replace_error(request.to(url), Nil))
  let body =
    json.object([#("token", json.string(token))])
    |> json.to_string
  let req =
    request.set_method(req, http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)
  use response <- result.try(result.replace_error(httpc.send(req), Nil))
  parse_introspection(response)
}

fn bearer_token(req: Request) -> Result(String, Nil) {
  use header <- result.try(
    list.find(req.headers, fn(header) {
      string.lowercase(header.0) == "authorization"
    })
    |> result.map(fn(header) { header.1 }),
  )
  let prefix = string.slice(string.lowercase(string.trim(header)), 0, 7)
  case prefix == "bearer " {
    False -> Error(Nil)
    True ->
      case string.trim(string.drop_start(header, 7)) {
        "" -> Error(Nil)
        token -> Ok(token)
      }
  }
}

fn parse_validation_response(
  response: response.Response(String),
) -> Result(TokenValidation, String) {
  case response.status {
    200 -> {
      case json.parse(response.body, token_validation_decoder()) {
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
  response: response.Response(String),
) -> Result(Introspection, Nil) {
  case response.status {
    200 ->
      result.replace_error(
        json.parse(response.body, introspection_decoder()),
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
