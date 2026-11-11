///|
pub(all) struct Limits {
  max_bytes : Int32
  max_frames : Int32
  max_points : Int32
  max_channels : Int32
  max_samples : Int32
  max_parameters : Int32
} derive(Debug, Eq)

///|
pub fn Limits::default() -> Limits {
  {
    max_bytes: 67108864,
    max_frames: 65535,
    max_points: 1024,
    max_channels: 1024,
    max_samples: 4000000,
    max_parameters: 4096,
  }
}

///|
pub(all) struct Header {
  parameter_block : Int32
  data_block : Int32
  point_count : Int32
  analog_values : Int32
  first_frame : Int32
  last_frame : Int32
  analog_per_frame : Int32
  frame_rate : Double
  scale : Double
  processor : Int32
} derive(Debug, Eq)

///|
pub fn read_header(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Header raise C3dError {
  validate_limits(limits)
  require(
    limits.max_bytes >= 512 && bytes.length() <= limits.max_bytes,
    "file byte budget exceeded",
  )
  require(bytes.length() >= 512 && bytes[1] == 80, "not a C3D header")
  let pb = bytes[0].to_int()
  require(
    pb >= 2 && (pb - 1) * 512 + 4 <= bytes.length(),
    "invalid parameter block",
  )
  let processor = bytes[(pb - 1) * 512 + 3].to_int()
  require(
    processor == 84 || processor == 86,
    "only Intel IEEE and MIPS IEEE processors supported",
  )
  let c = Cursor::new(bytes, 2, 24, processor == 86)
  let point_count = c.u16()
  let analog_values = c.u16()
  let first_frame = c.u16()
  let last_frame = c.u16()
  let _gap = c.u16()
  let scale = c.f32()
  let data_block = c.u16()
  let analog_per_frame = c.u16()
  let frame_rate = c.f32()
  require(first_frame >= 1 && last_frame >= first_frame, "invalid frame range")
  require(
    last_frame - first_frame + 1 <= limits.max_frames,
    "frame budget exceeded",
  )
  require(point_count <= limits.max_points, "point budget exceeded")
  require(finite(scale) && scale != 0.0, "invalid point scale")
  require(finite(frame_rate) && frame_rate > 0.0, "invalid frame rate")
  require(
    data_block > pb && (data_block - 1) * 512 <= bytes.length(),
    "invalid data block",
  )
  require(
    (analog_values == 0 && analog_per_frame == 0) ||
    (analog_per_frame > 0 && analog_values % analog_per_frame == 0),
    "inconsistent analog counts",
  )
  if analog_per_frame > 0 {
    require(
      analog_values / analog_per_frame <= limits.max_channels,
      "channel budget exceeded",
    )
  }
  {
    parameter_block: pb,
    data_block,
    point_count,
    analog_values,
    first_frame,
    last_frame,
    analog_per_frame,
    frame_rate,
    scale,
    processor,
  }
}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Header with @debug.Debug::{to_repr}

///|
pub extend Header with Eq::{equal, not_equal}

///|
fn validate_limits(limits : Limits) -> Unit raise C3dError {
  require(
    limits.max_bytes >= 512 &&
    limits.max_bytes <= 268435456 &&
    limits.max_frames > 0 &&
    limits.max_frames <= 65535 &&
    limits.max_points >= 0 &&
    limits.max_points <= 65535 &&
    limits.max_channels >= 0 &&
    limits.max_channels <= 65535 &&
    limits.max_samples > 0 &&
    limits.max_samples <= 67108864 &&
    limits.max_parameters > 0 &&
    limits.max_parameters <= 32767,
    "invalid or unsafe resource limits",
  )
}
