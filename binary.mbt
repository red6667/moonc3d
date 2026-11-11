///|
pub suberror C3dError {
  Invalid(String)
} derive(Debug)

///|
fn require(ok : Bool, message : String) -> Unit raise C3dError {
  if !ok {
    raise Invalid(message)
  }
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
priv struct Cursor {
  data : Bytes
  mut pos : Int32
  end : Int32
  big : Bool
}

///|
fn Cursor::new(
  data : Bytes,
  start : Int32,
  end : Int32,
  big : Bool,
) -> Cursor raise C3dError {
  require(
    start >= 0 && end >= start && end <= data.length(),
    "invalid byte range",
  )
  { data, pos: start, end, big, }
}

///|
fn Cursor::u8(self : Cursor) -> Int32 raise C3dError {
  require(self.pos < self.end, "truncated byte")
  let x = self.data[self.pos].to_int()
  self.pos += 1
  x
}

///|
fn Cursor::i8(self : Cursor) -> Int32 raise C3dError {
  let x = self.u8()
  if x >= 128 {
    x - 256
  } else {
    x
  }
}

///|
fn Cursor::u16(self : Cursor) -> Int32 raise C3dError {
  let a = self.u8()
  let b = self.u8()
  if self.big {
    a * 256 + b
  } else {
    b * 256 + a
  }
}

///|
fn Cursor::i16(self : Cursor) -> Int32 raise C3dError {
  let x = self.u16()
  if x >= 32768 {
    x - 65536
  } else {
    x
  }
}

///|
fn Cursor::f32(self : Cursor) -> Double raise C3dError {
  let a = self.u16()
  let b = self.u16()
  let bits = if self.big { (a << 16) | b } else { (b << 16) | a }
  Float::reinterpret_from_int(bits).to_double()
}

///|
fn Cursor::take(self : Cursor, n : Int32) -> Bytes raise C3dError {
  require(n >= 0 && n <= self.end - self.pos, "truncated byte payload")
  let b = Bytes::makei(n, i => self.data[self.pos + i])
  self.pos += n
  b
}

///|
fn ascii(data : Bytes) -> String raise C3dError {
  let chars : Array[Char] = []
  for b in data {
    let n = b.to_int()
    require(n >= 32 && n <= 126, "non-ASCII metadata text")
    chars.push(n.unsafe_to_char())
  }
  String::from_array(chars[:])
}

///|
fn ascii_bytes(s : String) -> Bytes raise C3dError {
  let a : Array[Byte] = []
  for c in s.iter() {
    let n = c.to_int()
    require(n >= 32 && n <= 126, "non-ASCII metadata text")
    a.push(n.to_byte())
  }
  Bytes::from_array(a[:])
}

///|
fn put8(out : Array[Byte], x : Int32) -> Unit {
  out.push((x & 255).to_byte())
}

///|
fn put16(out : Array[Byte], x : Int32) -> Unit {
  put8(out, x)
  put8(out, x >> 8)
}

///|
fn put32f(out : Array[Byte], x : Double) -> Unit raise C3dError {
  require(
    finite(x) && !Float::from_double(x).is_inf(),
    "value cannot be represented as float32",
  )
  let bits = Float::from_double(x).reinterpret_as_int()
  put16(out, bits & 65535)
  put16(out, (bits >> 16) & 65535)
}

///|
fn append_bytes(out : Array[Byte], b : Bytes) -> Unit {
  for x in b {
    out.push(x)
  }
}

///|
fn pad_to(out : Array[Byte], size : Int32) -> Unit {
  while out.length() < size {
    out.push(0)
  }
}

///|
fn product(dims : Array[Int32], limit : Int32) -> Int32 raise C3dError {
  let mut n = 1
  for d in dims {
    require(d >= 0 && d <= 255, "invalid parameter dimension")
    if d == 0 {
      n = 0
    } else {
      require(n <= limit / d, "parameter size exceeds budget")
      n *= d
    }
  }
  n
}

///|
pub extend C3dError with @debug.Debug::{to_repr}
