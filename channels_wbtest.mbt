///|
test "channel selection reorders analog and rejects unknown duplicates" {
  let t = sample_trial()
  let c = t.select(points=["R"], analog=["EMG", "Fx"])
  assert_eq(c.frames[0].points[0].residual, -1.0)
  assert_eq(c.frames[0].analog[1], [4.0, 3.0])
  let no_analog = t.select(points=["L"], analog=[])
  assert_eq(no_analog.analog_per_frame, 0)
  no_analog.validate()
  assert_true(
    try {
      let _ = t.select(points=["missing"], analog=[])
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = t.select(points=["L", "L"], analog=[])
      false
    } catch {
      _ => true
    },
  )
  let r = c.rename(points=["heel"], analog=["a", "b"])
  assert_eq(r.labels, ["heel"])
  assert_eq(r.frames, c.frames)
}
