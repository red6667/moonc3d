///|
fn parameter_record(
  out : Array[Byte],
  name : String,
  gid : Int32,
  payload : Bytes,
  locked : Bool,
  processor~ : Int32 = 84,
) -> Unit raise C3dError {
  let nb = ascii_bytes(name)
  require(
    nb.length() > 0 && nb.length() <= 127 && payload.length() <= 32765,
    "record too large",
  )
  put8(out, if locked { -nb.length() } else { nb.length() })
  put8(out, gid)
  append_bytes(out, nb)
  put_word(out, payload.length() + 2, processor)
  append_bytes(out, payload)
}

///|
fn group_record(
  out : Array[Byte],
  g : Group,
  processor~ : Int32 = 84,
) -> Unit raise C3dError {
  let desc = ascii_bytes(g.description)
  require(
    g.id >= 1 && g.id <= 127 && desc.length() <= 255,
    "invalid group record",
  )
  let payload = [desc.length().to_byte()]
  append_bytes(payload, desc)
  parameter_record(
    out,
    g.name,
    -g.id,
    Bytes::from_array(payload[:]),
    g.locked,
    processor~,
  )
}

///|
fn encode_parameter(
  out : Array[Byte],
  p : Parameter,
  gid : Int32,
  processor~ : Int32 = 84,
) -> Unit raise C3dError {
  let payload : Array[Byte] = []
  require(p.dimensions.length() <= 7, "too many parameter dimensions")
  require(
    p.element_size == -1 ||
    p.element_size == 1 ||
    p.element_size == 2 ||
    p.element_size == 4,
    "invalid parameter element type",
  )
  let n = product(p.dimensions, 16777216)
  require(
    n * p.element_size.abs() == p.data.length(),
    "parameter data shape mismatch",
  )
  let desc = ascii_bytes(p.description)
  require(desc.length() <= 255, "parameter description too long")
  put8(payload, p.element_size)
  put8(payload, p.dimensions.length())
  for d in p.dimensions {
    put8(payload, d)
  }
  if p.element_size == 4 {
    for x in p.numbers() {
      put_float(payload, x, processor)
    }
  } else if p.element_size == 2 {
    for x in p.numbers() {
      put_word(payload, x.to_int(), processor)
    }
  } else {
    append_bytes(payload, p.data)
  }
  put8(payload, desc.length())
  append_bytes(payload, desc)
  parameter_record(
    out,
    p.name,
    gid,
    Bytes::from_array(payload[:]),
    p.locked,
    processor~,
  )
}

///|
fn text_parameter(
  group : String,
  name : String,
  strings : Array[String],
) -> Parameter raise C3dError {
  require(
    strings.length() <= 255,
    "more than 255 string entries unsupported by canonical writer",
  )
  let mut width = 1
  for s in strings {
    width = width.max(ascii_bytes(s).length())
  }
  require(width <= 255, "string entry too wide")
  let data : Array[Byte] = []
  for s in strings {
    let b = ascii_bytes(s)
    append_bytes(data, b)
    for _ in b.length()..<width {
      data.push(32)
    }
  }
  {
    group,
    name,
    description: "",
    locked: false,
    element_size: -1,
    dimensions: [width, strings.length()],
    data: Bytes::from_array(data[:]),
    vax: false,
    big_endian: false,
  }
}

///|
fn number_parameter(
  group : String,
  name : String,
  values : Array[Double],
  integer : Bool,
  processor~ : Int32 = 84,
) -> Parameter raise C3dError {
  require(values.length() <= 255, "numeric parameter array too long")
  let data : Array[Byte] = []
  for x in values {
    if integer {
      require(
        finite(x) && x >= -32768.0 && x <= 65535.0 && x == x.trunc(),
        "integer parameter out of range",
      )
      put_word(data, x.to_int(), processor)
    } else {
      put_float(data, x, processor)
    }
  }
  {
    group,
    name,
    description: "",
    locked: false,
    element_size: if integer {
      2
    } else {
      4
    },
    dimensions: if values.length() == 1 {
      []
    } else {
      [values.length()]
    },
    data: Bytes::from_array(data[:]),
    vax: processor == 85,
    big_endian: processor == 86,
  }
}
