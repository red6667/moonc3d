///|
pub(all) struct MarkerQuality {
  label : String
  valid : Int32
  missing : Int32
  longest_gap : Int32
  minimum : Array[Double]?
  maximum : Array[Double]?
  mean_residual : Double?
} derive(Debug, Eq)

///|
pub(all) struct AnalogQuality {
  label : String
  count : Int32
  minimum : Double
  maximum : Double
  mean : Double
} derive(Debug, Eq)

// Bounds exclude missing points. None denotes no valid observations.

///|
pub fn Trial::marker_quality(
  self : Trial,
) -> Array[MarkerQuality] raise C3dError {
  self.validate()
  let out = []
  for i in 0..<self.labels.length() {
    let low = [0.0, 0.0, 0.0]
    let high = [0.0, 0.0, 0.0]
    let mut valid = 0
    let mut run = 0
    let mut longest_gap = 0
    let mut residual = 0.0
    for f in self.frames {
      let p = f.points[i]
      if p.residual < 0.0 {
        run += 1
        if run > longest_gap {
          longest_gap = run
        }
      } else {
        let xyz = [p.x, p.y, p.z]
        for k in 0..<3 {
          if valid == 0 || xyz[k] < low[k] {
            low[k] = xyz[k]
          }
          if valid == 0 || xyz[k] > high[k] {
            high[k] = xyz[k]
          }
        }
        valid += 1
        residual += (p.residual - residual) / valid.to_double()
        run = 0
      }
    }
    out.push({
      label: self.labels[i],
      valid,
      missing: self.frames.length() - valid,
      longest_gap,
      minimum: if valid == 0 {
        None
      } else {
        Some(low)
      },
      maximum: if valid == 0 {
        None
      } else {
        Some(high)
      },
      mean_residual: if valid == 0 {
        None
      } else {
        Some(residual)
      },
    })
  }
  out
}

///|
pub fn Trial::analog_quality(
  self : Trial,
) -> Array[AnalogQuality] raise C3dError {
  self.validate()
  let out = []
  for i in 0..<self.analog_labels.length() {
    let mut count = 0
    let mut low = 0.0
    let mut high = 0.0
    let mut mean = 0.0
    for f in self.frames {
      for row in f.analog {
        let v = row[i]
        if count == 0 || v < low {
          low = v
        }
        if count == 0 || v > high {
          high = v
        }
        count += 1
        // Weighted form avoids overflow from subtracting opposite extreme values.
        let n = count.to_double()
        mean = mean * ((n - 1.0) / n) + v / n
      }
    }
    require(finite(mean), "analog mean overflow")
    out.push({
      label: self.analog_labels[i],
      count,
      minimum: low,
      maximum: high,
      mean,
    })
  }
  out
}
