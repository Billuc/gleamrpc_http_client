# gleamrpc_http_client

[![Package Version](https://img.shields.io/hexpm/v/gleamrpc_http_client)](https://hex.pm/packages/gleamrpc_http_client)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamrpc_http_client/)

**HTTP client for GleamRPC**

Call your GleamRPC procedures via HTTP. Should be used with [gleamrpc_http_server](https://hexdocs.pm/gleamrpc_http_server/).

Query data is sent in the request query while the Mutation's data is sent in the body in Json.

## Installation

```sh
gleam add gleamrpc_http_client@1
```

## Usage

```gleam
import gleamrpc
import gleamrpc/http/client.{http_client}

pub fn main() {
  use data <- my_procedure
    |> gleamrpc.with_client(http_client("http://localhost:3000"))
    |> gleamrpc.call(params)

  // ...
}
```

Further documentation can be found at <https://hexdocs.pm/gleamrpc_http_client>.

## Features

- Support for Javascript and Erlang targets
- Send Queries via HTTP Get requests
- Send Mutations via HTTP Post requests 

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
