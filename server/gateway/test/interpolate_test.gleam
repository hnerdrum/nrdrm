import config/interpolate.{interpolate}
import gleeunit/should

fn env(name: String) -> Result(String, Nil) {
  case name {
    "HOST" -> Ok("recipes.test")
    "PORT" -> Ok("8000")
    "EMPTY" -> Ok("")
    _ -> Error(Nil)
  }
}

pub fn text_without_variables_is_unchanged_test() {
  interpolate("http://recipes.test", env)
  |> should.equal(Ok("http://recipes.test"))
}

pub fn every_variable_is_replaced_test() {
  interpolate("http://${HOST}:${PORT}/api", env)
  |> should.equal(Ok("http://recipes.test:8000/api"))
}

pub fn every_unset_or_empty_variable_is_reported_test() {
  interpolate("http://${MISSING}:${EMPTY}/${HOST}", env)
  |> should.equal(
    Error([
      "environment variable MISSING is not set",
      "environment variable EMPTY is not set",
    ]),
  )
}

pub fn unterminated_variable_is_reported_test() {
  interpolate("http://${HOST", env)
  |> should.equal(Error(["unterminated \"${\""]))
}
