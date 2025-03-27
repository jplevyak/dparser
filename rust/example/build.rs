// examples/dparser_example/build.rs

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=src/my_grammar.g");
    println!("cargo:rerun-if-changed=build.rs");

    // 1. Get necessary paths
    let out_dir = PathBuf::from(env::var("OUT_DIR")?);
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?);
    let dparser_c_include_path = env::var("DEP_DPARSE_INCLUDE")
        .expect("DEP_DPARSE_INCLUDE not set by dparser_lib build script.");
    println!("cargo:rerun-if-env-changed=DEP_DPARSE_INCLUDE");

    let grammar_file = manifest_dir.join("src").join("my_grammar.g");

    // Define intermediate and final output paths within OUT_DIR
    let c_output = out_dir.join("my_grammar.g.d_parser.c");
    let intermediate_output = out_dir.join("my_grammar.actions");
    let rust_output = out_dir.join("actions.rs");

    // 2. Run make_dparser (C parser generator)
    eprintln!(
        "Running make_dparser: {:?} -> {:?}",
        grammar_file, intermediate_output
    );

    let make_dparser_path = env::var("DEP_DPARSE_BINARY_PATH")
        .map(PathBuf::from)
        .expect("DEP_DPARSE_BINARY_PATH not set by dparser_lib build script. Make sure dparser_lib is a dependency.");

    let make_dparser_status = Command::new(&make_dparser_path)
        .arg(grammar_file)
        .arg("-o") // output
        .arg(&c_output)
        .arg("-a") // source
        .arg(&intermediate_output)
        .status()?;

    if !make_dparser_status.success() {
        return Err(format!("make_dparser failed with status: {}", make_dparser_status).into());
    }

    // 3. Run dparser_builder (Rust code generator)
    eprintln!(
        "Running dparser_builder: {:?} -> {:?}",
        intermediate_output, rust_output
    );

    dparser_lib::build_actions(
        &intermediate_output,
        &rust_output,
        "GlobalsStruct",
        "NodeStruct",
    )?;

    // 4. Compile the generated C code using the cc crate
    eprintln!("Compiling generated C code: {:?}", c_output);
    cc::Build::new()
        .file(&c_output) // Compile this C file
        .include(&dparser_c_include_path) // Add dparser's include path
        // Add any other include paths needed by the generated C code
        // .include("some/other/path")
        // Add any necessary C definitions
        // .define("SOME_MACRO", "1")
        .warnings(false)
        .opt_level(2) // Set optimization level if needed
        .try_compile("parser_tables")?; // Compile into libparser_tables.a (or .lib) and link it

    eprintln!("Generated parser code at: {:?}", rust_output);
    eprintln!("Compiled and linked C code from: {:?}", c_output);

    Ok(())
}
