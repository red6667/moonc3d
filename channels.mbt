///|
fn channel_indices(
  available : Array[String],
  requested : Array[String],
) -> Array[Int32] raise C3dError {
  validate_labels(requested)
  let indices = []
  for label in requested {
    let mut found = -1
    for i in 0..<available.length() {
      if available[i] == label {
        found = i
        break
      }
    }
    require(found >= 0, "unknown channel: " + label)
    indices.push(found)
  }
  indices
}

// Selection also reorders channels. Empty lists explicitly remove a channel family.

///|
pub fn Trial::select(
  self : Trial,
  points~ : Array[String],
  analog~ : Array[String],
) -> Trial raise C3dError {
  self.validate()
  let pi = channel_indices(self.labels, points)
  let ai = channel_indices(self.analog_labels, analog)
  let frames = self.frames.map(f => {
    points: pi.map(i => f.points[i]),
    analog: if ai.length() == 0 {
      []
    } else {
      f.analog.map(row => ai.map(i => row[i]))
    },
  })
  {
    ..self,
    labels: points.copy(),
    analog_labels: analog.copy(),
    analog_per_frame: if ai.length() == 0 {
      0
    } else {
      self.analog_per_frame
    },
    frames,
  }
}

///|
pub fn Trial::rename(
  self : Trial,
  points~ : Array[String],
  analog~ : Array[String],
) -> Trial raise C3dError {
  self.validate()
  require(
    points.length() == self.labels.length() &&
    analog.length() == self.analog_labels.length(),
    "rename must keep channel counts",
  )
  validate_labels(points)
  validate_labels(analog)
  { ..self, labels: points.copy(), analog_labels: analog.copy(), }
}
