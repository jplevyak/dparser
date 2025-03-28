use regex::Regex;
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::PathBuf;

pub fn build_actions(
    input_path: &PathBuf,
    output_path: &PathBuf,
    globals_type: &str,
    node_type: &str,
) -> std::io::Result<()> {
    const PARAMETERS: &str = "(_ps: *mut c_void, _children: *mut *mut c_void, _n_children: i32, _offset: i32, _parser: *mut D_Parser) -> i32";
    let file = File::open(input_path)?;
    let mut reader = BufReader::new(file);

    let mut output = String::new();
    let mut content = String::new();
    reader.read_to_string(&mut content)?;

    let globals = format!("d_globals::<{}>(_parser).unwrap()", globals_type);
    let child_user = format!(
        "d_user::<{}>(d_pn_ptr(d_child_pn_ptr(_children, $1), _offset)).unwrap()",
        node_type
    );
    let user = format!("d_user::<{}>(d_pn_ptr(_ps, _offset)).unwrap()", node_type);

    output.push_str(
        r#"
use dparser_lib::bindings::*;
use dparser_lib::{d_globals, d_child_pn_ptr, d_pn, d_pn_ptr, d_user};
use std::os::raw::c_void;
        "#,
    );

    // Define regex patterns
    let global_code_regex = Regex::new(r#"^(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let header_regex = Regex::new(r#"^(\w+)\s+(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let dollar_child_regex = Regex::new(r"\$(\d+)").unwrap();
    let dollar_g_regex = Regex::new(r"\$g").unwrap();
    let dollar_n_child_regex = Regex::new(r"\$n(\d+)").unwrap();
    let dollar_n_regex = Regex::new(r"\$n").unwrap();
    let dollar_dollar_regex = Regex::new(r"\$\$").unwrap();

    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        if i == 0 {
            // Handle global code
            if let Some(captures) = global_code_regex.captures(lines[i]) {
                let line_number = &captures[1].parse::<usize>().unwrap_or(0);
                let file_name = &captures[2];
                let line_count = &captures[3].parse::<usize>().unwrap_or(0);
                output.push_str(&format!("// line!({}, \"{}\")\n", line_number, file_name));
                while i < *line_count && i < lines.len() {
                    i += 1;
                    output.push_str(lines[i]);
                    output.push('\n');
                }
                i += 1;
            }
            continue;
        }

        // Try to match the header line
        if let Some(captures) = header_regex.captures(lines[i]) {
            let function_name = &captures[1];
            let line_number = &captures[2].parse::<usize>().unwrap_or(0);
            let file_name = &captures[3];
            let line_count = &captures[4].parse::<usize>().unwrap_or(0);

            i += 1; // Move to the next line (body starts here)

            if i < lines.len() {
                // Read the body, which might span multiple lines
                let mut body = String::new();
                let start_line = i;

                while i < lines.len() && i - start_line < *line_count {
                    body.push_str(lines[i]);
                    body.push('\n');
                    i += 1;
                }
                // Transform the body
                let body = dollar_child_regex
                    .replace_all(&body, child_user.clone())
                    .to_string();
                let body = dollar_g_regex
                    .replace_all(&body, globals.clone())
                    .to_string();
                let body = dollar_n_child_regex
                    .replace_all(
                        &body,
                        "d_pn(d_child_pn_ptr(_children, $1), _offset).unwrap()",
                    )
                    .to_string();
                let body = dollar_n_regex
                    .replace_all(&body, "d_pn(_ps, _offset).unwrap()")
                    .to_string();
                let body = dollar_dollar_regex
                    .replace_all(&body, user.clone())
                    .to_string();

                // Create the Rust function
                let rust_function = format!(
                    "#[unsafe(no_mangle)]\npub extern \"C\" fn {}{} {{\n  // line!({}, \"{}\")\n{} 0 }}\n\n",
                    function_name, PARAMETERS, line_number, file_name, body
                );

                output.push_str(&rust_function);
            }
        } else {
            eprintln!("Error: Bad header line '{}'", lines[i]);
            std::process::exit(1);
        }
    }

    // Write the output to a file
    std::fs::write(output_path, output)?;

    Ok(())
}
