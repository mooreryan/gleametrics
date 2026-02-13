import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared

pub fn main(downloads_json_string: String) {
  let app =
    lustre.application(fn(_) { init(downloads_json_string) }, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// Model ---------------------------------------------------------------------

type Model {
  Model(hex_packages: List(shared.HexPackage), current_plot: Plot)
}

fn init(downloads_json_string: String) -> #(Model, effect.Effect(Msg)) {
  let hex_packages = parse_download_json(downloads_json_string)

  #(
    Model(hex_packages: hex_packages, current_plot: TotalDownloadsPlot),
    effect.from(fn(dispatch) { dispatch(UserLoadedPage) }),
  )
}

fn parse_download_json(json_string: String) {
  let result =
    json.parse(json_string, decode.list(shared.hex_package_decoder()))
  case result {
    Ok(packages) -> packages
    Error(value) -> panic as "failed to parse package info"
  }
}

type Plot {
  TotalDownloadsPlot
  LifetimeDownloadRatePlot
  PackageAgePlot
}

fn plot_title(plot: Plot) -> String {
  case plot {
    TotalDownloadsPlot -> "Total Downloads"
    LifetimeDownloadRatePlot -> "Lifetime Download Rate"
    PackageAgePlot -> "Package Age"
  }
}

fn plot_axis_title(plot: Plot) -> String {
  case plot {
    TotalDownloadsPlot -> "Total Downloads"
    LifetimeDownloadRatePlot -> "Lifetime Download Rate (per day)"
    PackageAgePlot -> "Package Age (days)"
  }
}

fn plot_attribute_value(plot: Plot) -> String {
  case plot {
    TotalDownloadsPlot -> "total-downloads"
    LifetimeDownloadRatePlot -> "lifetime-download-rate"
    PackageAgePlot -> "package-age"
  }
}

fn plot_from_attribute_value(attribute_value: String) -> Result(Plot, String) {
  case attribute_value {
    "total-downloads" -> Ok(TotalDownloadsPlot)
    "lifetime-download-rate" -> Ok(LifetimeDownloadRatePlot)
    "package-age" -> Ok(PackageAgePlot)
    _ -> Error("Invalid plot attribute value")
  }
}

fn plot_html_option(
  plot: Plot,
  currently_selected_plot currently_selected_plot: Plot,
) -> Element(a) {
  html.option(
    [
      attribute.value(plot_attribute_value(plot)),
      attribute.selected(plot == currently_selected_plot),
    ],
    plot_title(plot),
  )
}

type LiftetimeDownloadRate {
  LifetimeDownloadRate(package_name: String, downloads_per_day: Float)
}

fn lifetime_download_rate_plot_point_to_json(
  lifetime_download_rate_plot_point: LiftetimeDownloadRate,
) -> json.Json {
  let LifetimeDownloadRate(package_name:, downloads_per_day:) =
    lifetime_download_rate_plot_point
  json.object([
    #("package_name", json.string(package_name)),
    #("downloads_per_day", json.float(downloads_per_day)),
  ])
}

fn lifetime_download_rate_plot_point(package: shared.HexPackage) {
  let assert Ok(inserted_at) = package.inserted_at |> timestamp.parse_rfc3339

  let download_day =
    timestamp.from_calendar(
      date: calendar.Date(2026, calendar.February, 12),
      time: calendar.TimeOfDay(00, 00, 00, 0),
      offset: calendar.utc_offset,
    )

  let package_age = timestamp.difference(inserted_at, download_day)
  let age_seconds = duration.to_seconds(package_age)
  // Absolute unit of day, not civil time or anything like that
  let age_in_days = age_seconds /. 60.0 /. 60.0 /. 24.0

  // For very recent packages, this age_in_days may be weird, so set it to 1.
  let age_in_days = float.max(1.0, age_in_days)

  let downloads_per_day =
    { int.to_float(package.downloads.all) /. age_in_days }
    |> float.to_precision(2)

  LifetimeDownloadRate(
    package_name: package.name,
    downloads_per_day: downloads_per_day,
  )
}

fn lifetime_download_rate_plot(
  entries: List(LiftetimeDownloadRate),
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
          json.array(
            from: entries,
            of: lifetime_download_rate_plot_point_to_json,
          ),
        ),
      ]),
    ),
    #(
      "mark",
      json.object([#("type", json.string("bar")), #("tooltip", json.bool(True))]),
    ),
    #(
      "encoding",
      json.object([
        #(
          "y",
          json.object([
            // This must match with the field name in the type
            #("field", json.string("package_name")),
            #("type", json.string("nominal")),
            #("sort", json.string("-x")),
            #("axis", json.object([#("title", json.bool(False))])),
          ]),
        ),
        #(
          "x",
          json.object([
            // This must match with the field name in the type
            #("field", json.string("downloads_per_day")),
            #("type", json.string("quantitative")),
            #(
              "axis",
              json.object([
                #(
                  "title",
                  json.string(plot_axis_title(LifetimeDownloadRatePlot)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}

type PackageAge {
  PackageAge(name: String, days: Int)
}

fn package_age_to_json(package_age: PackageAge) -> json.Json {
  let PackageAge(name:, days:) = package_age
  json.object([
    #("name", json.string(name)),
    #("days", json.int(days)),
  ])
}

fn package_age_plot_point(package: shared.HexPackage) {
  let assert Ok(inserted_at) = package.inserted_at |> timestamp.parse_rfc3339

  let download_day =
    timestamp.from_calendar(
      date: calendar.Date(2026, calendar.February, 12),
      time: calendar.TimeOfDay(00, 00, 00, 0),
      offset: calendar.utc_offset,
    )

  let package_age = timestamp.difference(inserted_at, download_day)
  let age_seconds = duration.to_seconds(package_age)
  // Absolute unit of day, not civil time or anything like that
  let age_in_days = age_seconds /. 60.0 /. 60.0 /. 24.0

  // For very recent packages, this age_in_days may be weird, so set it to 1.
  let age_in_days = float.max(1.0, age_in_days) |> float.round

  PackageAge(name: package.name, days: age_in_days)
}

fn package_age_plot(entries: List(PackageAge), title title: String) -> json.Json {
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
        #("values", json.array(from: entries, of: package_age_to_json)),
      ]),
    ),
    #(
      "mark",
      json.object([#("type", json.string("bar")), #("tooltip", json.bool(True))]),
    ),
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
            #("field", json.string("days")),
            #("type", json.string("quantitative")),
            #(
              "axis",
              json.object([
                #("title", json.string(plot_axis_title(PackageAgePlot))),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}

fn total_downloads_plot(
  entries: List(shared.HexPackage),
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
        #("values", json.array(from: entries, of: shared.hex_package_to_json)),
      ]),
    ),
    #(
      "mark",
      json.object([#("type", json.string("bar")), #("tooltip", json.bool(True))]),
    ),
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
              json.object([
                #("title", json.string(plot_axis_title(TotalDownloadsPlot))),
              ]),
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
  UserChangedPlot(plot_attribute_value: String)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserLoadedPage -> #(model, embed_total_downloads_plot(model.hex_packages))

    UserChangedPlot(plot_attribute_value) -> {
      // TODO: handle the error!
      let assert Ok(plot) = plot_from_attribute_value(plot_attribute_value)

      let model = Model(..model, current_plot: plot)

      let effect = case plot {
        TotalDownloadsPlot -> embed_total_downloads_plot(model.hex_packages)

        LifetimeDownloadRatePlot ->
          embed_lifetime_download_rate_plot(model.hex_packages)

        PackageAgePlot -> embed_package_age_plot(model.hex_packages)
      }

      #(model, effect)
    }
  }
}

fn embed_total_downloads_plot(
  hex_packages: List(shared.HexPackage),
) -> effect.Effect(a) {
  effect.from(fn(_) {
    hex_packages
    |> total_downloads_plot(title: plot_title(TotalDownloadsPlot))
    |> embed_plot
  })
}

fn embed_lifetime_download_rate_plot(
  hex_packages: List(shared.HexPackage),
) -> effect.Effect(a) {
  use _ <- effect.from
  hex_packages
  |> list.map(lifetime_download_rate_plot_point)
  |> lifetime_download_rate_plot(title: plot_title(LifetimeDownloadRatePlot))
  |> embed_plot
}

fn embed_package_age_plot(
  hex_packages: List(shared.HexPackage),
) -> effect.Effect(a) {
  use _ <- effect.from
  hex_packages
  |> list.map(package_age_plot_point)
  |> package_age_plot(title: plot_title(PackageAgePlot))
  |> embed_plot
}

@external(javascript, "./ui_ffi.mjs", "vega_embed")
fn vega_embed(id: String, vega_lite_spec: json.Json) -> Nil

fn embed_plot(vega_lite_spec: json.Json) -> Nil {
  vega_embed("#plot", vega_lite_spec)
}

// View ----------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("py-2")], [
    html.h1([attribute.class("text-2xl pb-2")], [html.text("Gleametrics")]),
    html.div([attribute.class("pb-2")], [
      html.fieldset([attribute.class("fieldset")], [
        html.label([attribute.for("plot-select"), attribute.class("label")], [
          html.text("Select Plot"),
        ]),
        html.select(
          [
            attribute.id("plot-select"),
            attribute.name("plot-select"),
            attribute.class("select"),
            event.on_input(UserChangedPlot),
          ],
          [
            plot_html_option(
              TotalDownloadsPlot,
              currently_selected_plot: model.current_plot,
            ),
            plot_html_option(
              LifetimeDownloadRatePlot,
              currently_selected_plot: model.current_plot,
            ),
            plot_html_option(
              PackageAgePlot,
              currently_selected_plot: model.current_plot,
            ),
          ],
        ),
      ]),
    ]),
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
