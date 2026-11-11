///|
test "trajectory and analog extraction expose independent sample clocks" {
  let t = sample_trial()
  let m = t.marker_series("R")
  assert_eq(m.frame_numbers, [7, 8])
  assert_eq(m.seconds, [0.0, 0.01])
  assert_eq(m.samples[0].residual, -1.0)
  let a = t.analog_series("EMG")
  assert_eq(a.samples, [2.0, 4.0, 6.0, 8.0])
  assert_eq(a.seconds, [0.0, 0.005, 0.01, 0.015])
  assert_true(
    try {
      let _ = t.analog_series("unknown")
      false
    } catch {
      _ => true
    },
  )
}
