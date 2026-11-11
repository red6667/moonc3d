///|
fn main raise {
  let t = @data.sample().crop(1, 2).select(points=["heel"], analog=["Fx"])
  let edited = t.convert_units("m")
  let bytes = @moonc3d.write(edited, residual_scale=0.0005)
  let restored = @moonc3d.read(bytes)
  assert_eq(restored.first_frame, 8)
  assert_eq(restored.labels, ["heel"])
  assert_true((restored.frames[0].points[0].x - 0.0045).abs() < 0.000000001)
  assert_eq(restored.frames[0].analog, [[3.0], [4.0]])
  println("edit: cropped, selected, converted, rewritten and read back")
}
