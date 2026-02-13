import gleam/dynamic/decode
import gleam/int
import gleam/json

pub type HexPackagesSnapshot {
  HexPackagesSnapshot(fetched_at: String, packages: List(HexPackage))
}

pub fn hex_package_snapshot_decoder() -> decode.Decoder(HexPackagesSnapshot) {
  use fetched_at <- decode.field("fetched_at", decode.string)
  use packages <- decode.field("packages", decode.list(hex_package_decoder()))
  decode.success(HexPackagesSnapshot(fetched_at:, packages:))
}

pub fn hex_package_snapshot_to_json(
  hex_package_snapshot: HexPackagesSnapshot,
) -> json.Json {
  let HexPackagesSnapshot(fetched_at:, packages:) = hex_package_snapshot
  json.object([
    #("fetched_at", json.string(fetched_at)),
    #("packages", json.array(packages, hex_package_to_json)),
  ])
}

pub type HexPackage {
  HexPackage(
    name: String,
    downloads: Downloads,
    inserted_at: String,
    updated_at: String,
  )
}

pub fn hex_package_to_json(hex_package: HexPackage) -> json.Json {
  let HexPackage(name:, downloads:, inserted_at:, updated_at:) = hex_package
  json.object([
    #("name", json.string(name)),
    #("downloads", downloads_to_json(downloads)),
    #("inserted_at", json.string(inserted_at)),
    #("updated_at", json.string(updated_at)),
  ])
}

pub fn hex_package_decoder() -> decode.Decoder(HexPackage) {
  use name <- decode.field("name", decode.string)
  use inserted_at <- decode.field("inserted_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use downloads <- decode.field("downloads", downloads_decoder())
  decode.success(HexPackage(name:, updated_at:, inserted_at:, downloads:))
}

fn hex_packages_decoder() -> decode.Decoder(List(HexPackage)) {
  decode.list(hex_package_decoder())
}

pub fn decode_hex_packages(
  json: String,
) -> Result(List(HexPackage), json.DecodeError) {
  json.parse(json, hex_packages_decoder())
}

pub fn decode_hex_package(json: String) -> Result(HexPackage, json.DecodeError) {
  json.parse(json, hex_package_decoder())
}

pub type Downloads {
  Downloads(all: Int, recent: Int)
}

// If a package has no downloads, then this will be an empty map, so we use
// optional fields and give things a zero download count.
pub fn downloads_decoder() -> decode.Decoder(Downloads) {
  use all <- decode.optional_field("all", 0, decode.int)
  use recent <- decode.optional_field("recent", 0, decode.int)
  decode.success(Downloads(all:, recent:))
}

pub fn downloads_to_json(downloads: Downloads) -> json.Json {
  let Downloads(all:, recent:) = downloads
  json.object([
    #("all", json.int(all)),
    #("recent", json.int(recent)),
  ])
}

pub type NormalizedDownloads {
  NormalizedDownloads(all: Float, recent: Float)
}

// Unlike the downloads decoder, this one doesn't have to worry about optional
// data.
pub fn normalized_downloads_decoder() -> decode.Decoder(NormalizedDownloads) {
  use all <- decode.field("all", decode.float)
  use recent <- decode.field("recent", decode.float)
  decode.success(NormalizedDownloads(all:, recent:))
}

pub fn normalized_downloads_to_json(
  normalized_downloads: NormalizedDownloads,
) -> json.Json {
  let NormalizedDownloads(all:, recent:) = normalized_downloads
  json.object([
    #("all", json.float(all)),
    #("recent", json.float(recent)),
  ])
}

pub fn normalize_downloads(
  downloads: Downloads,
  by by: Downloads,
) -> NormalizedDownloads {
  NormalizedDownloads(
    all: int.to_float(downloads.all) /. int.to_float(by.all),
    recent: int.to_float(downloads.recent) /. int.to_float(by.recent),
  )
}
