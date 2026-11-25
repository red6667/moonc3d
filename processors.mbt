// C3D processor 85 uses VAX F-floating: little-endian 16-bit words,
// exponent bias 128 and a normalized 0.5 significand. Decode through Double
// so the two smallest VAX exponents do not lose IEEE-subnormal precision.

///|
fn decode_vax(low : Int32, high : Int32) -> Double raise C3dError {
  let exponent = (low >> 7) & 255
  let negative = (low & 32768) != 0
  if exponent == 0 {
    require(!negative, "VAX reserved operand")
    return 0.0
  }
  let fraction = ((low & 127) << 16) | high
  let mut value = 1.0 + fraction.to_double() / 8388608.0
  let power = exponent - 129
  if power >= 0 {
    for _ in 0..<power {
      value *= 2.0
    }
  } else {
    for _ in 0..<-power {
      value /= 2.0
    }
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
fn put_vax(out : Array[Byte], x : Double) -> Unit raise C3dError {
  require(finite(x), "nonfinite VAX value")
  if x == 0.0 {
    put16(out, 0)
    put16(out, 0)
    return
  }
  let mut significand = x.abs()
  let mut power = 0
  while significand >= 2.0 && power <= 126 {
    significand /= 2.0
    power += 1
  }
  while significand < 1.0 && power >= -128 {
    significand *= 2.0
    power -= 1
  }
  require(power >= -128 && power <= 126, "value outside VAX F range")
  let raw = (significand - 1.0) * 8388608.0
  let floor = raw.floor()
  let remainder = raw - floor
  let mut fraction = floor.to_int()
  // Round to nearest, ties to even at the format's 24-bit significand.
  if remainder > 0.5 || (remainder == 0.5 && fraction % 2 == 1) {
    fraction += 1
  }
  if fraction == 8388608 {
    fraction = 0
    power += 1
  }
  require(power <= 126, "rounded VAX value overflow")
  let sign = if x < 0.0 { 32768 } else { 0 }
  put16(out, sign | ((power + 129) << 7) | (fraction >> 16))
  put16(out, fraction & 65535)
}

///|
fn put_word(out : Array[Byte], x : Int32, processor : Int32) -> Unit {
  if processor == 86 {
    put8(out, x >> 8)
    put8(out, x)
  } else {
    put16(out, x)
  }
}

///|
fn put_float(
  out : Array[Byte],
  x : Double,
  processor : Int32,
) -> Unit raise C3dError {
  if processor == 85 {
    put_vax(out, x)
  } else {
    let tmp = []
    put32f(tmp, x)
    if processor == 86 {
      for i in 0..<4 {
        out.push(tmp[3 - i])
      }
    } else {
      for b in tmp {
        out.push(b)
      }
    }
  }
}

///|
fn checked_processor(processor : Int32) -> Unit raise C3dError {
  require(
    processor == 84 || processor == 85 || processor == 86,
    "invalid C3D processor (expected 84, 85 or 86)",
  )
}
