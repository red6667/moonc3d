///|
fn meters_per_unit(unit : String) -> Double raise C3dError {
  match unit {
    "m" => 1.0
    "cm" => 0.01
    "mm" => 0.001
    _ => raise Invalid("unsupported spatial unit: " + unit)
  }
}

// Analog samples remain in their independently calibrated units.

///|
pub fn Trial::convert_units(
  self : Trial,
  unit : String,
) -> Trial raise C3dError {
  self.validate()
  let ratio = meters_per_unit(self.units) / meters_per_unit(unit)
  let frames = self.frames.map(f => {
    ..f,
    points: f.points.map(p => {
      ..p,
      x: p.x * ratio,
      y: p.y * ratio,
      z: p.z * ratio,
      residual: if p.residual < 0.0 {
        -1.0
      } else {
        p.residual * ratio
      },
    }),
  })
  let out = { ..self, units: unit, frames, }
  out.validate()
  out
}

// Right handed rigid transform: row-major 3x3 rotation, translation in trial units.
// Orthonormality and positive determinant are required; residuals retain their meaning.

///|
pub fn Trial::transform(
  self : Trial,
  rotation : Array[Double],
  translation : Array[Double],
) -> Trial raise C3dError {
  self.validate()
  require(
    rotation.length() == 9 && translation.length() == 3,
    "rigid transform shape mismatch",
  )
  for v in rotation {
    require(finite(v), "nonfinite rotation")
  }
  for v in translation {
    require(finite(v), "nonfinite translation")
  }
  for i in 0..<3 {
    for j in 0..<3 {
      let mut dot = 0.0
      for k in 0..<3 {
        dot += rotation[i * 3 + k] * rotation[j * 3 + k]
      }
      let expected = if i == j { 1.0 } else { 0.0 }
      require(
        (dot - expected).abs() <= 0.0000001,
        "rotation is not orthonormal",
      )
    }
  }
  let r = rotation
  let det = r[0] * (r[4] * r[8] - r[5] * r[7]) -
    r[1] * (r[3] * r[8] - r[5] * r[6]) +
    r[2] * (r[3] * r[7] - r[4] * r[6])
  require((det - 1.0).abs() <= 0.0000001, "rotation must preserve handedness")
  let out = {
    ..self,
    frames: self.frames.map(f => {
      ..f,
      points: f.points.map(p => {
        if p.residual < 0.0 {
          p
        } else {
          {
            ..p,
            x: r[0] * p.x + r[1] * p.y + r[2] * p.z + translation[0],
            y: r[3] * p.x + r[4] * p.y + r[5] * p.z + translation[1],
            z: r[6] * p.x + r[7] * p.y + r[8] * p.z + translation[2],
          }
        }
      }),
    }),
  }
  out.validate()
  out
}
