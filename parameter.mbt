///|
pub(all) struct Parameter {
  group : String
  name : String
  description : String
  locked : Bool
  element_size : Int32
  dimensions : Array[Int32]
  data : Bytes
  big_endian : Bool
} derive(Debug, Eq)

///|
pub(all) struct Group {
  id : Int32
  name : String
  description : String
  locked : Bool
} derive(Debug, Eq)

///|
pub(all) struct Metadata {
  groups : Array[Group]
  parameters : Array[Parameter]
} derive(Debug, Eq)

///|
pub fn Metadata::find(
  self : Metadata,
  group : String,
  name : String,
) -> Parameter? {
  for p in self.parameters {
    if p.group == group.to_upper() && p.name == name.to_upper() {
      return Some(p)
    }
  }
  None
}

///|
pub fn Parameter::numbers(self : Parameter) -> Array[Double] raise C3dError {
  require(
    self.element_size == 1 || self.element_size == 2 || self.element_size == 4,
    "parameter is not numeric",
  )
  let n = product(self.dimensions, 16777216)
  require(
    n <= self.data.length() / self.element_size &&
    n * self.element_size == self.data.length(),
    "parameter shape mismatch",
  )
  let c = Cursor::new(self.data, 0, self.data.length(), self.big_endian)
  let out = []
  for _ in 0..<n {
    let x = if self.element_size == 1 {
      c.i8().to_double()
    } else if self.element_size == 2 {
      c.i16().to_double()
    } else {
      c.f32()
    }
    require(finite(x), "nonfinite numeric parameter")
    out.push(x)
  }
  out
}

///|
pub fn Parameter::strings(self : Parameter) -> Array[String] raise C3dError {
  require(
    self.element_size == -1 && self.dimensions.length() > 0,
    "parameter is not a string array",
  )
  let n = product(self.dimensions, 16777216)
  require(n == self.data.length(), "string parameter shape mismatch")
  let width = self.dimensions[0]
  require(width > 0, "zero string width")
  let out = []
  for row in 0..<(n / width) {
    let b = Bytes::makei(width, i => self.data[row * width + i])
    out.push(ascii(b).trim().to_owned())
  }
  out
}

///|
fn scalar(
  m : Metadata,
  g : String,
  name : String,
  default : Double,
) -> Double raise C3dError {
  match m.find(g, name) {
    None => default
    Some(p) => {
      let a = p.numbers()
      require(a.length() == 1, "expected scalar parameter")
      a[0]
    }
  }
}

// Some legacy C3D header-compatible counters store unsigned values in int16 parameters.

///|
fn counter(
  m : Metadata,
  name : String,
  default : Double,
) -> Double raise C3dError {
  let x = scalar(m, "POINT", name, default)
  match m.find("POINT", name) {
    Some(p) if p.element_size == 2 && x < 0.0 => x + 65536.0
    _ => x
  }
}

///|
pub extend Parameter with @debug.Debug::{to_repr}

///|
pub extend Parameter with Eq::{equal, not_equal}

///|
pub extend Group with @debug.Debug::{to_repr}

///|
pub extend Group with Eq::{equal, not_equal}

///|
pub extend Metadata with @debug.Debug::{to_repr}

///|
pub extend Metadata with Eq::{equal, not_equal}
