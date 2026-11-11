///|
test "packed point residual and camera mask integer format" {
  let p = @moonc3d.decode_point_record(b"\x02\x00\xfc\xff\x06\x00\x03\x05", 0.5)
  assert_eq(p.x, 1.0)
  assert_eq(p.y, -2.0)
  assert_eq(p.residual, 1.5)
  assert_eq(p.cameras, 5)
  let q = @moonc3d.decode_point_record(b"\x00\x00\x00\x00\x00\x00\xff\xff", 1.0)
  assert_eq(q.residual, -1.0)
  assert_eq(q.cameras, 0)
}
