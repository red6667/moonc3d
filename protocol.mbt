///|
fn hex_digit(c : Char) -> Int32 raise C3dError {
  let n = c.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 65 && n <= 70 {
    n - 55
  } else if n >= 97 && n <= 102 {
    n - 87
  } else {
    raise Invalid("invalid hexadecimal digit")
  }
}

///|
pub fn decode_hex(
  text : String,
  max_bytes~ : Int32 = 67108864,
) -> Bytes raise C3dError {
  require(
    max_bytes >= 0 && text.length() % 2 == 0 && text.length() / 2 <= max_bytes,
    "hex length/budget invalid",
  )
  let out : Array[Byte] = []
  let mut high = -1
  for c in text.iter() {
    let d = hex_digit(c)
    if high < 0 {
      high = d
    } else {
      out.push((high * 16 + d).to_byte())
      high = -1
    }
  }
  require(high < 0, "odd hex length")
  Bytes::from_array(out[:])
}

///|
pub fn encode_hex(bytes : Bytes) -> String {
  let out = StringBuilder()
  let digits = "0123456789abcdef"
  for b in bytes {
    out.write_char(digits[b.to_int() >> 4].to_int().unsafe_to_char())
    out.write_char(digits[b.to_int() & 15].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
pub fn Trial::to_json(self : Trial) -> Json raise C3dError {
  self.validate()
  Json::object({
    "first_frame": Json::number(self.first_frame.to_double()),
    "point_rate": Json::number(self.point_rate),
    "analog_per_frame": Json::number(self.analog_per_frame.to_double()),
    "labels": Json::array(self.labels.map(Json::string)),
    "analog_labels": Json::array(self.analog_labels.map(Json::string)),
    "units": Json::string(self.units),
    "frames": Json::array(
      self.frames.map(f => {
        Json::object({
          "points": Json::array(
            f.points.map(p => {
              Json::array([
                Json::number(p.x),
                Json::number(p.y),
                Json::number(p.z),
                Json::number(p.residual),
                Json::number(p.cameras.to_double()),
              ])
            }),
          ),
          "analog": Json::array(
            f.analog.map(row => Json::array(row.map(v => Json::number(v)))),
          ),
        })
      }),
    ),
  })
}

///|
fn required_string(
  object : Map[String, Json],
  key : String,
) -> String raise C3dError {
  match object.get(key) {
    Some(String(s)) => s
    _ => raise Invalid("expected string: " + key)
  }
}

// Versioned, bounded JSON bridge for host runtimes. Binary I/O belongs to the caller.

///|
pub fn process_json(request : String) -> String raise C3dError {
  require(request.length() <= 134218752, "JSON request too large")
  let value = @json.parse(
    request[:],
    max_nesting_depth=16,
    reject_duplicate_keys=true,
  ) catch {
    _ => raise Invalid("invalid JSON request")
  }
  let fields = match value {
    Object(m) => m
    _ => raise Invalid("request must be an object")
  }
  for key in fields.keys() {
    require(
      key == "schema" || key == "op" || key == "hex" || key == "residual_scale",
      "unknown request field: " + key,
    )
  }
  require(
    required_string(fields, "schema") == "moonc3d/1",
    "unsupported JSON schema",
  )
  let op = required_string(fields, "op")
  let bytes = decode_hex(required_string(fields, "hex"))
  let trial = read(bytes)
  let result = match op {
    "read" => trial.to_json()
    "rewrite" => {
      let scale = match fields.get("residual_scale") {
        None => 1.0
        Some(Number(n, ..)) => n
        _ => raise Invalid("residual_scale must be numeric")
      }
      Json::object({
        "hex": Json::string(encode_hex(write(trial, residual_scale=scale))),
      })
    }
    "points_csv" => Json::string(trial.points_csv())
    "analog_csv" => Json::string(trial.analog_csv())
    _ => raise Invalid("unsupported operation: " + op)
  }
  Json::object({ "schema": Json::string("moonc3d/1"), "result": result }).stringify()
}
