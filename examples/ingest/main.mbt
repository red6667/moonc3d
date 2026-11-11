///|
fn main raise {
  let bytes = @moonc3d.write(@data.sample(), residual_scale=0.5)
  let layout = @moonc3d.inspect(bytes)
  let trial = @moonc3d.read(bytes)
  assert_eq(layout.header.processor, 84)
  assert_eq(trial.marker_series("heel").seconds, [0.0, 0.01])
  assert_eq(trial.marker_quality()[1].missing, 1)
  println("ingest: 2 frames, synchronized analog, missing marker detected")
}
