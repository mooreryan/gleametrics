import gleam/int
import gleam/json
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// Model ---------------------------------------------------------------------

type Model {
  Model(package_downloads: List(Package))
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(
    Model(package_downloads: [
      Package(name: "gleam_stdlib", downloads: 1_079_600),
      Package(name: "gleam_erlang", downloads: 527_107),
      Package(name: "gleeunit", downloads: 746_727),
      Package(name: "gleam_otp", downloads: 405_715),
    ]),
    effect.from(fn(dispatch) { dispatch(UserLoadedPage) }),
  )
}

type Package {
  Package(name: String, downloads: Int)
}

fn package_downloads_to_json(package_downloads: Package) -> json.Json {
  let Package(name:, downloads:) = package_downloads
  json.object([
    #("Name", json.string(name)),
    #("Downloads", json.int(downloads)),
  ])
}

fn package_downloads_plot(
  entries: List(Package),
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
        #("values", json.array(from: entries, of: package_downloads_to_json)),
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
            #("field", json.string("Name")),
            #("type", json.string("nominal")),
            #("sort", json.string("-x")),
            #("axis", json.object([#("title", json.bool(False))])),
          ]),
        ),
        #(
          "x",
          json.object([
            // This must match with the field name in the type
            #("field", json.string("Downloads")),
            #("type", json.string("quantitative")),
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
        model.package_downloads
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
            attribute.class("w-full min-h-48"),
          ],
          [],
        ),
      ],
    ),
  ])
}
