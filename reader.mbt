///|
fn frame_at(bytes : Bytes, l : Layout, index : Int32) -> Frame raise C3dError {
  let h = l.header
  require(
    index >= 0 && index <= h.last_frame - h.first_frame,
    "frame index out of range",
  )
  let start = (h.data_block - 1) * 512 + index * l.frame_bytes
  let c = Cursor::new(bytes, start, start + l.frame_bytes, h.processor == 86)
  let points = []
  for _ in 0..<h.point_count {
    points.push(read_point(c, h.scale))
  }
  let analog = []
  for _ in 0..<h.analog_per_frame {
    let row = []
    for ch in 0..<l.analog_labels.length() {
      let raw = if h.scale < 0.0 {
        c.f32()
      } else if l.unsigned_analog {
        c.u16().to_double()
      } else {
        c.i16().to_double()
      }
      let calibrated = (raw - l.analog_offsets[ch]) * l.analog_scales[ch]
      require(finite(calibrated), "nonfinite calibrated analog sample")
      row.push(calibrated)
    }
    analog.push(row)
  }
  { points, analog, }
}

///|
pub fn read_frame(
  bytes : Bytes,
  index : Int32,
  limits~ : Limits = Limits::default(),
) -> Frame raise C3dError {
  frame_at(bytes, inspect(bytes, limits~), index)
}

///|
pub fn read(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Trial raise C3dError {
  let l = inspect(bytes, limits~)
  let frames = []
  for i in 0..<(l.header.last_frame - l.header.first_frame + 1) {
    frames.push(frame_at(bytes, l, i))
  }
  let t : Trial = {
    first_frame: l.header.first_frame,
    point_rate: l.header.frame_rate,
    analog_per_frame: l.header.analog_per_frame,
    labels: l.labels,
    analog_labels: l.analog_labels,
    units: l.units,
    metadata: l.metadata,
    frames,
  }
  t.validate(limits~)
  t
}
