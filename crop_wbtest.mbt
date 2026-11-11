///|
test "crop preserves analog synchronization and original numbering" {
  let t = sample_trial()
  let c = t.crop(1, 2)
  assert_eq(c.first_frame, 8)
  assert_eq(c.frames[0].analog, [[5.0, 6.0], [7.0, 8.0]])
  assert_eq(c.frame_time(0), 0.0)
  assert_eq(t.time_window(0.01, 0.02), c)
  assert_eq(t.frames.length(), 2)
  assert_true(
    try {
      let _ = t.crop(1, 1)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = t.time_window(-0.01, 0.01)
      false
    } catch {
      _ => true
    },
  )
}
