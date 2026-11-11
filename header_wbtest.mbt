///|
fn header_fixture() -> Bytes {
  let b = Array::make(1024, (0 : Byte))
  b[0] = 2
  b[1] = 80
  b[6] = 1
  b[8] = 1
  b[16] = 3
  b[14] = 128
  b[15] = 191
  b[22] = 112
  b[23] = 66
  b[515] = 84
  Bytes::from_array(b[:])
}

///|
test "header accepts Intel and rejects unsupported processor" {
  let h = read_header(header_fixture())
  assert_eq(h.frame_rate, 60.0)
  assert_eq(h.scale, -1.0)
  let a = header_fixture().to_array()
  a[515] = 85
  let bad = try {
    let _ = read_header(Bytes::from_array(a[:]))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
