///|
pub fn read_metadata(
  bytes : Bytes,
  limits~ : Limits = Limits::default(),
) -> Metadata raise C3dError {
  let h = read_header(bytes, limits~)
  let start = (h.parameter_block - 1) * 512
  let blocks = bytes[start + 2].to_int()
  require(
    blocks > 0 && start + blocks * 512 <= (h.data_block - 1) * 512,
    "parameter blocks overlap data",
  )
  let end = start + blocks * 512
  let c = Cursor::new(bytes, start + 4, end, h.processor == 86)
  let groups : Array[Group] = []
  let pending : Array[(Int32, Parameter)] = []
  let mut count = 0
  while c.pos + 2 <= end {
    let nchars = c.i8()
    let gid = c.i8()
    if nchars == 0 || gid == 0 {
      break
    }
    require(nchars != -128 && gid != -128, "invalid signed record identifier")
    count += 1
    require(count <= limits.max_parameters, "metadata record budget exceeded")
    let name = ascii(c.take(nchars.abs())).to_upper()
    require(name.length() > 0, "empty metadata name")
    let offset_pos = c.pos
    let offset = c.u16()
    require(
      offset == 0 || (offset >= 2 && offset <= end - offset_pos),
      "invalid record offset",
    )
    let next = if offset == 0 { end } else { offset_pos + offset }
    let r = Cursor::new(bytes, c.pos, next, h.processor == 86)
    if gid < 0 {
      require(
        !groups.iter().any(g => g.id == -gid || g.name == name),
        "duplicate group",
      )
      let desc_len = r.u8()
      let description = ascii(r.take(desc_len))
      groups.push({ id: -gid, name, description, locked: nchars < 0, })
    } else {
      let element_size = r.i8()
      require(
        element_size == -1 ||
        element_size == 1 ||
        element_size == 2 ||
        element_size == 4,
        "unsupported parameter type",
      )
      let ndim = r.u8()
      require(ndim <= 7, "too many parameter dimensions")
      let dims = []
      for _ in 0..<ndim {
        dims.push(r.u8())
      }
      let n = product(dims, limits.max_bytes / element_size.abs())
      let data = r.take(n * element_size.abs())
      let desc_len = r.u8()
      let description = ascii(r.take(desc_len))
      require(
        !pending.iter().any(x => x.0 == gid && x.1.name == name),
        "duplicate parameter",
      )
      pending.push(
        (
          gid,
          {
            group: "",
            name,
            description,
            locked: nchars < 0,
            element_size,
            dimensions: dims,
            data,
            big_endian: h.processor == 86,
          },
        ),
      )
    }
    c.pos = next
    if offset == 0 {
      break
    }
  }
  let parameters = []
  for (gid, p) in pending {
    let mut group_name = ""
    for g in groups {
      if g.id == gid {
        group_name = g.name
      }
    }
    require(group_name != "", "parameter references missing group")
    parameters.push({ ..p, group: group_name, })
  }
  { groups, parameters, }
}
