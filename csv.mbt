///|
fn csv_text(out : StringBuilder, value : String) -> Unit {
  out.write_char('"')
  for c in value.iter() {
    if c == '"' {
      out.write_char('"')
    }
    out.write_char(c)
  }
  out.write_char('"')
}

///|
fn csv_budget(
  frames : Int32,
  samples : Int32,
  channels : Int32,
  max_rows : Int32,
) -> Unit raise C3dError {
  require(max_rows >= 0, "negative CSV row budget")
  require(
    channels == 0 ||
    (samples <= max_rows / channels && frames <= max_rows / channels / samples),
    "CSV row budget exceeded",
  )
}

// Long-form CSV: missing coordinates are empty, with valid=false and residual=-1.

///|
pub fn Trial::points_csv(
  self : Trial,
  max_rows~ : Int32 = 1000000,
) -> String raise C3dError {
  self.validate()
  csv_budget(self.frames.length(), 1, self.labels.length(), max_rows)
  let out = StringBuilder()
  out.write_string(
    "frame,time_s,label,valid,x,y,z,residual,camera_mask,units\r\n",
  )
  for i in 0..<self.frames.length() {
    for j in 0..<self.labels.length() {
      let p = self.frames[i].points[j]
      out.write_string(
        (self.first_frame + i).to_string() +
        "," +
        (i.to_double() / self.point_rate).to_string() +
        ",",
      )
      csv_text(out, self.labels[j])
      if p.residual < 0.0 {
        out.write_string(",false,,,,-1,0,")
      } else {
        out.write_string(
          ",true," +
          p.x.to_string() +
          "," +
          p.y.to_string() +
          "," +
          p.z.to_string() +
          "," +
          p.residual.to_string() +
          "," +
          p.cameras.to_string() +
          ",",
        )
      }
      csv_text(out, self.units)
      out.write_string("\r\n")
    }
  }
  out.to_string()
}

///|
pub fn Trial::analog_csv(
  self : Trial,
  max_rows~ : Int32 = 1000000,
) -> String raise C3dError {
  self.validate()
  csv_budget(
    self.frames.length(),
    self.analog_per_frame,
    self.analog_labels.length(),
    max_rows,
  )
  let out = StringBuilder()
  out.write_string("frame,subframe,time_s,channel,value\r\n")
  let rate = self.point_rate * self.analog_per_frame.to_double()
  for i in 0..<self.frames.length() {
    for s in 0..<self.analog_per_frame {
      for j in 0..<self.analog_labels.length() {
        let t = (i * self.analog_per_frame + s).to_double() / rate
        out.write_string(
          (self.first_frame + i).to_string() +
          "," +
          s.to_string() +
          "," +
          t.to_string() +
          ",",
        )
        csv_text(out, self.analog_labels[j])
        out.write_string("," + self.frames[i].analog[s][j].to_string() + "\r\n")
      }
    }
  }
  out.to_string()
}
