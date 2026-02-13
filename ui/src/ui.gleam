import gleam/int
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// Model ---------------------------------------------------------------------

type Model =
  Int

fn init(_) -> Model {
  0
}

// Update --------------------------------------------------------------------

type Msg {
  UserClickedIncrement
  UserClickedDecrement
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    UserClickedIncrement -> model + 1
    UserClickedDecrement -> model - 1
  }
}

// View ----------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let count = int.to_string(model)

  html.div([], [
    html.button([attribute.class("btn"), event.on_click(UserClickedDecrement)], [
      html.text("-"),
    ]),
    html.p([attribute.class("text-2xl")], [
      html.text("Count: "),
      html.text(count),
    ]),
    html.button([attribute.class("btn"), event.on_click(UserClickedIncrement)], [
      html.text("+"),
    ]),
  ])
}
