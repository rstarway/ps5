use mlua::Lua;
fn main() {
    let lua = Lua::new();
    let mut bad = 0;
    for path in std::env::args().skip(1) {
        let src = std::fs::read_to_string(&path).unwrap();
        match lua.load(&src).set_name(&path).into_function() {
            Ok(_) => {}
            Err(e) => { bad += 1; println!("{}", e); }
        }
    }
    println!("checked, {} errors", bad);
    std::process::exit(if bad > 0 { 1 } else { 0 });
}
