///|
test "canonical writer roundtrip points invalid samples analog and frame number" {
  let t = sample_trial()
  let frames = t.frames.map(f => {
    ..f,
    points: f.points.map(p => {
      if p.residual < 0.0 {
        p
      } else {
        { ..p, residual: 2.0, }
      }
    }),
  })
  let original = { ..t, frames, }
  let b = write(original)
  let r = read(b)
  assert_eq(r.frames, original.frames)
  assert_eq(r.first_frame, 7)
  assert_eq(r.labels, ["L", "R"])
  assert_eq(r.analog_labels, ["Fx", "EMG"])
  assert_eq(b.length() % 512, 0)
}
