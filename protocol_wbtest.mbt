///|
test "hex bridge rejects malformed and over budget input" {
  assert_eq(decode_hex("00aBff"), b"\x00\xab\xff")
  assert_eq(encode_hex(b"\x00\xab\xff"), "00abff")
  for text in ["f", "xz", "uu"] {
    assert_true(
      try {
        let _ = decode_hex(text)
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      let _ = decode_hex("0000", max_bytes=1)
      false
    } catch {
      _ => true
    },
  )
}

///|
test "JSON bridge uses explicit version and rejects duplicate fields" {
  let hex = encode_hex(write(sample_trial(), residual_scale=0.5))
  let request = Json::object({
    "schema": Json::string("moonc3d/1"),
    "op": Json::string("read"),
    "hex": Json::string(hex),
  }).stringify()
  let response = process_json(request)
  assert_true(response.contains("first_frame"))
  assert_true(response.contains("analog_per_frame"))
  assert_true(
    try {
      let _ = process_json("{\"schema\":\"x\",\"schema\":\"y\"}")
      false
    } catch {
      _ => true
    },
  )
}
