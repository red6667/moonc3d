///|
test "parameter block bounds and empty record terminator" {
  let a = header_fixture().to_array()
  a[514] = 1
  assert_eq(read_metadata(Bytes::from_array(a[:])).groups.length(), 0)
  a[514] = 2
  assert_true(
    try {
      let _ = read_metadata(Bytes::from_array(a[:]))
      false
    } catch {
      _ => true
    },
  )
}
