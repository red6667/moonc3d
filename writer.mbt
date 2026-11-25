///|
fn canonical_metadata(
  t : Trial,
  data_block : Int32,
  scale : Double,
  scales : Array[Double],
  offsets : Array[Double],
  unsigned : Bool,
  processor : Int32,
) -> Metadata raise C3dError {
  let groups : Array[Group] = [
    { id: 1, name: "POINT", description: "3D points", locked: false, },
    { id: 2, name: "ANALOG", description: "Calibrated analog", locked: false, },
    {
      id: 3,
      name: "TRIAL",
      description: "32-bit source frame range",
      locked: false,
    },
  ]
  let n = t.frames.length()
  let exact_float_count = Float::from_double(n.to_double()).to_double() ==
    n.to_double()
  let p = [
    number_parameter(
      "POINT",
      "USED",
      [t.labels.length().to_double()],
      true,
      processor~,
    ),
    number_parameter(
      "POINT",
      "FRAMES",
      [if n < 65535 || exact_float_count { n.to_double() } else { 65535.0 }],
      n < 65535 || !exact_float_count,
      processor~,
    ),
    number_parameter(
      "POINT",
      "DATA_START",
      [data_block.to_double()],
      true,
      processor~,
    ),
    number_parameter("POINT", "SCALE", [scale], false, processor~),
    number_parameter("POINT", "RATE", [t.point_rate], false, processor~),
    text_parameter("POINT", "UNITS", [t.units]),
    number_parameter(
      "ANALOG",
      "USED",
      [t.analog_labels.length().to_double()],
      true,
      processor~,
    ),
    number_parameter(
      "ANALOG",
      "RATE",
      [t.point_rate * t.analog_per_frame.to_double()],
      false,
      processor~,
    ),
    number_parameter("ANALOG", "GEN_SCALE", [1.0], false, processor~),
    text_parameter("ANALOG", "FORMAT", [
      if unsigned {
        "UNSIGNED"
      } else {
        "SIGNED"
      },
    ]),
    number_parameter("ANALOG", "BITS", [16.0], true, processor~),
    frame_pair("ACTUAL_START_FIELD", t.first_frame),
    frame_pair("ACTUAL_END_FIELD", t.first_frame + n - 1),
  ]
  if n >= 65535 && exact_float_count {
    p.push(
      number_parameter(
        "POINT",
        "LONG_FRAMES",
        [n.to_double()],
        false,
        processor~,
      ),
    )
  }
  for (group, labels) in [("POINT", t.labels), ("ANALOG", t.analog_labels)] {
    add_text_array(p, group, "LABELS", labels)
    let descriptions = metadata_strings(t.metadata, group, "DESCRIPTIONS")
    add_text_array(
      p,
      group,
      "DESCRIPTIONS",
      Array::makei(labels.length(), i => {
        if i < descriptions.length() {
          descriptions[i]
        } else {
          ""
        }
      }),
    )
  }
  let units = metadata_strings(t.metadata, "ANALOG", "UNITS")
  add_text_array(
    p,
    "ANALOG",
    "UNITS",
    Array::makei(t.analog_labels.length(), i => {
      if i < units.length() {
        units[i]
      } else {
        ""
      }
    }),
  )
  add_number_array(p, "ANALOG", "SCALE", scales, false, processor)
  add_number_array(p, "ANALOG", "OFFSET", offsets, true, processor)
  // Rebuild only authoritative layout/calibration fields. Keep typed optional
  // EVENT/FORCE_PLATFORM/vendor metadata for an unedited read -> write.
  for g in t.metadata.groups {
    if !groups.iter().any(x => x.name == g.name) {
      require(groups.length() < 127, "too many metadata groups")
      groups.push({ ..g, id: groups.length() + 1, })
    }
    for x in t.metadata.parameters {
      if x.group == g.name && !regenerated_parameter(x.group, x.name) {
        p.push(x)
      }
    }
  }
  if !groups.iter().any(g => g.name == "FORCE_PLATFORM") {
    require(groups.length() < 127, "too many metadata groups")
    groups.push({
      id: groups.length() + 1,
      name: "FORCE_PLATFORM",
      description: "No force platforms",
      locked: false,
    })
    p.push(number_parameter("FORCE_PLATFORM", "USED", [0.0], true, processor~))
  }
  { groups, parameters: p, }
}

///|
fn metadata_bytes(
  m : Metadata,
  processor~ : Int32 = 84,
) -> Bytes raise C3dError {
  let out : Array[Byte] = [0, 0, 0, processor.to_byte()]
  for g in m.groups {
    group_record(out, g, processor~)
    for p in m.parameters {
      if p.group == g.name {
        encode_parameter(out, p, g.id, processor~)
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
fn exact_integer(
  value : Double,
  minimum : Int32,
  maximum : Int32,
  what : String,
) -> Int32 raise C3dError {
  let rounded = value.round()
  require(
    finite(value) &&
    rounded >= minimum.to_double() &&
    rounded <= maximum.to_double() &&
    (value - rounded).abs() <= 0.00001,
    what + " is not representable at the selected scale",
  )
  rounded.to_int()
}

///|
pub fn write(
  trial : Trial,
  residual_scale~ : Double = 1.0,
  processor~ : Int32 = 84,
  integer~ : Bool = false,
  unsigned_analog~ : Bool = false,
  analog_scales~ : Array[Double]? = None,
  analog_offsets~ : Array[Double]? = None,
  limits~ : Limits = Limits::default(),
) -> Bytes raise C3dError {
  trial.validate(limits~)
  checked_processor(processor)
  // Normalize options through the actual target representation, not host Float.
  let encoded_scale = []
  put_float(encoded_scale, residual_scale, processor)
  let c = Cursor::new(
    Bytes::from_array(encoded_scale[:]),
    0,
    4,
    processor == 86,
    dec=processor == 85,
  )
  let residual_scale = c.f32()
  require(
    finite(residual_scale) && residual_scale > 0.0,
    "residual scale must be positive",
  )
  let count = trial.analog_labels.length()
  let scales = analog_scales.unwrap_or(Array::make(count, 1.0)).copy()
  let offsets = analog_offsets.unwrap_or(Array::make(count, 0.0)).copy()
  require(
    scales.length() == count && offsets.length() == count,
    "analog calibration shape mismatch",
  )
  for i in 0..<count {
    let encoded = []
    put_float(encoded, scales[i], processor)
    let c = Cursor::new(
      Bytes::from_array(encoded[:]),
      0,
      4,
      processor == 86,
      dec=processor == 85,
    )
    scales[i] = c.f32()
    require(scales[i] != 0.0, "zero analog scale")
    let _ = exact_integer(
      offsets[i],
      if unsigned_analog {
        0
      } else {
        -32768
      },
      if unsigned_analog {
        65535
      } else {
        32767
      },
      "analog offset",
    )
  }
  validate_metadata(trial.metadata, limits)
  let scale = if integer { residual_scale } else { -residual_scale }
  let canonical = canonical_metadata(
    trial, 0, scale, scales, offsets, unsigned_analog, processor,
  )
  validate_metadata(canonical, limits)
  let preliminary = metadata_bytes(canonical, processor~)
  let data_block = 2 + preliminary.length() / 512
  let metadata = metadata_bytes(
    canonical_metadata(
      trial, data_block, scale, scales, offsets, unsigned_analog, processor,
    ),
    processor~,
  )
  let frame_values = trial.labels.length() * 4 + count * trial.analog_per_frame
  require(
    count * trial.analog_per_frame <= 65535,
    "analog header count overflow",
  )
  let prefix = 512 + metadata.length()
  let width = if integer { 2 } else { 4 }
  require(
    prefix <= limits.max_bytes &&
    (
      frame_values == 0 ||
      trial.frames.length() <=
      (limits.max_bytes - prefix) / width / frame_values
    ),
    "output byte budget exceeded",
  )
  let header : Array[Byte] = [2, 80]
  put_word(header, trial.labels.length(), processor)
  put_word(header, count * trial.analog_per_frame, processor)
  put_word(header, trial.first_frame.min(65535), processor)
  put_word(
    header,
    (trial.first_frame + trial.frames.length() - 1).min(65535),
    processor,
  )
  put_word(header, 0, processor)
  put_float(header, scale, processor)
  put_word(header, data_block, processor)
  put_word(header, trial.analog_per_frame, processor)
  put_float(header, trial.point_rate, processor)
  pad_to(header, 512)
  write_header_events(header, trial.header_events, processor)
  append_bytes(header, metadata)
  for f in trial.frames {
    for p in f.points {
      for value in [p.x, p.y, p.z] {
        if integer {
          put_word(
            header,
            exact_integer(
              value / residual_scale,
              -32768,
              32767,
              "point coordinate",
            ),
            processor,
          )
        } else {
          put_float(header, value, processor)
        }
      }
      let packed = if p.residual < 0.0 {
        -1
      } else {
        (p.cameras << 8) |
        exact_integer(p.residual / residual_scale, 0, 255, "residual")
      }
      if integer {
        put_word(header, packed, processor)
      } else {
        put_float(header, packed.to_double(), processor)
      }
    }
    for row in f.analog {
      for i in 0..<row.length() {
        let raw = row[i] / scales[i] + offsets[i]
        if integer {
          put_word(
            header,
            exact_integer(
              raw,
              if unsigned_analog {
                0
              } else {
                -32768
              },
              if unsigned_analog {
                65535
              } else {
                32767
              },
              "analog sample",
            ),
            processor,
          )
        } else {
          put_float(header, raw, processor)
        }
      }
    }
  }
  let padded = (header.length() + 511) / 512 * 512
  require(padded <= limits.max_bytes, "padded output exceeds byte budget")
  pad_to(header, padded)
  let output = Bytes::from_array(header[:])
  check_required(inspect(output, limits~))
  output
}
