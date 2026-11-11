///|
test "writer builds typed metadata with portable endian conversion" {
  let p = text_parameter("POINT", "LABELS", ["A", "LONG"])
  assert_eq(p.strings(), ["A", "LONG"])
  let n = number_parameter("ANALOG", "SCALE", [0.5, 2.0], false)
  assert_eq(n.numbers(), [0.5, 2.0])
  let b : Array[Byte] = []
  encode_parameter(b, n, 2)
  assert_true(b.length() > 8)
}
