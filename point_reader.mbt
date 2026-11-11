///|
fn read_point(c : Cursor, scale : Double) -> Point raise C3dError {
  let floating = scale < 0.0
  let x = if floating { c.f32() } else { c.i16().to_double() * scale }
  let y = if floating { c.f32() } else { c.i16().to_double() * scale }
  let z = if floating { c.f32() } else { c.i16().to_double() * scale }
  let packed = if floating {
    let v = c.f32()
    require(
      finite(v) && v >= -32768.0 && v <= 32767.0 && v == v.trunc(),
      "invalid floating residual word",
    )
    v.to_int()
  } else {
    c.i16()
  }
  require(finite(x) && finite(y) && finite(z), "nonfinite point coordinates")
  {
    x,
    y,
    z,
    residual: if packed < 0 {
      -1.0
    } else {
      (packed & 255).to_double() * scale.abs()
    },
    cameras: if packed < 0 {
      0
    } else {
      (packed >> 8) & 127
    },
  }
}

///|
pub fn decode_point_record(
  bytes : Bytes,
  scale : Double,
  big_endian~ : Bool = false,
) -> Point raise C3dError {
  require(finite(scale) && scale != 0.0, "invalid point scale")
  let width = if scale < 0.0 { 16 } else { 8 }
  require(bytes.length() == width, "point record has wrong width")
  read_point(Cursor::new(bytes, 0, width, big_endian), scale)
}
