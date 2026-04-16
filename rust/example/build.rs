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

    let grammar_file = manifest_dir.join("src").join("my_grammar.g");

    // Define intermediate and final output paths within OUT_DIR
    let c_output = out_dir.join("my_grammar.g.d_parser.bin");
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
        .arg(&grammar_file)
        .arg("-B") // Output binary tables
        .arg("-X") // Change extension to .bin
        .arg("bin")
        .arg("-o")
        .arg(&c_output)
        .arg("-a") // Actions output
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

    eprintln!("Generated parser code at: {:?}", rust_output);
    eprintln!("Generated binary tables at: {:?}", c_output);

    Ok(())
}
