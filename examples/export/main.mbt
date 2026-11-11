///|
fn main raise {
  let t = @data.sample()
  let points = t.points_csv()
  let analog = t.analog_csv()
  assert_true(points.contains(",false,,,,-1,0,"))
  assert_eq(t.analog_series("Fx").samples, [1.0, 2.0, 3.0, 4.0])
  assert_true(analog.contains("8,1,0.015"))
  assert_eq(t.analog_quality()[0].mean, 2.5)
  println("export: quoted CSV, timestamps, marker gaps and analog summaries")
}
