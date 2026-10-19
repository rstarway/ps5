use mlua::{Lua, Table, Value, Function};
fn main() -> mlua::Result<()> {
    let lua = Lua::new();
    let g = lua.globals();
    g.set("readfile", lua.create_function(|_, p: String| Ok(std::fs::read_to_string(p).ok()))?)?;
    g.set("compile", lua.create_function(|lua, (src, name, env): (String, String, Table)| {
        let f: Function = lua.load(&src).set_name(&name).set_environment(env).into_function()?;
        Ok(f)
    })?)?;
    g.set("listdir", lua.create_function(|lua, p: String| {
        let t = lua.create_table()?;
        let mut entries: Vec<_> = std::fs::read_dir(&p).map(|r| r.filter_map(|e| e.ok()).collect()).unwrap_or_default();
        entries.sort_by_key(|e| e.file_name());
        for (i, e) in entries.iter().enumerate() {
            let row = lua.create_table()?;
            row.set("name", e.file_name().to_string_lossy().to_string())?;
            row.set("dir", e.path().is_dir())?;
            t.set(i + 1, row)?;
        }
        Ok(t)
    })?)?;
    let args: Vec<String> = std::env::args().collect();
    g.set("ARGS", args.clone())?;
    let path = args.get(1).expect("usage: luaurun <script.lua> [args]").clone();
    let src = std::fs::read_to_string(&path).unwrap();
    let r: mlua::Result<Value> = lua.load(&src).set_name(&path).eval();
    if let Err(e) = r { println!("FATAL: {}", e); std::process::exit(1); }
    Ok(())
}
