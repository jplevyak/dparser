// integration_tests/build.rs
use std::env;
use std::path::{Path, PathBuf};
use std::fs;

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let grammars_dir = Path::new("grammars");

    if !grammars_dir.exists() {
        return;
    }

    // Tell cargo to rerun if grammar files change
    println!("cargo:rerun-if-changed=grammars");

    for entry in fs::read_dir(grammars_dir).unwrap() {
        let entry = entry.unwrap();
        let path = entry.path();
        
        if path.extension().unwrap_or_default() == "g" {
            let file_name = path.file_name().unwrap().to_str().unwrap();
            let base_name = file_name.trim_end_matches(".g");
            
            let bin_output = out_dir.join(format!("{}.d_parser.bin", path.file_name().unwrap().to_str().unwrap()));
            let actions_output = out_dir.join(format!("{}.actions", base_name));
            
            // Execute standard DParser compiler
            let status = std::process::Command::new("../../make_dparser")
                .arg(&path)
                .arg("-B")
                .arg("-X").arg("bin")
                .arg("-o").arg(&bin_output)
                .arg("-a").arg(&actions_output)
                .status()
                .expect("Failed to execute make_dparser");

            if !status.success() {
                panic!("make_dparser failed on {:?}", path);
            }

            // Map macros cleanly via builder.rs dynamically using the explicit actions output
            let action_path = out_dir.join(format!("{}_actions.rs", base_name));
            dparser::builder::build_actions(
                &actions_output,
                &action_path,
                "GlobalsStruct",
                "NodeStruct",
            ).unwrap_or_else(|_| panic!("Failed mapping actions for {:?}", path));
        }
    }
}
