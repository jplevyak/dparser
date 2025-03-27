use clap::Parser;
use regex::Regex;
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::Path;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Input file
    #[arg(short, long)]
    source: String,

    /// Output file
    #[arg(short, long)]
    target: String,

    /// Globals type
    #[arg(short, long)]
    globals: String,

    /// Node type
    #[arg(short, long)]
    node: String,
}

const PARAMETERS: &str =
"(_ps: *mut c_void, _children: *mut *mut c_void, _n_children: i32, _offset: i32, _parser: *mut D_Parser *_parser) -> i32";

fn parse_file<P: AsRef<Path>>(
    input_path: P,
    output_path: P,
    globals_type: &str,
    node_type: &str,
) -> std::io::Result<()> {
    let file = File::open(input_path)?;
    let mut reader = BufReader::new(file);

    let mut output = String::new();
    let mut content = String::new();
    reader.read_to_string(&mut content)?;

    let globals = format!("d_globals<{}>()", globals_type);
    let user = format!(
        "d_user<{}>(d_pn(d_child_pn(_children, $1, _offset), _offset))",
        node_type
    );

    // Define regex patterns
    let global_code_regex = Regex::new(r#"^(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let header_regex = Regex::new(r#"^(\w+)\s+(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let dollar_var_regex = Regex::new(r"\$(\d+)").unwrap();
    let dollar_g_regex = Regex::new(r"\$g").unwrap();
    let dollar_n_regex = Regex::new(r"\$n(\d+)").unwrap();
    let dollar_dollar_regex = Regex::new(r"\$\$").unwrap();

    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        let line = lines[i];

        if i == 0 {
            // Handle global code
            if let Some(captures) = global_code_regex.captures(line) {
                let line_number = &captures[1].parse::<usize>().unwrap_or(0);
                let file_name = &captures[2];
                let line_count = &captures[3].parse::<usize>().unwrap_or(0);
                output.push_str(&format!("// line!({}, \"{}\")\n", line_number, file_name));
                while i < *line_count + 1 && i < lines.len() {
                    i += 1;
                    output.push_str(lines[i]);
                    output.push('\n');
                }
            }
            continue;
        }

        // Try to match the header line
        if let Some(captures) = header_regex.captures(line) {
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
                let body = dollar_var_regex
                    .replace_all(&body, user.clone())
                    .to_string();
                let body = dollar_g_regex
                    .replace_all(&body, globals.clone())
                    .to_string();
                let body = dollar_n_regex
                    .replace_all(&body, "d_pn(d_child_pn(_children, $1, _offset), _offset)")
                    .to_string();
                let body = dollar_dollar_regex.replace_all(&body, "d_pn(_ps, _offset)");

                // Create the Rust function
                let rust_function = format!(
                    "#[no_mangle]\npub extern \"C\" fn {}{} {{\n  // line!({}, \"{}\")\n{}}}\n\n",
                    function_name, PARAMETERS, line_number, file_name, body
                );

                output.push_str(&rust_function);
            }
        } else {
            eprintln!("Error: Bad header line '{}'", line);
            std::process::exit(1);
        }
    }

    // Write the output to a file
    std::fs::write(output_path, output)?;

    Ok(())
}

fn main() -> std::io::Result<()> {
    let args = Args::parse();

    let input_file = args.source;
    let output_file = args.target;
    let globals_type = args.globals;
    let node_type = args.node;

    if !Path::new(&input_file).exists() {
        eprintln!("Error: Input file '{}' not found.", input_file);
        std::process::exit(1);
    }

    parse_file(&input_file, &output_file, &globals_type, &node_type)
}
