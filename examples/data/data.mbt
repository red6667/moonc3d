///|
pub fn sample() -> @moonc3d.Trial {
  let p : @moonc3d.Point = {
    x: 1.5,
    y: -2.0,
    z: 3.0,
    residual: 0.5,
    cameras: 3,
  }
  {
    first_frame: 7,
    point_rate: 100.0,
    analog_per_frame: 2,
    labels: ["heel", "toe"],
    analog_labels: ["Fx"],
    units: "mm",
    metadata: { groups: [], parameters: [], },
    frames: [
      {
        points: [p, { ..p, residual: -1.0, cameras: 0, }],
        analog: [[1.0], [2.0]],
      },
      { points: [{ ..p, x: 4.5, }, p], analog: [[3.0], [4.0]], },
    ],
  }
}
