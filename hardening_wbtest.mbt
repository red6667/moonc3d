///|
test "unsafe limits and resource budgets fail before allocation" {
  let t = sample_trial()
  let bytes = write(t, residual_scale=0.5)
  for
    limits in [
      { ..Limits::default(), max_samples: 1, },
      { ..Limits::default(), max_channels: -1, },
      { ..Limits::default(), max_parameters: 0, },
    ] {
    assert_true(
      try {
        let _ = read(bytes, limits~)
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      let _ = write(t, residual_scale=0.5, limits={
        ..Limits::default(),
        max_bytes: 512,
      })
      false
    } catch {
      _ => true
    },
  )
}

///|
test "malformed linked records truncated frames and NaN are rejected" {
  let original = write(sample_trial(), residual_scale=0.5)
  let a = original.to_array()
  let offset = 516 + 2 + 5
  a[offset] = 1
  a[offset + 1] = 0
  assert_true(
    try {
      let _ = read(Bytes::from_array(a[:]))
      false
    } catch {
      _ => true
    },
  )
  let data_start = (read_header(original).data_block - 1) * 512
  let short = Bytes::makei(data_start + 1, i => original[i])
  assert_true(
    try {
      let _ = read(short)
      false
    } catch {
      _ => true
    },
  )
  let nan = original.to_array()
  nan[data_start] = 0
  nan[data_start + 1] = 0
  nan[data_start + 2] = 192
  nan[data_start + 3] = 127
  assert_true(
    try {
      let _ = read(Bytes::from_array(nan[:]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "extended frame metadata cannot silently truncate a trial" {
  let p = number_parameter("TRIAL", "ACTUAL_END_FIELD", [9.0, 1.0], true)
  let m : Metadata = { groups: [], parameters: [p], }
  assert_true(
    try {
      verify_extended_frames(
        m,
        read_header(write(sample_trial(), residual_scale=0.5)),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "deterministic bounded header and parameter mutations never panic" {
  let b = write(sample_trial(), residual_scale=0.5)
  for i in 0..<640 {
    let a = b.to_array()
    a[i] = (a[i].to_int() ^ 255).to_byte()
    try {
      let _ = read(Bytes::from_array(a[:]))
      ()
    } catch {
      _ => ()
    }
  }
}
