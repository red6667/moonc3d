///|
fn validate_metadata(m : Metadata, limits : Limits) -> Unit raise C3dError {
  require(
    m.groups.length() + m.parameters.length() <= limits.max_parameters,
    "metadata record budget exceeded",
  )
  let groups : Map[String, Bool] = Map([])
  let ids : Map[Int32, Bool] = Map([])
  for g in m.groups {
    let name = ascii_bytes(g.name)
    require(
      g.id > 0 && g.id <= 127 && !ids.contains(g.id),
      "invalid or duplicate metadata group id",
    )
    require(
      name.length() > 0 &&
      name.length() <= 127 &&
      g.name.to_upper() == g.name &&
      !groups.contains(g.name),
      "metadata group names must be unique uppercase ASCII",
    )
    require(
      ascii_bytes(g.description).length() <= 255,
      "group description too long",
    )
    groups[g.name] = true
    ids[g.id] = true
  }
  let names : Map[String, Bool] = Map([])
  for p in m.parameters {
    require(groups.contains(p.group), "metadata parameter group missing")
    let name = ascii_bytes(p.name)
    let key = p.group + ":" + p.name
    require(
      name.length() > 0 &&
      name.length() <= 127 &&
      p.name.to_upper() == p.name &&
      !names.contains(key),
      "parameter names must be unique uppercase ASCII",
    )
    require(
      ascii_bytes(p.description).length() <= 255,
      "parameter description too long",
    )
    require(
      p.dimensions.length() <= 7 && p.data.length() <= 65500,
      "parameter payload too large",
    )
    if p.element_size == -1 {
      let _ = p.strings()
    } else {
      let _ = p.numbers()
    }
    names[key] = true
  }
}
