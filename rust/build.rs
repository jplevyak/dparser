extern crate cc;
use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    
    // During cargo publish, parent might not have the files, but they are included in the package root
    let dparser_c_root = if manifest_dir.join("DParser.Makefile").exists() {
        manifest_dir.clone()
    } else {
        manifest_dir.join("..")
    };

    let makefile_name = if dparser_c_root.join("DParser.Makefile").exists() {
        "DParser.Makefile"
    } else {
        "Makefile"
    };

    if !dparser_c_root.join(makefile_name).exists() {
        panic!(
            "dparser C Makefile not found at: {}/{}",
            dparser_c_root.display(),
            makefile_name
        );
    }

    println!("cargo:include={}", dparser_c_root.to_str().unwrap());
    let path_to_make_dparser = PathBuf::from(env::var("OUT_DIR").unwrap()).join("make_dparser");
    println!("cargo:binary_path={}", path_to_make_dparser.display());

    // Copy C source to OUT_DIR to build there and avoid polluting the source tree
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let c_src_dir = out_dir.join("c_src");
    if !c_src_dir.exists() {
        fs::create_dir_all(&c_src_dir).unwrap();
    }

    // Copy necessary files to c_src_dir
    let files_to_copy = vec![makefile_name, "mkdep", "version.c"]; 
    for f in files_to_copy {
        let src = dparser_c_root.join(f);
        if src.exists() {
            let dest_name = if f == makefile_name { "Makefile" } else { f };
            fs::copy(&src, c_src_dir.join(dest_name)).unwrap();
        }
    }

    // Copy all .c, .h, .g files
    for entry in fs::read_dir(&dparser_c_root).unwrap() {
        let entry = entry.unwrap();
        let path = entry.path();
        if let Some(ext) = path.extension() {
            if ext == "c" || ext == "h" || ext == "g" {
                fs::copy(&path, c_src_dir.join(path.file_name().unwrap())).unwrap();
            }
        }
    }

    // Only build make_dparser and its dependencies in the OUT_DIR/c_src
    let output = std::process::Command::new("make")
        .arg("make_dparser")
        .current_dir(&c_src_dir)
        .output()
        .expect("Failed to execute make");

    if !output.status.success() {
        panic!(
            "make failed in {}:\nstdout: {}\nstderr: {}",
            c_src_dir.display(),
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let src_path = c_src_dir.join("make_dparser");
    let dest_path = out_dir.join("make_dparser");

    if src_path.exists() {
        fs::copy(&src_path, &dest_path).expect("Failed to copy make_dparser");

        let test_grammar = dparser_c_root.join("tests/g29.test.g");
        let test_bin = out_dir.join("test_grammar.bin");
        println!("cargo:rerun-if-changed={}", test_grammar.display());
        let gen_status = std::process::Command::new(&dest_path)
            .args([
                "-B",
                "-o",
                test_bin.to_str().unwrap(),
                test_grammar.to_str().unwrap(),
            ])
            .status()
            .expect("Failed to execute make_dparser for test tables");

        if !gen_status.success() {
            panic!("make_dparser failed to generate test binary tables");
        }
    } else {
        panic!("make_dparser not found at {:?}", src_path);
    }
}
