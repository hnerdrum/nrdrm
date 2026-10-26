type TimeUnit {
  Millisecond
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: TimeUnit) -> Int

/// Only differences between two readings mean anything.
pub fn monotonic_ms() -> Int {
  monotonic_time(Millisecond)
}
