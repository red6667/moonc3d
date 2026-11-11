///|
test "CSV has explicit invalid samples and escaped channel labels" {
  let t = sample_trial().rename(points=["L,heel", "R\"heel"], analog=[
    "Fx", "EMG",
  ])
  let c = t.points_csv()
  assert_true(c.contains("\"L,heel\""))
  assert_true(c.contains("\"R\"\"heel\""))
  assert_true(c.contains(",false,,,,-1,0,"))
  assert_true(t.analog_csv().contains("8,1,0.015,\"EMG\",8"))
  assert_true(
    try {
      let _ = t.points_csv(max_rows=3)
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = t.analog_csv(max_rows=7)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    t.select(points=[], analog=[]).analog_csv(),
    "frame,subframe,time_s,channel,value\r\n",
  )
}
