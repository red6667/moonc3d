///|
test "roundtrip Intel DEC and MIPS processor encodings" {
  let t = sample_trial()
  for processor in [84, 85, 86] {
    let bytes = write(t, residual_scale=0.5, processor~)
    let restored = read(bytes)
    assert_eq(restored.frames.length(), t.frames.length())
    assert_true((restored.frames[0].points[0].x - 1.5).abs() < 0.00001)
    assert_true((restored.frames[0].analog[1][1] - 4.0).abs() < 0.00001)
  }
}

///|
test "header event roundtrip for processor variants" {
  let t = {
    ..sample_trial(),
    header_events: [
      { time: 0.125, label: "HS", displayed: true, },
      { time: 0.75, label: "TO", displayed: false, },
    ],
  }
  for processor in [84, 85, 86] {
    let bytes = write(t, residual_scale=0.5, processor~)
    assert_eq(read_header_events(bytes), t.header_events)
    assert_eq(read(bytes).header_events, t.header_events)
  }
}

///|
test "channel metadata arrays split at C3D dimension limit" {
  let values = Array::makei(256, i => "marker_" + i.to_string())
  let parameters = []
  add_text_array(parameters, "POINT", "LABELS", values)
  let m : Metadata = { groups: [], parameters, }
  assert_eq(parameters.length(), 2)
  assert_eq(parameters[0].name, "LABELS")
  assert_eq(parameters[1].name, "LABELS2")
  assert_eq(metadata_strings(m, "POINT", "LABELS"), values)
}

///|
test "VAX F boundaries and reserved operand" {
  for value in [0.0, 1.0, -1.0, 2.938735877055719e-39, 1.7014117331926443e38] {
    let encoded = []
    put_vax(encoded, value)
    let cursor = Cursor::new(Bytes::from_array(encoded[:]), 0, 4, false)
    let restored = decode_vax(cursor.u16(), cursor.u16())
    let tolerance = value.abs() * 0.000001 + 1.0e-40
    assert_true((restored - value).abs() <= tolerance)
  }
  assert_true(
    try {
      let _ = decode_vax(32768, 0)
      false
    } catch {
      _ => true
    },
  )
}

///|
test "extended frame count reconciles LONG_FRAMES and TRIAL words" {
  let m : Metadata = {
    groups: [],
    parameters: [
      number_parameter("POINT", "FRAMES", [65535.0], true),
      number_parameter("POINT", "LONG_FRAMES", [65536.0], false),
      frame_pair("ACTUAL_START_FIELD", 100000),
      frame_pair("ACTUAL_END_FIELD", 165535),
    ],
  }
  let h : Header = {
    parameter_block: 2,
    data_block: 5,
    point_count: 0,
    analog_values: 0,
    first_frame: 100000,
    last_frame: 165534,
    analog_per_frame: 0,
    frame_rate: 100.0,
    scale: -1.0,
    processor: 84,
  }
  let restored = verify_extended_frames(m, h)
  assert_eq(restored.first_frame, 100000)
  assert_eq(restored.last_frame, 165535)
}
