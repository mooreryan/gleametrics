import envoy
import gleam/dynamic/decode
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

  // TODO: remove this
  let normalized_downloads =
    list.map(gleam_packages, fn(hex_package) {
      shared.normalize_downloads(
        hex_package.downloads,
        by: stdlib_package.downloads,
      )
    })

  list.zip(gleam_packages, normalized_downloads)
  |> list.map(fn(x) {
    let #(hex_package, normalized_downloads) = x
    shared.HexPackageOutput(
      name: hex_package.name,
      downloads: hex_package.downloads,
      normalized_downloads: normalized_downloads,
      inserted_at: hex_package.inserted_at,
      updated_at: hex_package.updated_at,
    )
  })
  |> json.array(shared.hex_package_output_to_json)
  |> json.to_string()
  |> io.println

  Nil
}

fn fetch_stdlib() -> Result(HexPackage, json.DecodeError) {
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

  decode_hex_package(body)
}

fn fetch_packages() {
  do_fetch_packages(1, [])
}

fn do_fetch_packages(
  page: Int,
  packages: List(List(HexPackage)),
) -> Result(List(HexPackage), json.DecodeError) {
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

  case decode_hex_packages(body) {
    Ok([]) -> packages |> list.reverse |> list.flatten |> Ok
    Ok(new_packages) -> do_fetch_packages(page + 1, [new_packages, ..packages])
    Error(error) as x -> {
      io.println_error(body)
      error |> echo
      x
    }
  }
}

type HexPackage {
  HexPackage(
    name: String,
    downloads: shared.Downloads,
    inserted_at: String,
    updated_at: String,
  )
}

fn hex_package_decoder() -> decode.Decoder(HexPackage) {
  use name <- decode.field("name", decode.string)
  use inserted_at <- decode.field("inserted_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use downloads <- decode.field("downloads", shared.downloads_decoder())
  decode.success(HexPackage(name:, updated_at:, inserted_at:, downloads:))
}

fn hex_packages_decoder() -> decode.Decoder(List(HexPackage)) {
  decode.list(hex_package_decoder())
}

fn decode_hex_packages(
  json: String,
) -> Result(List(HexPackage), json.DecodeError) {
  json.parse(json, hex_packages_decoder())
}

fn decode_hex_package(json: String) -> Result(HexPackage, json.DecodeError) {
  json.parse(json, hex_package_decoder())
}
