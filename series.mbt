///|
pub(all) struct MarkerSeries {
  label : String
  frame_numbers : Array[Int32]
  seconds : Array[Double]
  samples : Array[Point]
} derive(Debug, Eq)

///|
pub(all) struct AnalogSeries {
  label : String
  seconds : Array[Double]
  samples : Array[Double]
} derive(Debug, Eq)

///|
pub fn Trial::marker_series(
  self : Trial,
  label : String,
) -> MarkerSeries raise C3dError {
  self.validate()
  let i = channel_indices(self.labels, [label])[0]
  {
    label,
    frame_numbers: Array::makei(self.frames.length(), k => self.first_frame + k),
    seconds: Array::makei(self.frames.length(), k => {
      k.to_double() / self.point_rate
    }),
    samples: self.frames.map(f => f.points[i]),
  }
}

///|
pub fn Trial::analog_series(
  self : Trial,
  label : String,
) -> AnalogSeries raise C3dError {
  self.validate()
  let i = channel_indices(self.analog_labels, [label])[0]
  let count = self.frames.length() * self.analog_per_frame
  let rate = self.point_rate * self.analog_per_frame.to_double()
  {
    label,
    seconds: Array::makei(count, k => k.to_double() / rate),
    samples: Array::makei(count, k => {
      self.frames[k / self.analog_per_frame].analog[k % self.analog_per_frame][i]
    }),
  }
}

///|
pub extend MarkerSeries with @debug.Debug::{to_repr}

///|
pub extend MarkerSeries with Eq::{equal, not_equal}

///|
pub extend AnalogSeries with @debug.Debug::{to_repr}

///|
pub extend AnalogSeries with Eq::{equal, not_equal}
