///|
test "unit converted residuals survive float32 scale representation" {
  let t = sample_trial().convert_units("m")
  let r = read(write(t, residual_scale=0.0005))
  assert_true((r.frames[0].points[0].residual - 0.0005).abs() < 0.000000001)
  assert_true(
    try {
      let _ = write(t, residual_scale=0.0)
      false
    } catch {
      _ => true
    },
  )
}

///|
test "independent metadata is preserved and stale channel groups discarded" {
  let t = sample_trial()
  let custom = number_parameter("CUSTOM", "GAIN", [2.0], false)
  let metadata : Metadata = {
    groups: [
      { id: 3, name: "CUSTOM", description: "independent", locked: false, },
      { id: 4, name: "EVENT", description: "stale", locked: false, },
    ],
    parameters: [custom, text_parameter("EVENT", "LABELS", ["old"])],
  }
  let r = read(write({ ..t, metadata, }, residual_scale=0.5))
  assert_eq(r.metadata.find("CUSTOM", "GAIN").unwrap().numbers(), [2.0])
  assert_eq(r.metadata.find("EVENT", "LABELS"), None)
  let bad = {
    ..metadata,
    groups: [{ id: 1, name: "point", description: "", locked: false, }],
  }
  assert_true(
    try {
      let _ = write({ ..t, metadata: bad, }, residual_scale=0.5)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = write(t, residual_scale=0.5, limits={
        ..Limits::default(),
        max_parameters: 1,
      })
      false
    } catch {
      _ => true
    },
  )
}
