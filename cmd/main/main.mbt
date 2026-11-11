///|
#cfg(target="js")
fn argument_offset() -> Int32 {
  2
}

///|
#cfg(not(target="js"))
fn argument_offset() -> Int32 {
  1
}

///|
fn main raise {
  let args = @env.args()
  if args.length() != argument_offset() + 1 {
    println(
      "{\"error\":\"pass one moonc3d/1 JSON request argument; see README\"}",
    )
    fail("invalid command arguments")
  } else {
    println(@moonc3d.process_json(args[argument_offset()])) catch {
      error => {
        println(
          Json::object({ "error": Json::string(@debug.to_string(error)) }).stringify(),
        )
        raise error
      }
    }
  }
}
