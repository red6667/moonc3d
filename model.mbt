///|
pub(all) struct Point {
  x : Double
  y : Double
  z : Double
  residual : Double
  cameras : Int32
} derive(Debug, Eq)

///|
pub(all) struct Frame {
  points : Array[Point]
  analog : Array[Array[Double]]
} derive(Debug, Eq)

///|
pub(all) struct Trial {
  first_frame : Int32
  point_rate : Double
  analog_per_frame : Int32
  labels : Array[String]
  analog_labels : Array[String]
  units : String
  metadata : Metadata
  frames : Array[Frame]
} derive(Debug, Eq)

///|
pub fn Trial::validate(
  self : Trial,
  limits~ : Limits = Limits::default(),
) -> Unit raise C3dError {
  validate_limits(limits)
  require(
    self.first_frame >= 1 &&
    self.frames.length() > 0 &&
    self.frames.length() <= limits.max_frames,
    "invalid trial frame range",
  )
  require(
    self.first_frame <= 65535 &&
    self.frames.length() <= 65536 - self.first_frame,
    "extended frame numbering unsupported",
  )
  require(
    finite(self.point_rate) && self.point_rate > 0.0,
    "invalid trial point rate",
  )
  require(
    self.labels.length() <= limits.max_points &&
    self.analog_labels.length() <= limits.max_channels,
    "trial channel budget exceeded",
  )
  require(
    self.analog_per_frame >= 0 && self.analog_per_frame <= 65535,
    "invalid analog subframe count",
  )
  require(
    (self.analog_labels.length() == 0) == (self.analog_per_frame == 0),
    "analog rate/channel mismatch",
  )
  require(
    self.labels.length() <= limits.max_samples / 4 &&
    (
      self.analog_per_frame == 0 ||
      self.analog_labels.length() <= limits.max_samples / self.analog_per_frame
    ),
    "trial frame sample budget exceeded",
  )
  let per_frame = self.labels.length() * 4 +
    self.analog_labels.length() * self.analog_per_frame
  require(
    per_frame <= limits.max_samples &&
    (per_frame == 0 || self.frames.length() <= limits.max_samples / per_frame),
    "trial sample budget exceeded",
  )
  validate_labels(self.labels)
  validate_labels(self.analog_labels)
  let _ = ascii_bytes(self.units)
  for frame in self.frames {
    require(
      frame.points.length() == self.labels.length(),
      "point frame width mismatch",
    )
    require(
      frame.analog.length() == self.analog_per_frame,
      "analog subframe count mismatch",
    )
    for p in frame.points {
      require(
        finite(p.x) && finite(p.y) && finite(p.z) && finite(p.residual),
        "nonfinite point",
      )
      require(
        (p.residual == -1.0 || p.residual >= 0.0) &&
        p.cameras >= 0 &&
        p.cameras <= 127 &&
        (p.residual >= 0.0 || p.cameras == 0),
        "invalid residual/camera mask",
      )
    }
    for row in frame.analog {
      require(
        row.length() == self.analog_labels.length(),
        "analog row width mismatch",
      )
      for v in row {
        require(finite(v), "nonfinite analog sample")
      }
    }
  }
}

///|
fn validate_labels(labels : Array[String]) -> Unit raise C3dError {
  let seen : Map[String, Bool] = Map([])
  for label in labels {
    let b = ascii_bytes(label)
    require(
      b.length() > 0 && b.length() <= 255 && label.trim().to_owned() == label,
      "invalid channel label",
    )
    require(!seen.contains(label), "duplicate channel label")
    seen[label] = true
  }
}

///|
pub fn Trial::duration(self : Trial) -> Double {
  self.frames.length().to_double() / self.point_rate
}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Frame with @debug.Debug::{to_repr}

///|
pub extend Frame with Eq::{equal, not_equal}

///|
pub extend Trial with @debug.Debug::{to_repr}

///|
pub extend Trial with Eq::{equal, not_equal}
