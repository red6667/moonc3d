// Strict validation is separate from tolerant legacy ingestion. All emitted
// files pass this gate, including files with no points or no analog channels.

///|
fn required_parameter(
  m : Metadata,
  group : String,
  name : String,
  kind : Int32,
) -> Parameter raise C3dError {
  let p = m
    .find(group, name)
    .unwrap_or_else(() => {
      raise Invalid("missing required parameter: " + group + ":" + name)
    })
  require(
    p.element_size == kind,
    "wrong required parameter type: " + group + ":" + name,
  )
  p
}

///|
fn required_scalar(
  m : Metadata,
  group : String,
  name : String,
  kind : Int32,
) -> Unit raise C3dError {
  let p = required_parameter(m, group, name, kind)
  require(
    p.numbers().length() == 1,
    "required scalar shape: " + group + ":" + name,
  )
}

///|
fn required_text_array(
  m : Metadata,
  group : String,
  name : String,
  count : Int32,
) -> Unit raise C3dError {
  let p = required_parameter(m, group, name, -1)
  require(
    p.dimensions.length() >= 1 &&
    metadata_strings(m, group, name).length() >= count,
    "required text array too short: " + group + ":" + name,
  )
}

///|
fn check_force_platform(m : Metadata, channels : Int32) -> Unit raise C3dError {
  if !m.groups.iter().any(g => g.name == "FORCE_PLATFORM") {
    return
  }
  required_scalar(m, "FORCE_PLATFORM", "USED", 2)
  let n = counter_in(m, "FORCE_PLATFORM", "USED", 0.0)
  require(
    n >= 0.0 && n <= 255.0 && n == n.trunc(),
    "invalid force platform count",
  )
  if n == 0.0 {
    return
  }
  let count = n.to_int()
  let types = required_parameter(m, "FORCE_PLATFORM", "TYPE", 2).numbers()
  require(
    types.length() == count && types.iter().all(x => x > 0.0),
    "invalid force platform TYPE",
  )
  let corners = required_parameter(m, "FORCE_PLATFORM", "CORNERS", 4)
  require(
    corners.dimensions == [3, 4, count],
    "invalid force platform CORNERS shape",
  )
  let origin = required_parameter(m, "FORCE_PLATFORM", "ORIGIN", 4)
  require(
    origin.dimensions == [3, count],
    "invalid force platform ORIGIN shape",
  )
  let channel = required_parameter(m, "FORCE_PLATFORM", "CHANNEL", 2)
  require(
    channel.dimensions.length() == 2 &&
    channel.dimensions[1] == count &&
    channel.dimensions[0] > 0,
    "invalid force platform CHANNEL shape",
  )
  for x in channel.numbers() {
    require(
      x >= 0.0 && x <= channels.to_double(),
      "force platform analog index out of range",
    )
  }
  let zero = required_parameter(m, "FORCE_PLATFORM", "ZERO", 2).numbers()
  require(zero.length() == 2, "invalid force platform ZERO shape")
  if types.iter().any(x => x == 4.0) {
    let matrix = required_parameter(m, "FORCE_PLATFORM", "CAL_MATRIX", 4)
    require(
      matrix.dimensions == [6, 6, count],
      "type 4 requires force calibration matrix",
    )
  }
}

///|
fn check_event_parameters(m : Metadata) -> Unit raise C3dError {
  if !m.groups.iter().any(g => g.name == "EVENT") {
    return
  }
  required_scalar(m, "EVENT", "USED", 2)
  let count = counter_in(m, "EVENT", "USED", 0.0).to_int()
  if count == 0 {
    return
  }
  required_text_array(m, "EVENT", "LABELS", count)
  let times = required_parameter(m, "EVENT", "TIMES", 4)
  require(times.dimensions == [2, count], "invalid EVENT:TIMES shape")
  for x in times.numbers() {
    require(x >= 0.0, "negative event time component")
  }
}

///|
fn check_required(l : Layout) -> Unit raise C3dError {
  let m = l.metadata
  validate_metadata(m, Limits::default())
  for name in ["USED", "DATA_START"] {
    required_scalar(m, "POINT", name, 2)
  }
  for name in ["SCALE", "RATE"] {
    required_scalar(m, "POINT", name, 4)
  }
  let frames = m
    .find("POINT", "FRAMES")
    .unwrap_or_else(() => raise Invalid("missing POINT:FRAMES"))
  require(
    (frames.element_size == 2 || frames.element_size == 4) &&
    frames.numbers().length() == 1,
    "POINT:FRAMES must be an integer or floating scalar",
  )
  if l.labels.length() > 0 {
    for name in ["LABELS", "DESCRIPTIONS"] {
      required_text_array(m, "POINT", name, l.labels.length())
    }
    required_text_array(m, "POINT", "UNITS", 1)
  }
  required_scalar(m, "ANALOG", "USED", 2)
  if l.analog_labels.length() > 0 {
    for name in ["RATE", "GEN_SCALE"] {
      required_scalar(m, "ANALOG", name, 4)
    }
    for (name, kind) in [("SCALE", 4), ("OFFSET", 2)] {
      let _ = required_parameter(m, "ANALOG", name, kind)
      let values = metadata_numbers(m, "ANALOG", name)
      require(
        values.length() >= l.analog_labels.length(),
        "missing per-channel calibration values",
      )
    }
    for name in ["LABELS", "DESCRIPTIONS", "UNITS"] {
      required_text_array(m, "ANALOG", name, l.analog_labels.length())
    }
  }
  match m.find("ANALOG", "BITS") {
    None => ()
    Some(_) => {
      required_scalar(m, "ANALOG", "BITS", 2)
      let bits = scalar(m, "ANALOG", "BITS", 16.0)
      require(bits >= 1.0 && bits <= 16.0, "invalid analog ADC resolution")
    }
  }
  check_force_platform(m, l.analog_labels.length())
  check_event_parameters(m)
}

///|
pub fn validate_file(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Unit raise C3dError {
  let layout = inspect(bytes, limits~)
  check_required(layout)
  let _ = read(bytes, limits~)
}
