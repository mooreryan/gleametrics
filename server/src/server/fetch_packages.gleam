import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import shared

pub fn main() -> Nil {
  let assert Ok(stdlib_package) = fetch_stdlib() as "failed to fetch stdlib"
  let assert Ok(hex_packages) = fetch_packages() as "failed to fetch packages"

  let gleam_packages = [stdlib_package, ..hex_packages]

  gleam_packages
  |> json.array(shared.hex_package_to_json)
  |> json.to_string()
  |> io.println

  Nil
}

fn fetch_stdlib() -> Result(shared.HexPackage, json.DecodeError) {
  process.sleep(100)
  io.println_error("fetching stdlib")

  let assert Ok(request) =
    request.to("https://hex.pm/api/packages/gleam_stdlib")
    as "failed to build request"

  let assert Ok(hex_api_key) = envoy.get("HEX_API_KEY") as "HEX_API_KEY not set"

  let request =
    request
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("authorization", hex_api_key)

  let assert Ok(body) = {
    use response <- result.map(httpc.send(request))
    assert response.status == 200
    response.body
  }
    as "the api request failed"

  shared.decode_hex_package(body)
}

fn fetch_packages() {
  do_fetch_packages(1, [])
}

fn do_fetch_packages(
  page: Int,
  packages: List(List(shared.HexPackage)),
) -> Result(List(shared.HexPackage), json.DecodeError) {
  process.sleep(100)
  io.println_error("fetching page " <> int.to_string(page))

  let assert Ok(request) = request.to("https://hex.pm/api/packages")
    as "failed to build request"

  let assert Ok(hex_api_key) = envoy.get("HEX_API_KEY") as "HEX_API_KEY not set"

  let request =
    request
    |> request.set_query([
      #("search", "depends:hexpm:gleam_stdlib"),
      #("sort", "recent_downloads"),
      // NOTE: you will know that you have hit the last page when you get an empty json array back (`[]`)
      #("page", int.to_string(page)),
    ])
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("authorization", hex_api_key)

  let assert Ok(body) = {
    use response <- result.map(httpc.send(request))
    assert response.status == 200
    response.body
  }
    as "the api request failed"

  case shared.decode_hex_packages(body) {
    Ok([]) -> packages |> list.reverse |> list.flatten |> Ok
    Ok(new_packages) -> do_fetch_packages(page + 1, [new_packages, ..packages])
    Error(error) as x -> {
      io.println_error(body)
      error |> echo
      x
    }
  }
}
