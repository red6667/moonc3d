///|
test "quality excludes invalid markers and measures contiguous missing runs" {
  let t = sample_trial()
  let q = t.marker_quality()
  assert_eq(q[0].valid, 2)
  assert_eq(q[0].minimum, Some([1.5, -2.0, 3.25]))
  assert_eq(q[0].maximum, Some([4.5, -2.0, 3.25]))
  assert_eq(q[1].missing, 1)
  assert_eq(q[1].longest_gap, 1)
  let absent = {
    ..t,
    frames: t.frames.map(f => {
      ..f,
      points: f.points.map(p => { ..p, residual: -1.0, cameras: 0, }),
    }),
  }
  assert_eq(absent.marker_quality()[0].minimum, None)
  assert_eq(absent.marker_quality()[0].longest_gap, 2)
  let a = t.analog_quality()
  assert_eq(a[0].count, 4)
  assert_eq(a[0].mean, 4.0)
  assert_eq(a[1].maximum, 8.0)
}
