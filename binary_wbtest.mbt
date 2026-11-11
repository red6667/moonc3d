///|
test "binary endian and float primitives" {
  let b : Array[Byte] = []
  put16(b, 65535)
  put32f(b, -3.5)
  let c = Cursor::new(Bytes::from_array(b[:]), 0, 6, false)
  assert_eq(c.i16(), -1)
  assert_eq(c.f32(), -3.5)
  assert_eq(Cursor::new(b"\x12\x34", 0, 2, true).u16(), 4660)
  assert_eq(product([2, 3], 100), 6)
  assert_eq(ascii(ascii_bytes("C3D")), "C3D")
}
