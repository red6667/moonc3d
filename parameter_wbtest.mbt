///|
test "typed metadata parameters and case-insensitive lookup" {
  let p : Parameter = {
    group: "POINT",
    name: "LABELS",
    description: "",
    locked: false,
    element_size: -1,
    dimensions: [4, 2],
    data: b"L   R   ",
    big_endian: false,
  }
  assert_eq(p.strings(), ["L", "R"])
  let m : Metadata = { groups: [], parameters: [p], }
  assert_true(m.find("point", "labels") is Some(_))
  assert_eq(scalar(m, "POINT", "RATE", 120.0), 120.0)
}
