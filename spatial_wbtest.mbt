///|
test "unit conversion scales valid residuals and leaves analog untouched" {
  let t = sample_trial()
  let m = t.convert_units("m")
  assert_eq(m.frames[0].points[0].x, 0.0015)
  assert_eq(m.frames[0].points[0].residual, 0.0005)
  assert_eq(m.frames[0].points[1].residual, -1.0)
  assert_eq(m.frames[0].analog, t.frames[0].analog)
  assert_true(
    try {
      let _ = t.convert_units("inch")
      false
    } catch {
      _ => true
    },
  )
}

///|
test "rigid rotation preserves residual and invalid markers" {
  let t = sample_trial()
  let r = t.transform([0.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0], [
    10.0, 0.0, 0.0,
  ])
  assert_eq(r.frames[0].points[0].x, 12.0)
  assert_eq(r.frames[0].points[0].y, 1.5)
  assert_eq(r.frames[0].points[0].residual, 0.5)
  assert_eq(r.frames[0].points[1], t.frames[0].points[1])
  assert_true(
    try {
      let _ = t.transform([-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], [
        0.0, 0.0, 0.0,
      ])
      false
    } catch {
      _ => true
    },
  )
}
