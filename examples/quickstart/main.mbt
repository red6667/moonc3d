///|
fn main raise {
  let trial : @moonc3d.Trial = {
    first_frame: 7,
    point_rate: 100.0,
    analog_per_frame: 2,
    labels: ["heel"],
    analog_labels: ["Fx"],
    units: "mm",
    metadata: { groups: [], parameters: [], },
    frames: [
      {
        points: [{ x: 1.5, y: -2.0, z: 3.0, residual: 0.5, cameras: 3, }],
        analog: [[1.0], [2.0]],
      },
    ],
  }
  let bytes = @moonc3d.write(trial, residual_scale=0.5)
  let restored = @moonc3d.read(bytes)
  assert_eq(restored.first_frame, 7)
  assert_eq(restored.analog_series("Fx").samples, [1.0, 2.0])
  println(restored.points_csv())
}
