import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/string
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

pub fn main(downloads_json_string: String) -> Nil {
  let app =
    lustre.application(fn(_) { init(downloads_json_string) }, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// Model ---------------------------------------------------------------------

type Model {
  Model(hex_packages_snapshot: shared.HexPackagesSnapshot, current_plot: Plot)
}

fn init(downloads_json_string: String) -> #(Model, effect.Effect(Msg)) {
  let hex_packages_snapshot = parse_download_json(downloads_json_string)

  #(
    Model(
      hex_packages_snapshot: hex_packages_snapshot,
      current_plot: RecentDownloadsPlot,
    ),
    effect.from(fn(dispatch) { dispatch(UserLoadedPage) }),
  )
}

fn parse_download_json(json_string: String) -> shared.HexPackagesSnapshot {
  let result = json.parse(json_string, shared.hex_package_snapshot_decoder())
  case result {
    Ok(packages) -> packages
    Error(value) -> panic as "failed to parse package info"
  }
}

type Plot {
  RecentDownloadsPlot
  TotalDownloadsPlot
  LifetimeDownloadRatePlot
  PackageAgePlot
}

fn plot_title(plot: Plot) -> String {
  case plot {
    RecentDownloadsPlot -> "Recent Downloads"
    TotalDownloadsPlot -> "Total Downloads"
    LifetimeDownloadRatePlot -> "Lifetime Download Rate"
    PackageAgePlot -> "Package Age"
  }
}

fn plot_axis_title(plot: Plot) -> String {
  case plot {
    RecentDownloadsPlot -> "Recent Downloads"
    TotalDownloadsPlot -> "Total Downloads"
    LifetimeDownloadRatePlot -> "Lifetime Download Rate (per day)"
    PackageAgePlot -> "Package Age (days)"
  }
}

fn plot_attribute_value(plot: Plot) -> String {
  case plot {
    RecentDownloadsPlot -> "recent-downloads"
    TotalDownloadsPlot -> "total-downloads"
    LifetimeDownloadRatePlot -> "lifetime-download-rate"
    PackageAgePlot -> "package-age"
  }
}

fn plot_from_attribute_value(attribute_value: String) -> Result(Plot, String) {
  case attribute_value {
    "recent-downloads" -> Ok(RecentDownloadsPlot)
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

fn lifetime_download_rate_plot_point(
  package: shared.HexPackageOut,
) -> LiftetimeDownloadRate {
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
    { int.to_float(package.all_downloads) /. age_in_days }
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

fn package_age_plot_point(package: shared.HexPackageOut) -> PackageAge {
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
  entries: List(shared.HexPackageOut),
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
          json.array(from: entries, of: shared.hex_package_out_to_json),
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
            #("field", json.string("all_downloads")),
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

fn recent_downloads_plot(
  entries: List(shared.HexPackageOut),
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
          json.array(from: entries, of: shared.hex_package_out_to_json),
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
            #("field", json.string("recent_downloads")),
            #("type", json.string("quantitative")),
            #(
              "axis",
              json.object([
                #("title", json.string(plot_axis_title(RecentDownloadsPlot))),
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
    UserLoadedPage -> #(
      model,
      embed_recent_downloads_plot(model.hex_packages_snapshot.packages),
    )

    UserChangedPlot(plot_attribute_value) -> {
      // TODO: handle the error!
      let assert Ok(plot) = plot_from_attribute_value(plot_attribute_value)

      let model = Model(..model, current_plot: plot)

      let effect = case plot {
        RecentDownloadsPlot ->
          embed_recent_downloads_plot(model.hex_packages_snapshot.packages)

        TotalDownloadsPlot ->
          embed_total_downloads_plot(model.hex_packages_snapshot.packages)

        LifetimeDownloadRatePlot ->
          embed_lifetime_download_rate_plot(
            model.hex_packages_snapshot.packages,
          )

        PackageAgePlot ->
          embed_package_age_plot(model.hex_packages_snapshot.packages)
      }

      #(model, effect)
    }
  }
}

fn embed_recent_downloads_plot(
  hex_packages: List(shared.HexPackageOut),
) -> effect.Effect(a) {
  effect.from(fn(_) {
    hex_packages
    |> recent_downloads_plot(title: plot_title(RecentDownloadsPlot))
    |> embed_plot
  })
}

fn embed_total_downloads_plot(
  hex_packages: List(shared.HexPackageOut),
) -> effect.Effect(a) {
  effect.from(fn(_) {
    hex_packages
    |> total_downloads_plot(title: plot_title(TotalDownloadsPlot))
    |> embed_plot
  })
}

fn embed_lifetime_download_rate_plot(
  hex_packages: List(shared.HexPackageOut),
) -> effect.Effect(a) {
  use _ <- effect.from
  hex_packages
  |> list.map(lifetime_download_rate_plot_point)
  |> lifetime_download_rate_plot(title: plot_title(LifetimeDownloadRatePlot))
  |> embed_plot
}

fn embed_package_age_plot(
  hex_packages: List(shared.HexPackageOut),
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
    view_title(),
    view_info(model.hex_packages_snapshot.fetched_at),
    view_stats(model.hex_packages_snapshot),
    view_plot(model.current_plot),
  ])
}

fn view_title() {
  html.h1([attribute.class("text-4xl pb-2 text-bold")], [
    html.text("Gleametrics"),
  ])
}

fn view_info(fetched_at) {
  html.div([], [
    html.p([], [
      html.text("Package download metrics for "),
      html.a([attribute.href("https://gleam.run"), attribute.class("link")], [
        html.text("Gleam"),
      ]),
      html.text("."),
    ]),
    view_data_fetched_on(fetched_at),
  ])
}

fn view_data_fetched_on(fetched_at: String) -> Element(Msg) {
  html.div([], [
    html.p([attribute.class("text-xs opacity-50")], [
      html.text("Data fetched on: " <> data_fetched_at_string(fetched_at)),
    ]),
  ])
}

fn view_stats(hex_packages_snapshot: shared.HexPackagesSnapshot) -> Element(Msg) {
  let total_downloads =
    hex_packages_snapshot.packages
    |> list.fold(
      from: 0,
      with: fn(total_downloads: Int, package: shared.HexPackageOut) {
        total_downloads + package.all_downloads
      },
    )

  let total_packages = hex_packages_snapshot.packages |> list.length

  html.div([attribute.class("stats my-4")], [
    html.div([attribute.class("stat")], [
      html.div([attribute.class("stat-title")], [
        html.text("Packages"),
      ]),
      html.div([attribute.class("stat-value")], [
        html.text(format_with_commas(total_packages)),
      ]),
    ]),
    html.div([attribute.class("stat")], [
      html.div([attribute.class("stat-title")], [html.text("Total Downloads")]),
      html.div([attribute.class("stat-value")], [
        html.text(format_with_commas(total_downloads)),
      ]),
    ]),
  ])
}

@internal
pub fn format_with_commas(n: Int) -> String {
  let str = int.to_string(n)

  case n < 0 {
    True -> "-" <> format_digits(string.drop_start(str, 1))
    False -> format_digits(str)
  }
}

fn format_digits(str: String) -> String {
  str
  |> string.to_graphemes
  |> list.reverse
  |> group_by_threes
  |> list.reverse
  |> string.join("")
}

fn group_by_threes(digits: List(String)) -> List(String) {
  case digits {
    [] | [_] | [_, _] | [_, _, _] -> digits
    [a, b, c, ..rest] -> [a, b, c, ",", ..group_by_threes(rest)]
  }
}

fn view_plot(current_plot: Plot) -> Element(Msg) {
  html.div([], [
    html.div([attribute.class("py-2")], [
      html.fieldset([attribute.class("fieldset")], [
        html.label(
          [attribute.for("plot-select"), attribute.class("label hidden")],
          [
            html.text("Select Plot"),
          ],
        ),
        html.select(
          [
            attribute.id("plot-select"),
            attribute.name("plot-select"),
            attribute.class("select"),
            event.on_input(UserChangedPlot),
          ],
          [
            plot_html_option(
              RecentDownloadsPlot,
              currently_selected_plot: current_plot,
            ),
            plot_html_option(
              TotalDownloadsPlot,
              currently_selected_plot: current_plot,
            ),
            plot_html_option(
              LifetimeDownloadRatePlot,
              currently_selected_plot: current_plot,
            ),
            plot_html_option(
              PackageAgePlot,
              currently_selected_plot: current_plot,
            ),
          ],
        ),
      ]),
    ]),
    html.div(
      [
        // The paddings are to even out the vega chart
        attribute.class(
          "bg-base-300 shadow-md w-sm md:w-md lg:w-2xl pl-2 pt-2 pr-4 pb-1",
        ),
      ],
      [
        html.div(
          [
            attribute.id("plot"),
            // attribute.class("w-full h-5000"),
            attribute.class("w-full h-5000"),
          ],
          [],
        ),
      ],
    ),
  ])
}

fn data_fetched_at_string(timestamp_string: String) -> String {
  let to_string = fn(n) {
    n |> int.to_string |> string.pad_start(to: 2, with: "0")
  }

  case timestamp.parse_rfc3339(timestamp_string) {
    Error(Nil) -> "unknown"
    Ok(ts) -> {
      let x = timestamp.to_calendar(ts, calendar.utc_offset)
      let #(date, _) = x
      let calendar.Date(year:, month:, day:) = date

      int.to_string(year)
      <> "-"
      <> to_string(calendar.month_to_int(month))
      <> "-"
      <> to_string(day)
    }
  }
}
