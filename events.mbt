///|
pub(all) struct HeaderEvent {
  time : Double
  label : String
  displayed : Bool
} derive(Debug, Eq)

///|
pub fn read_header_events(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Array[HeaderEvent] raise C3dError {
  let h = read_header(bytes, limits~)
  let c = Cursor::new(bytes, 298, 304, h.processor == 86)
  let long_labels = c.u16() == 12345
  let count = c.u16()
  require(count <= 18, "more than eighteen header events")
  let out = []
  for i in 0..<count {
    let c = Cursor::new(
      bytes,
      304 + i * 4,
      308 + i * 4,
      h.processor == 86,
      dec=h.processor == 85,
    )
    let time = c.f32()
    require(finite(time) && time >= 0.0, "invalid header event time")
    let width = if long_labels { 4 } else { 2 }
    let offset = 396 + i * width
    let chars = []
    for j in 0..<width {
      let b = bytes[offset + j].to_int()
      if b != 0 {
        require(b >= 32 && b <= 126, "invalid header event label")
        chars.push(b.unsafe_to_char())
      }
    }
    out.push({
      time,
      label: String::from_array(chars[:]).trim().to_owned(),
      displayed: bytes[376 + i] != 0,
    })
  }
  out
}

///|
fn write_header_events(
  header : Array[Byte],
  events : Array[HeaderEvent],
  processor : Int32,
) -> Unit raise C3dError {
  require(events.length() <= 18, "more than eighteen header events")
  let key = []
  put_word(key, 12345, processor)
  put_word(key, events.length(), processor)
  for i in 0..<4 {
    header[298 + i] = key[i]
  }
  for i in 0..<events.length() {
    let e = events[i]
    require(finite(e.time) && e.time >= 0.0, "invalid header event time")
    let label = ascii_bytes(e.label)
    require(label.length() <= 4, "header event label exceeds four characters")
    let time = []
    put_float(time, e.time, processor)
    for j in 0..<4 {
      header[304 + i * 4 + j] = time[j]
      header[396 + i * 4 + j] = if j < label.length() { label[j] } else { 32 }
    }
    header[376 + i] = if e.displayed { 1 } else { 0 }
  }
}

///|
pub extend HeaderEvent with @debug.Debug::{to_repr}

///|
pub extend HeaderEvent with Eq::{equal, not_equal}
