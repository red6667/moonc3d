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

///|
test "fractional residuals are preserved with explicit scale" {
  let t = sample_trial()
  let r = read(write(t, residual_scale=0.5))
  assert_eq(r.frames, t.frames)
  assert_true(
    try {
      let _ = write(t)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    (read(write(t, residual_scale=0.1)).frames[0].points[0].residual - 0.5).abs() <
    0.000001,
  )
}

///|
test "unsigned POINT frame count interpretation" {
  let p = number_parameter("POINT", "FRAMES", [40000.0], true)
  let m : Metadata = { groups: [], parameters: [p], }
  assert_eq(counter(m, "FRAMES", 0.0), 40000.0)
}
