import config/interpolate
import config/path_pattern.{type PathPattern}
import gleam/dynamic/decode.{type Decoder}
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import simplifile

pub type Routing {
  Routing(identity: Upstream, upstreams: List(Upstream), routes: List(Route))
}

pub type Upstream {
  Upstream(name: String, base_request: Request(BitArray), timeout_ms: Int)
}

pub type Route {
  Route(
    prefix: String,
    upstream: Upstream,
    request_headers: Set(String),
    response_headers: Set(String),
    rules: List(Rule),
  )
}

pub type Rule {
  Rule(path: PathPattern, methods: List(Method), auth: Auth)
}

pub type Auth {
  Public
  Session
  Bearer(audience: String)
}

const reserved_prefixes = ["_gateway"]

pub fn upstream_request(
  upstream: Upstream,
  path: List(String),
) -> Request(BitArray) {
  let base = upstream.base_request
  request.Request(..base, path: base.path <> "/" <> string.join(path, "/"))
}

pub fn load(
  path: String,
  lookup: fn(String) -> Result(String, Nil),
) -> Result(Routing, List(String)) {
  case simplifile.read(path) {
    Ok(contents) ->
      parse(contents, lookup)
      |> result.map_error(list.map(_, fn(error) { path <> ": " <> error }))
    Error(error) ->
      Error([path <> ": cannot read file: " <> simplifile.describe_error(error)])
  }
}

pub fn parse(
  json_string: String,
  lookup: fn(String) -> Result(String, Nil),
) -> Result(Routing, List(String)) {
  case json.parse(json_string, file_decoder()) {
    Ok(file) -> build(file, lookup)
    Error(error) -> Error(describe_decode_error(error))
  }
}

pub fn parse_base_url(url: String) -> Result(Request(BitArray), Nil) {
  case request.to(url) {
    Ok(request.Request(query: None, ..) as req) ->
      Ok(
        request.Request(..req, path: trim_trailing_slash(req.path))
        |> request.set_body(<<>>),
      )
    _ -> Error(Nil)
  }
}

fn trim_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") {
    True -> trim_trailing_slash(string.drop_end(path, 1))
    False -> path
  }
}

type File {
  File(
    identity_upstream: String,
    upstreams: List(UpstreamSpec),
    routes: List(RouteSpec),
  )
}

type UpstreamSpec {
  UpstreamSpec(name: String, url: String, timeout_ms: Int)
}

type RouteSpec {
  RouteSpec(
    prefix: String,
    upstream: String,
    request_headers: Set(String),
    response_headers: Set(String),
    rules: List(Rule),
  )
}

fn build(
  file: File,
  lookup: fn(String) -> Result(String, Nil),
) -> Result(Routing, List(String)) {
  let built = list.map(file.upstreams, build_upstream(_, lookup))
  let upstreams = list.filter_map(built, fn(upstream) { upstream })
  let names = list.map(file.upstreams, fn(spec) { spec.name })

  // An upstream that failed to build has already been reported, so routes
  // that point at it add no further errors.
  let resolve = fn(owner: String, name: String) {
    case list.find(upstreams, fn(upstream) { upstream.name == name }) {
      Ok(upstream) -> Ok(upstream)
      Error(Nil) ->
        case list.contains(names, name) {
          True -> Error([])
          False -> Error([owner <> ": unknown upstream \"" <> name <> "\""])
        }
    }
  }

  let identity = resolve("identity_upstream", file.identity_upstream)
  let routes =
    list.map(file.routes, fn(spec) {
      use upstream <- result.map(resolve(
        "route \"" <> spec.prefix <> "\"",
        spec.upstream,
      ))
      Route(
        prefix: spec.prefix,
        upstream: upstream,
        request_headers: spec.request_headers,
        response_headers: spec.response_headers,
        rules: spec.rules,
      )
    })

  let errors =
    list.flatten([
      list.flat_map(built, errors_of),
      duplicates(names)
        |> list.map(fn(name) {
          "upstream \"" <> name <> "\" is defined more than once"
        }),
      duplicates(list.map(file.routes, fn(spec) { spec.prefix }))
        |> list.map(fn(prefix) {
          "route \"" <> prefix <> "\" is defined more than once"
        }),
      errors_of(identity),
      list.flat_map(routes, errors_of),
    ])

  case errors, identity {
    [], Ok(identity) ->
      Ok(Routing(
        identity: identity,
        upstreams: upstreams,
        routes: list.filter_map(routes, fn(route) { route }),
      ))
    _, _ -> Error(errors)
  }
}

fn build_upstream(
  spec: UpstreamSpec,
  lookup: fn(String) -> Result(String, Nil),
) -> Result(Upstream, List(String)) {
  let owner = "upstream \"" <> spec.name <> "\""
  use url <- result.try(
    interpolate.interpolate(spec.url, lookup)
    |> result.map_error(list.map(_, fn(error) { owner <> ": " <> error })),
  )
  case parse_base_url(url) {
    Ok(base_request) -> Ok(Upstream(spec.name, base_request, spec.timeout_ms))
    Error(Nil) ->
      Error([
        owner
        <> ": url \""
        <> url
        <> "\" is not an absolute http(s) URL without a query string",
      ])
  }
}

fn errors_of(result: Result(a, List(String))) -> List(String) {
  case result {
    Ok(_) -> []
    Error(errors) -> errors
  }
}

fn duplicates(values: List(String)) -> List(String) {
  let #(_, repeated) =
    list.fold(values, #(set.new(), set.new()), fn(acc, value) {
      let #(seen, repeated) = acc
      case set.contains(seen, value) {
        True -> #(seen, set.insert(repeated, value))
        False -> #(set.insert(seen, value), repeated)
      }
    })
  set.to_list(repeated) |> list.sort(string.compare)
}

fn describe_decode_error(error: json.DecodeError) -> List(String) {
  case error {
    json.UnableToDecode(errors) ->
      list.map(errors, fn(error) {
        string.join(error.path, ".")
        <> ": expected "
        <> error.expected
        <> ", found "
        <> error.found
      })
    _ -> ["invalid JSON: " <> string.inspect(error)]
  }
}

fn file_decoder() -> Decoder(File) {
  use identity_upstream <- decode.field("identity_upstream", decode.string)
  use upstreams <- decode.field("upstreams", decode.list(upstream_decoder()))
  use routes <- decode.field("routes", decode.list(route_decoder()))
  decode.success(File(identity_upstream, upstreams, routes))
}

fn upstream_decoder() -> Decoder(UpstreamSpec) {
  use name <- decode.field("name", decode.string)
  use url <- decode.field("url", decode.string)
  use timeout_ms <- decode.field("timeout_ms", positive_int_decoder())
  decode.success(UpstreamSpec(name, url, timeout_ms))
}

fn route_decoder() -> Decoder(RouteSpec) {
  use prefix <- decode.field("prefix", prefix_decoder())
  use upstream <- decode.field("upstream", decode.string)
  use request_headers <- decode.optional_field(
    "request_headers",
    set.new(),
    header_set_decoder(),
  )
  use response_headers <- decode.optional_field(
    "response_headers",
    set.new(),
    header_set_decoder(),
  )
  use rules <- decode.field("rules", decode.list(rule_decoder()))
  decode.success(RouteSpec(
    prefix: prefix,
    upstream: upstream,
    request_headers: request_headers,
    response_headers: response_headers,
    rules: rules,
  ))
}

fn rule_decoder() -> Decoder(Rule) {
  use path <- decode.field("path", path_pattern.decoder())
  use methods <- decode.field("methods", decode.list(method_decoder()))
  use auth <- decode.field("auth", auth_decoder())
  decode.success(Rule(path, methods, auth))
}

fn auth_decoder() -> Decoder(Auth) {
  let keyword = {
    use word <- decode.then(decode.string)
    case word {
      "public" -> decode.success(Public)
      "session" -> decode.success(Session)
      _ -> decode.failure(Public, "")
    }
  }
  let bearer = {
    use audience <- decode.subfield(["bearer", "audience"], decode.string)
    case audience {
      "" -> decode.failure(Public, "")
      _ -> decode.success(Bearer(audience))
    }
  }
  decode.one_of(keyword, [bearer])
  |> decode.collapse_errors(
    "\"public\", \"session\" or {\"bearer\": {\"audience\": \"...\"}}",
  )
}

fn prefix_decoder() -> Decoder(String) {
  use prefix <- decode.then(decode.string)
  let single_segment =
    prefix != ""
    && prefix != "."
    && prefix != ".."
    && !string.contains(prefix, "/")
    && !string.contains(prefix, "*")
  case single_segment, list.contains(reserved_prefixes, prefix) {
    False, _ -> decode.failure(prefix, "a single path segment")
    True, True ->
      decode.failure(
        prefix,
        "a prefix other than the reserved \"" <> prefix <> "\"",
      )
    True, False -> decode.success(prefix)
  }
}

fn positive_int_decoder() -> Decoder(Int) {
  use value <- decode.then(decode.int)
  case value > 0 {
    True -> decode.success(value)
    False -> decode.failure(value, "a positive integer")
  }
}

fn header_set_decoder() -> Decoder(Set(String)) {
  decode.list(decode.string)
  |> decode.map(fn(names) { set.from_list(list.map(names, string.lowercase)) })
}

fn method_decoder() -> Decoder(Method) {
  use name <- decode.then(decode.string)
  case http.parse_method(string.uppercase(name)) {
    Ok(http.Other(_)) | Error(Nil) ->
      decode.failure(http.Get, "a standard HTTP method")
    Ok(method) -> decode.success(method)
  }
}
