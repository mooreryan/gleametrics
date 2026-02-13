import gleam/dynamic/decode
import gleam/json
import gleam/list
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import shared

pub fn main(downloads_json_string: String) {
  let app =
    lustre.application(fn(_) { init(downloads_json_string) }, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// Model ---------------------------------------------------------------------

type Model {
  Model(hex_packages: List(shared.HexPackageOutput))
}

fn init(downloads_json_string: String) -> #(Model, effect.Effect(Msg)) {
  let hex_packages = parse_download_json(downloads_json_string)

  #(
    Model(hex_packages: hex_packages),
    effect.from(fn(dispatch) { dispatch(UserLoadedPage) }),
  )
}

fn parse_download_json(json_string: String) {
  let result =
    json.parse(json_string, decode.list(shared.hex_package_output_decoder()))
  case result {
    Ok(packages) -> packages
    Error(value) -> panic as "failed to parse package info"
  }
}

fn package_downloads_plot(
  entries: List(shared.HexPackageOutput),
  title title: String,
) -> json.Json {
  json.object([
    #("$schema", json.string("https://vega.github.io/schema/vega-lite/v6.json")),
    #("title", json.string(title)),
    #("description", json.string("A lovely chart of package downloads")),
    #("width", json.string("container")),
    #("height", json.string("container")),
    #(
      "config",
      json.object([
        #(
          "title",
          json.object([
            #("fontSize", json.int(20)),
          ]),
        ),
        #(
          "axis",
          json.object([
            #("titleFontSize", json.int(16)),
            #("labelFontSize", json.int(14)),
          ]),
        ),
      ]),
    ),
    #(
      "data",
      json.object([
        #(
          "values",
          json.array(from: entries, of: shared.hex_package_output_to_json),
        ),
      ]),
    ),
    #("mark", json.string("bar")),
    #(
      "encoding",
      json.object([
        #(
          "y",
          json.object([
            // This must match with the field name in the type
            #("field", json.string("name")),
            #("type", json.string("nominal")),
            #("sort", json.string("-x")),
            #("axis", json.object([#("title", json.bool(False))])),
          ]),
        ),
        #(
          "x",
          json.object([
            // This must match with the field name in the type
            #("field", json.string("downloads.recent")),
            #("type", json.string("quantitative")),
            #(
              "axis",
              json.object([#("title", json.string("Recent Downloads"))]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}

// Update --------------------------------------------------------------------

type Msg {
  UserLoadedPage
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserLoadedPage -> #(
      model,
      effect.from(fn(_) {
        model.hex_packages
        |> package_downloads_plot(title: "Total Package Downloads")
        |> embed_plot
      }),
    )
  }
}

@external(javascript, "./ui_ffi.mjs", "vega_embed")
fn vega_embed(id: String, vega_lite_spec: json.Json) -> Nil

fn embed_plot(vega_lite_spec: json.Json) -> Nil {
  vega_embed("#plot", vega_lite_spec)
}

// View ----------------------------------------------------------------------

fn view(_model: Model) -> Element(Msg) {
  html.div([], [
    html.h1([attribute.class("text-2xl pb-2")], [html.text("Gleametrics")]),
    html.h2([attribute.class("text-xl pb-2")], [html.text("Package Downloads")]),
    html.div(
      [
        attribute.class(
          "flex justify-center bg-base-300 shadow-md w-xl pl-2 pt-2 pr-4 pb-1",
        ),
      ],
      [
        html.div(
          [
            attribute.id("plot"),
            // The paddings are to even out the vega chart
            // attribute.class("w-full min-h-48"),
            attribute.class("w-full h-5000"),
          ],
          [],
        ),
      ],
    ),
  ])
}
