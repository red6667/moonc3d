// Metadata, not the historical raw-data frame range in the header, defines
// the stored frame count. TRIAL word pairs are base 2^16, low word first.

///|
fn frame_integer(value : Double) -> Int32 raise C3dError {
  require(
    finite(value) &&
    value >= 1.0 &&
    value <= 2147483647.0 &&
    value == value.trunc(),
    "invalid frame count",
  )
  value.to_int()
}

///|
fn trial_field(m : Metadata, name : String) -> Int32? raise C3dError {
  match m.find("TRIAL", name) {
    None => None
    Some(p) => {
      require(
        p.element_size == 2 && p.dimensions == [2] && p.data.length() == 4,
        "invalid TRIAL frame word pair",
      )
      let c = Cursor::new(p.data, 0, 4, p.big_endian)
      let low = c.u16()
      let high = c.u16()
      require(high <= 32767, "TRIAL frame exceeds signed 32-bit range")
      Some(low | (high << 16))
    }
  }
}

///|
fn verify_extended_frames(m : Metadata, h : Header) -> Header raise C3dError {
  let start = trial_field(m, "ACTUAL_START_FIELD")
  let end = trial_field(m, "ACTUAL_END_FIELD")
  require((start is Some(_)) == (end is Some(_)), "incomplete TRIAL frame pair")
  let first = start.unwrap_or(h.first_frame)
  let fallback = if h.last_frame >= h.first_frame {
    (h.last_frame - h.first_frame + 1).to_double()
  } else {
    0.0
  }
  let declared = counter(m, "FRAMES", fallback)
  let trial_count = match (start, end) {
    (Some(a), Some(b)) => {
      require(b >= a && b - a < 2147483647, "invalid TRIAL frame range")
      Some(b - a + 1)
    }
    _ => None
  }
  let long_count = match m.find("POINT", "LONG_FRAMES") {
    None => None
    Some(p) => {
      require(p.element_size == 4, "LONG_FRAMES must be floating-point")
      let a = p.numbers()
      require(a.length() == 1, "LONG_FRAMES must be scalar")
      Some(frame_integer(a[0]))
    }
  }
  let count = if declared == 65535.0 {
    long_count.unwrap_or(trial_count.unwrap_or(65535))
  } else {
    frame_integer(declared)
  }
  match long_count {
    Some(n) => require(n == count, "conflicting LONG_FRAMES")
    None => ()
  }
  match trial_count {
    Some(n) => require(n == count, "conflicting TRIAL frame count")
    None => ()
  }
  require(count - 1 <= 2147483647 - first, "last frame number overflow")
  { ..h, first_frame: first, last_frame: first + count - 1, }
}

///|
fn frame_pair(name : String, value : Int32) -> Parameter raise C3dError {
  number_parameter(
    "TRIAL",
    name,
    [(value & 65535).to_double(), (value >> 16).to_double()],
    true,
  )
}
