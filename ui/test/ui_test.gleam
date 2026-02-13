import gleeunit
import ui

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn format_with_commas__1_test() {
  assert ui.format_with_commas(1) == "1"
}

pub fn format_with_commas__2_test() {
  assert ui.format_with_commas(12) == "12"
}

pub fn format_with_commas__3_test() {
  assert ui.format_with_commas(123) == "123"
}

pub fn format_with_commas__4_test() {
  assert ui.format_with_commas(1234) == "1,234"
}

pub fn format_with_commas__5_test() {
  assert ui.format_with_commas(12_345) == "12,345"
}

pub fn format_with_commas__6_test() {
  assert ui.format_with_commas(123_456) == "123,456"
}

pub fn format_with_commas__7_test() {
  assert ui.format_with_commas(1_234_567) == "1,234,567"
}

pub fn format_with_commas__8_test() {
  assert ui.format_with_commas(-1) == "-1"
}

pub fn format_with_commas__9_test() {
  assert ui.format_with_commas(-12) == "-12"
}

pub fn format_with_commas__10_test() {
  assert ui.format_with_commas(-123) == "-123"
}

pub fn format_with_commas__11_test() {
  assert ui.format_with_commas(-1234) == "-1,234"
}
