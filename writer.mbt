///|
fn canonical_metadata(
  t : Trial,
  data_block : Int32,
  residual_scale : Double,
) -> Metadata raise C3dError {
  let groups : Array[Group] = [
    { id: 1, name: "POINT", description: "3D points", locked: false, },
    { id: 2, name: "ANALOG", description: "Calibrated analog", locked: false, },
  ]
  let p = [
    number_parameter("POINT", "USED", [t.labels.length().to_double()], true),
    number_parameter("POINT", "FRAMES", [t.frames.length().to_double()], true),
    number_parameter("POINT", "DATA_START", [data_block.to_double()], true),
    number_parameter("POINT", "SCALE", [-residual_scale], false),
    number_parameter("POINT", "RATE", [t.point_rate], false),
    text_parameter("POINT", "LABELS", t.labels),
    text_parameter("POINT", "DESCRIPTIONS", Array::make(t.labels.length(), "")),
    text_parameter("POINT", "UNITS", [t.units]),
    number_parameter(
      "ANALOG",
      "USED",
      [t.analog_labels.length().to_double()],
      true,
    ),
    number_parameter(
      "ANALOG",
      "RATE",
      [t.point_rate * t.analog_per_frame.to_double()],
      false,
    ),
    number_parameter("ANALOG", "GEN_SCALE", [1.0], false),
    number_parameter(
      "ANALOG",
      "SCALE",
      Array::make(t.analog_labels.length(), 1.0),
      false,
    ),
    number_parameter(
      "ANALOG",
      "OFFSET",
      Array::make(t.analog_labels.length(), 0.0),
      true,
    ),
    text_parameter("ANALOG", "LABELS", t.analog_labels),
    text_parameter(
      "ANALOG",
      "DESCRIPTIONS",
      Array::make(t.analog_labels.length(), ""),
    ),
    text_parameter("ANALOG", "FORMAT", ["SIGNED"]),
  ]
  // Preserve only independent groups: channel/event metadata may become stale after edits.
  for g in t.metadata.groups {
    if g.name != "POINT" &&
      g.name != "ANALOG" &&
      g.name != "EVENT" &&
      g.name != "TRIAL" &&
      g.name != "FORCE_PLATFORM" {
      require(groups.length() < 127, "too many metadata groups")
      require(
        !groups.iter().any(x => x.name == g.name),
        "duplicate metadata group",
      )
      groups.push({ ..g, id: groups.length() + 1, })
      for x in t.metadata.parameters {
        if x.group == g.name {
          p.push(x)
        }
      }
    }
  }
  { groups, parameters: p, }
}

///|
fn metadata_bytes(m : Metadata) -> Bytes raise C3dError {
  let out : Array[Byte] = [0, 0, 0, 84]
  for g in m.groups {
    group_record(out, g)
    for p in m.parameters {
      if p.group == g.name {
        encode_parameter(out, p, g.id)
      }
    }
  }
  put16(out, 0)
  let blocks = (out.length() + 511) / 512
  require(blocks <= 255, "parameter block limit exceeded")
  out[2] = blocks.to_byte()
  pad_to(out, blocks * 512)
  Bytes::from_array(out[:])
}

///|
pub fn write(
  trial : Trial,
  residual_scale~ : Double = 1.0,
  limits~ : Limits = Limits::default(),
) -> Bytes raise C3dError {
  trial.validate(limits~)
  require(
    finite(residual_scale) &&
    residual_scale > 0.0 &&
    Float::from_double(residual_scale).to_double() == residual_scale,
    "residual scale must be positive exactly representable float32",
  )
  require(
    trial.labels.length() <= 255 && trial.analog_labels.length() <= 255,
    "canonical writer supports at most 255 channels of each kind",
  )
  let preliminary = metadata_bytes(canonical_metadata(trial, 0, residual_scale))
  let data_block = 2 + preliminary.length() / 512
  let metadata = metadata_bytes(
    canonical_metadata(trial, data_block, residual_scale),
  )
  let frame_values = trial.labels.length() * 4 +
    trial.analog_labels.length() * trial.analog_per_frame
  require(
    trial.analog_labels.length() * trial.analog_per_frame <= 65535,
    "analog header count overflow",
  )
  let prefix = 512 + metadata.length()
  require(
    prefix <= limits.max_bytes &&
    (
      frame_values == 0 ||
      trial.frames.length() <= (limits.max_bytes - prefix) / 4 / frame_values
    ),
    "output byte budget exceeded",
  )
  let header : Array[Byte] = [2, 80]
  put16(header, trial.labels.length())
  put16(header, trial.analog_labels.length() * trial.analog_per_frame)
  put16(header, trial.first_frame)
  put16(header, trial.first_frame + trial.frames.length() - 1)
  put16(header, 0)
  put32f(header, -residual_scale)
  put16(header, data_block)
  put16(header, trial.analog_per_frame)
  put32f(header, trial.point_rate)
  pad_to(header, 512)
  append_bytes(header, metadata)
  for f in trial.frames {
    for p in f.points {
      put32f(header, p.x)
      put32f(header, p.y)
      put32f(header, p.z)
      let packed = if p.residual < 0.0 {
        -1
      } else {
        require(
          p.residual / residual_scale <= 255.0 &&
          p.residual / residual_scale == (p.residual / residual_scale).trunc(),
          "residual must be an exact multiple of scale in 0..255 units",
        )
        (p.cameras << 8) | (p.residual / residual_scale).to_int()
      }
      put32f(header, packed.to_double())
    }
    for row in f.analog {
      for v in row {
        put32f(header, v)
      }
    }
  }
  let padded = (header.length() + 511) / 512 * 512
  require(padded <= limits.max_bytes, "padded output exceeds byte budget")
  pad_to(header, padded)
  Bytes::from_array(header[:])
}
