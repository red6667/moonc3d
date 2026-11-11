///|
test "layout detects truncated frames and synthesizes absent labels" {
  let a = header_fixture().to_array()
  a[514] = 1
  let l = inspect(Bytes::from_array(a[:]))
  assert_eq(l.frame_bytes, 0)
  a[2] = 1
  assert_true(
    try {
      let _ = inspect(Bytes::from_array(a[:]))
      false
    } catch {
      _ => true
    },
  )
}
