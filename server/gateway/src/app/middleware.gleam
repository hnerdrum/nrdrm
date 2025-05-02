import gleam/string
import gleam/list
import gleam/int
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/dynamic
import gleam/httpc
import wisp.{type Request}
import config/service.{type Service}
import app/context.{type Context}
import app/forward.{set_request_headers}
import utils

pub type TokenValidation {
  TokenValidation(valid: Bool)
}

pub fn auth_middleware(req: wisp.Request, ctx: Context, handler: fn(wisp.Request) -> wisp.Response) -> wisp.Response {
  case wisp.path_segments(req) {
    [service_name, ..path_segments] -> {
      case service.find(ctx.services, service_name) {
        Ok(service) -> {
          let path = string.join(path_segments, "/")
          case should_validate_auth(service, path, req) {
            True -> {
              case validate_auth(ctx.identity_service, req) {
                TokenValidation(valid: True) -> handler(req)
                TokenValidation(valid: False) -> wisp.string_body(wisp.response(401), "Unauthorized") 
              }
            }
            False -> handler(req)
          }
        }
        Error(_) -> handler(req)
      }
    }

    _ -> handler(req)
  }
}

fn validate_auth(identity_service: Service, incoming_request: Request) -> TokenValidation {
  let url = service.create_url(identity_service, "validate-token")
  case request.to(url) {
    Ok(req) -> {
      case httpc.send(set_request_headers(req, incoming_request, identity_service)) {
        Ok(response) -> {
          case parse_validation_response(response) {
            Ok(token_validation) -> {
              token_validation
            }
            Error(_) -> TokenValidation(valid: False)
          }
        }
        Error(_) -> TokenValidation(valid: False)
      }
    }
    Error(_) -> {
      TokenValidation(valid: False)
    }
  }
}

fn parse_validation_response(response: response.Response(String)) -> Result(TokenValidation, String) {
  case response.status {
    200 -> {
      case json.decode(response.body, token_validation_decoder()) {
        Ok(validation) -> Ok(validation)
        Error(_) -> Error("Failed to parse JSON into token validator type")
      }
    }
    _ -> Error("Validation service returned status " <> int.to_string(response.status))
  }
}
  
fn token_validation_decoder() -> dynamic.Decoder(TokenValidation) {
  dynamic.decode1(
    TokenValidation,
    dynamic.field("valid", dynamic.bool),
  )
}

fn should_validate_auth(service: Service, path: String, request: Request) -> Bool {
  let method = http.method_to_string(request.method)

  list.any(service.security.auth, fn(auth) {
    utils.glob_match(auth.path, path, "/") &&
    list.contains(auth.methods, string.lowercase(method))
  })
}
