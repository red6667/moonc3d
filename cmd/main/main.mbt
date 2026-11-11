///|
fn main {
  let args = @env.args()
  if args.length() != 1 {
    println(
      "{\"error\":\"pass one moonc3d/1 JSON request argument; see README\"}",
    )
  } else {
    println(@moonc3d.process_json(args[0])) catch {
      error =>
        println(
          Json::object({ "error": Json::string(@debug.to_string(error)) }).stringify(),
        )
    }
  }
}
