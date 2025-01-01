import convert/http/query
import convert/json as cjson
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleamrpc

@target(erlang)
import convert
@target(javascript)
import gleam/dynamic
@target(javascript)
import gleam/fetch
@target(javascript)
import gleam/http/response
@target(erlang)
import gleam/httpc
@target(javascript)
import gleam/javascript/promise

pub type GleamRpcHttpClientError {
  IncorrectURIError(uri: String)
  InvalidResponseError
  ConnectionError(uri: String, reason: String)
  JsonDecodeError(error: json.DecodeError)
  InvalidJsonError
  UnableToReadBodyError
}

pub fn http_client(
  uri: String,
) -> gleamrpc.ProcedureClient(a, b, GleamRpcHttpClientError) {
  gleamrpc.ProcedureClient(call(uri))
}

@target(javascript)
fn call(
  uri: String,
) -> fn(
  gleamrpc.Procedure(a, b),
  a,
  fn(Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError))) -> Nil,
) ->
  Nil {
  let request = request.to(uri)

  case request {
    Error(_) -> fn(
      _proc: gleamrpc.Procedure(a, b),
      _params: a,
      callback: fn(Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError))) ->
        Nil,
    ) {
      callback(Error(gleamrpc.GleamRPCError(IncorrectURIError(uri))))
    }
    Ok(req) -> fn(
      proc: gleamrpc.Procedure(a, b),
      params: a,
      callback: fn(Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError))) ->
        Nil,
    ) {
      {
        use body_result <- promise.map(
          req
          |> configure_request(proc, params)
          |> fetch.send()
          |> promise.try_await(fetch.read_json_body),
        )

        handle_fetched_body(body_result, uri, proc)
        |> callback
      }
      Nil
    }
  }
}

@target(javascript)
fn handle_fetched_body(
  body_result: Result(response.Response(dynamic.Dynamic), fetch.FetchError),
  uri: String,
  procedure: gleamrpc.Procedure(a, b),
) -> Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError)) {
  use res <- result.try(
    body_result
    |> result.map_error(fetch_to_gleamrpc_error(_, uri))
    |> result.map_error(gleamrpc.GleamRPCError),
  )

  res.body
  |> cjson.json_decode(procedure.return_type)
  |> result.map_error(json.UnexpectedFormat)
  |> result.map_error(JsonDecodeError)
  |> result.map_error(gleamrpc.GleamRPCError)
}

@target(javascript)
fn fetch_to_gleamrpc_error(
  error: fetch.FetchError,
  uri: String,
) -> GleamRpcHttpClientError {
  case error {
    fetch.InvalidJsonBody -> InvalidJsonError
    fetch.NetworkError(reason) -> ConnectionError(uri, reason)
    fetch.UnableToReadBody -> UnableToReadBodyError
  }
}

@target(erlang)
fn call(
  uri: String,
) -> fn(
  gleamrpc.Procedure(a, b),
  a,
  fn(Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError))) -> Nil,
) ->
  Nil {
  let request = request.to(uri)

  case request {
    Error(_) -> fn(
      _proc: gleamrpc.Procedure(a, b),
      _params: a,
      callback: fn(Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError))) ->
        Nil,
    ) {
      callback(Error(gleamrpc.GleamRPCError(IncorrectURIError(uri))))
    }
    Ok(req) -> fn(
      proc: gleamrpc.Procedure(a, b),
      params: a,
      callback: fn(Result(b, gleamrpc.GleamRPCError(GleamRpcHttpClientError))) ->
        Nil,
    ) {
      req
      |> configure_request(proc, params)
      |> httpc.send()
      |> result.map_error(fn(err) { httpc_to_gleamrpc_error(err, uri) })
      |> result.then(fn(res) { decode_result(res.body, proc.return_type) })
      |> result.map_error(gleamrpc.GleamRPCError)
      |> callback
    }
  }
}

@target(erlang)
fn httpc_to_gleamrpc_error(
  error: httpc.HttpError,
  uri: String,
) -> GleamRpcHttpClientError {
  case error {
    httpc.FailedToConnect(_, _) ->
      ConnectionError(uri, "Httpc failed to connect")
    httpc.InvalidUtf8Response -> InvalidResponseError
  }
}

fn configure_request(
  req: request.Request(_),
  procedure: gleamrpc.Procedure(a, b),
  params: a,
) -> request.Request(_) {
  case procedure.type_ {
    gleamrpc.Query -> configure_query(req, procedure, params)
    gleamrpc.Mutation -> configure_mutation(req, procedure, params)
  }
}

fn configure_query(
  req: request.Request(_),
  procedure: gleamrpc.Procedure(a, b),
  params: a,
) -> request.Request(_) {
  req
  |> request.set_method(http.Get)
  |> request.set_path(generate_path(procedure))
  |> request.set_query(params |> query.encode(procedure.params_type))
}

fn configure_mutation(
  req: request.Request(_),
  procedure: gleamrpc.Procedure(a, b),
  params: a,
) -> request.Request(String) {
  req
  |> request.set_method(http.Post)
  |> request.set_path(generate_path(procedure))
  |> request.set_body(
    cjson.json_encode(params, procedure.params_type) |> json.to_string,
  )
}

fn generate_path(procedure: gleamrpc.Procedure(a, b)) -> String {
  "/api/gleamRPC/"
  <> router_paths(procedure.router, []) |> string.join("/")
  <> "/"
  <> procedure.name
}

fn router_paths(
  router: option.Option(gleamrpc.Router),
  paths: List(String),
) -> List(String) {
  case router {
    option.None -> paths
    option.Some(router) -> router_paths(router.parent, [router.name, ..paths])
  }
}

@target(erlang)
fn decode_result(
  json_data: String,
  result_converter: convert.Converter(return),
) -> Result(return, GleamRpcHttpClientError) {
  json_data
  |> json.decode(cjson.json_decode(result_converter))
  |> result.map_error(JsonDecodeError)
}
