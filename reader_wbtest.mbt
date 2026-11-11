///|
test "full reader handles zero channels and indexes bounds" {
  let a = header_fixture().to_array()
  a[514] = 1
  let b = Bytes::from_array(a[:])
  let t = read(b)
  assert_eq(t.first_frame, 1)
  assert_eq(t.frames.length(), 1)
  assert_eq(read_frame(b, 0).points.length(), 0)
  assert_true(
    try {
      let _ = read_frame(b, 1)
      false
    } catch {
      _ => true
    },
  )
}
