extern crate cc;
use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let dparser_c_include_path = manifest_dir.join("../..");

    if !dparser_c_include_path.is_dir() {
        panic!(
            "dparser C include directory not found at: {}",
            dparser_c_include_path.display()
        );
    }
    let include_path_str = dparser_c_include_path.to_str().unwrap();

    println!("cargo:include={}", include_path_str);
    let path_to_make_dparser = PathBuf::from(env::var("OUT_DIR").unwrap()).join("make_dparser");
    println!("cargo:binary_path={}", path_to_make_dparser.display());
    // println!("cargo:rustc-link-search=native=../../");
    let project_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .to_path_buf();
    println!("cargo:rustc-link-search=native={}", project_root.display());
    println!("cargo:rustc-link-lib=static=dparse");
    let output = std::process::Command::new("make")
        .current_dir("../..")
        .output()
        .expect("Failed to execute make");

    if !output.status.success() {
        panic!(
            "make failed:\nstdout: {}\nstderr: {}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let src_path = project_root.join("make_dparser");
    let dest_path = out_dir.join("make_dparser");

    if src_path.exists() {
        fs::copy(&src_path, &dest_path).expect("Failed to copy make_dparser");
    } else {
        panic!("make_dparser not found at {:?}", src_path);
    }
}
