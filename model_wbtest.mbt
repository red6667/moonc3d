///|
fn sample_trial() -> Trial {
  let p : Point = { x: 1.5, y: -2.0, z: 3.25, residual: 0.5, cameras: 3, }
  {
    first_frame: 7,
    point_rate: 100.0,
    analog_per_frame: 2,
    labels: ["L", "R"],
    analog_labels: ["Fx", "EMG"],
    units: "mm",
    metadata: { groups: [], parameters: [], },
    frames: [
      {
        points: [p, { ..p, residual: -1.0, }],
        analog: [[1.0, 2.0], [3.0, 4.0]],
      },
      { points: [{ ..p, x: 4.5, }, p], analog: [[5.0, 6.0], [7.0, 8.0]], },
    ],
  }
}

///|
test "trial validates synchronized point and analog layout" {
  let t = sample_trial()
  t.validate()
  assert_eq(t.duration(), 0.02)
  let bad = { ..t, labels: ["L", "L"], }
  assert_true(
    try {
      bad.validate()
      false
    } catch {
      _ => true
    },
  )
}
