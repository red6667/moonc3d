///|
pub(all) struct Layout {
  header : Header
  metadata : Metadata
  labels : Array[String]
  analog_labels : Array[String]
  units : String
  analog_scales : Array[Double]
  analog_offsets : Array[Double]
  unsigned_analog : Bool
  frame_bytes : Int32
} derive(Debug, Eq)

///|
fn labels_from(
  m : Metadata,
  group : String,
  count : Int32,
) -> Array[String] raise C3dError {
  match m.find(group, "LABELS") {
    Some(p) => {
      let a = p.strings()
      require(a.length() >= count, "insufficient channel labels")
      let labels = Array::makei(count, i => a[i])
      validate_labels(labels)
      labels
    }
    None => Array::makei(count, i => group + "_" + (i + 1).to_string())
  }
}

///|
fn numeric_vector(
  m : Metadata,
  name : String,
  n : Int32,
  default : Double,
) -> Array[Double] raise C3dError {
  match m.find("ANALOG", name) {
    None => Array::make(n, default)
    Some(p) => {
      let a = p.numbers()
      require(a.length() >= n, "insufficient analog calibration values")
      Array::makei(n, i => a[i])
    }
  }
}

///|
pub fn inspect(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Layout raise C3dError {
  let h = read_header(bytes, limits~)
  let m = read_metadata(bytes, limits~)
  let nchan = if h.analog_per_frame == 0 {
    0
  } else {
    h.analog_values / h.analog_per_frame
  }
  require(
    scalar(m, "POINT", "USED", h.point_count.to_double()) ==
    h.point_count.to_double(),
    "POINT:USED disagrees with header",
  )
  require(
    scalar(m, "POINT", "FRAMES", (h.last_frame - h.first_frame + 1).to_double()) ==
    (h.last_frame - h.first_frame + 1).to_double(),
    "extended/inconsistent POINT:FRAMES unsupported",
  )
  require(
    scalar(m, "POINT", "DATA_START", h.data_block.to_double()) ==
    h.data_block.to_double(),
    "POINT:DATA_START disagrees with header",
  )
  let rate = scalar(m, "POINT", "RATE", h.frame_rate)
  require(
    (rate - h.frame_rate).abs() <= h.frame_rate * 0.00001,
    "POINT:RATE disagrees with header",
  )
  require(
    scalar(m, "POINT", "SCALE", h.scale) == h.scale,
    "POINT:SCALE disagrees with header",
  )
  require(
    scalar(m, "ANALOG", "USED", nchan.to_double()) == nchan.to_double(),
    "ANALOG:USED disagrees with header",
  )
  let arate = scalar(
    m,
    "ANALOG",
    "RATE",
    h.frame_rate * h.analog_per_frame.to_double(),
  )
  require(
    (arate - h.frame_rate * h.analog_per_frame.to_double()).abs() <=
    h.frame_rate * 0.00001,
    "ANALOG:RATE disagrees with header",
  )
  let labels = labels_from(m, "POINT", h.point_count)
  let analog_labels = labels_from(m, "ANALOG", nchan)
  let units = match m.find("POINT", "UNITS") {
    None => ""
    Some(p) => {
      let a = p.strings()
      require(a.length() == 1, "invalid POINT:UNITS")
      a[0]
    }
  }
  let unsigned_analog = match m.find("ANALOG", "FORMAT") {
    None => false
    Some(p) => {
      let a = p.strings()
      require(
        a.length() == 1 && (a[0] == "SIGNED" || a[0] == "UNSIGNED"),
        "unsupported ANALOG:FORMAT",
      )
      a[0] == "UNSIGNED"
    }
  }
  let scales = numeric_vector(m, "SCALE", nchan, 1.0)
  let gen = scalar(m, "ANALOG", "GEN_SCALE", 1.0)
  let offsets = numeric_vector(m, "OFFSET", nchan, 0.0)
  if unsigned_analog {
    for i in 0..<offsets.length() {
      if offsets[i] < 0.0 {
        offsets[i] += 65536.0
      }
    }
  }
  for i in 0..<scales.length() {
    scales[i] *= gen
    require(finite(scales[i]) && scales[i] != 0.0, "invalid analog scale")
  }
  let values = h.point_count * 4 + h.analog_values
  require(
    values <= limits.max_samples &&
    (
      values == 0 ||
      h.last_frame - h.first_frame + 1 <= limits.max_samples / values
    ),
    "sample budget exceeded",
  )
  let frame_bytes = values * (if h.scale < 0.0 { 4 } else { 2 })
  let available = bytes.length() - (h.data_block - 1) * 512
  require(
    frame_bytes == 0 ||
    h.last_frame - h.first_frame + 1 <= available / frame_bytes,
    "truncated frame data",
  )
  {
    header: h,
    metadata: m,
    labels,
    analog_labels,
    units,
    analog_scales: scales,
    analog_offsets: offsets,
    unsigned_analog,
    frame_bytes,
  }
}
