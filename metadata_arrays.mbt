// C3D array dimensions are bytes. LABELS2/SCALE2 etc extend a 255-entry
// channel family; they must be concatenated in numeric (not lexical) order.

///|
fn array_name(base : String, segment : Int32) -> String {
  if segment == 1 {
    base
  } else {
    base + segment.to_string()
  }
}

///|
fn metadata_strings(
  m : Metadata,
  group : String,
  base : String,
) -> Array[String] raise C3dError {
  let out = []
  for segment in 1..<=258 {
    match m.find(group, array_name(base, segment)) {
      None => break
      Some(p) =>
        for x in p.strings() {
          out.push(x)
        }
    }
  }
  out
}

///|
fn metadata_numbers(
  m : Metadata,
  group : String,
  base : String,
) -> Array[Double] raise C3dError {
  let out = []
  for segment in 1..<=258 {
    match m.find(group, array_name(base, segment)) {
      None => break
      Some(p) =>
        for x in p.numbers() {
          out.push(x)
        }
    }
  }
  out
}

///|
fn counter_in(
  m : Metadata,
  group : String,
  name : String,
  default : Double,
) -> Double raise C3dError {
  let x = scalar(m, group, name, default)
  match m.find(group, name) {
    Some(p) if p.element_size == 2 && x < 0.0 => x + 65536.0
    _ => x
  }
}

///|
fn add_text_array(
  out : Array[Parameter],
  group : String,
  base : String,
  values : Array[String],
) -> Unit raise C3dError {
  let chunks = ((values.length() + 254) / 255).max(1)
  for segment in 0..<chunks {
    let start = segment * 255
    let count = (values.length() - start).min(255)
    out.push(
      text_parameter(
        group,
        array_name(base, segment + 1),
        Array::makei(count, i => values[start + i]),
      ),
    )
  }
}

///|
fn add_number_array(
  out : Array[Parameter],
  group : String,
  base : String,
  values : Array[Double],
  integer : Bool,
  processor : Int32,
) -> Unit raise C3dError {
  let chunks = ((values.length() + 254) / 255).max(1)
  for segment in 0..<chunks {
    let start = segment * 255
    let count = (values.length() - start).min(255)
    let p = number_parameter(
      group,
      array_name(base, segment + 1),
      Array::makei(count, i => values[start + i]),
      integer,
      processor~,
    )
    // Per-channel calibration is an array even for one channel.
    out.push({ ..p, dimensions: [count], })
  }
}

///|
fn regenerated_parameter(group : String, name : String) -> Bool {
  if group == "TRIAL" {
    return name == "ACTUAL_START_FIELD" || name == "ACTUAL_END_FIELD"
  }
  let bases = if group == "POINT" {
    [
      "USED", "FRAMES", "LONG_FRAMES", "DATA_START", "SCALE", "RATE", "LABELS", "DESCRIPTIONS",
      "UNITS",
    ]
  } else if group == "ANALOG" {
    [
      "USED", "SCALE", "OFFSET", "GEN_SCALE", "RATE", "LABELS", "DESCRIPTIONS", "UNITS",
      "FORMAT", "BITS",
    ]
  } else {
    []
  }
  for base in bases {
    if name == base {
      return true
    }
    for segment in 2..<=258 {
      if name == array_name(base, segment) {
        return true
      }
    }
  }
  false
}
