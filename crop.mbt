// Frame windows are zero-based, half-open; original C3D frame numbers survive cropping.
///|
pub fn Trial::crop(
  self : Trial,
  start : Int32,
  end : Int32,
) -> Trial raise C3dError {
  self.validate()
  require(
    start >= 0 && end > start && end <= self.frames.length(),
    "invalid frame window",
  )
  {
    ..self,
    first_frame: self.first_frame + start,
    frames: Array::makei(end - start, i => self.frames[start + i]),
  }
}

// Timestamp zero denotes the first stored point frame, independent of first_frame.

///|
pub fn Trial::frame_time(self : Trial, index : Int32) -> Double raise C3dError {
  require(
    index >= 0 && index < self.frames.length(),
    "frame index out of range",
  )
  index.to_double() / self.point_rate
}

// Select frames whose sample timestamps lie in [start_seconds, end_seconds).

///|
pub fn Trial::time_window(
  self : Trial,
  start_seconds : Double,
  end_seconds : Double,
) -> Trial raise C3dError {
  self.validate()
  require(
    finite(start_seconds) &&
    finite(end_seconds) &&
    start_seconds >= 0.0 &&
    end_seconds > start_seconds &&
    end_seconds <= self.duration(),
    "invalid time window",
  )
  let start = (start_seconds * self.point_rate).ceil().to_int()
  let end = (end_seconds * self.point_rate).ceil().to_int()
  self.crop(start, end)
}
