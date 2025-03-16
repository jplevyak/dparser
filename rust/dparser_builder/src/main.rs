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
}

fn parse_file<P: AsRef<Path>>(input_path: P, output_path: P) -> std::io::Result<()> {
    let file = File::open(input_path)?;
    let mut reader = BufReader::new(file);

    let mut output = String::new();
    let mut content = String::new();
    reader.read_to_string(&mut content)?;

    // Define regex patterns
    let header_regex = Regex::new(r#"^(\w+)\s+(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let dollar_var_regex = Regex::new(r"\$(\d+)").unwrap();
    let dollar_g_regex = Regex::new(r"\$g").unwrap();
    let dollar_n_regex = Regex::new(r"\$n(\d+)").unwrap();

    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        let line = lines[i];

        // Try to match the header line
        if let Some(captures) = header_regex.captures(line) {
            let function_name = &captures[1];
            let line_number = &captures[2].parse::<usize>().unwrap_or(0);
            let file_name = &captures[3];
            let char_count = &captures[4].parse::<usize>().unwrap_or(0);

            i += 1; // Move to the next line (body starts here)

            if i < lines.len() {
                // Read the body, which might span multiple lines
                let mut body = String::new();
                let mut chars_read = 0;

                while i < lines.len() && chars_read < *char_count {
                    let current_line = lines[i];
                    body.push_str(current_line);
                    body.push('\n');
                    chars_read += current_line.len() + 1; // +1 for the newline
                    i += 1;

                    // If we've read enough characters, or hit another header, break
                    if chars_read >= *char_count
                        || (i < lines.len() && header_regex.is_match(lines[i]))
                    {
                        break;
                    }
                }
                // Transform the body
                let body = dollar_var_regex
                    .replace_all(&body, "ParseNode($1)")
                    .to_string();
                let body = dollar_g_regex.replace_all(&body, "Globals()").to_string();
                let body = dollar_n_regex.replace_all(&body, "Node($1)");

                // Create the Rust function
                let rust_function = format!(
                    "fn {}() {{\n  // line!({}, \"{}\")\n{}}}\n\n",
                    function_name, line_number, file_name, body
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

    if !Path::new(&input_file).exists() {
        eprintln!("Error: Input file '{}' not found.", input_file);
        std::process::exit(1);
    }

    parse_file(&input_file, &output_file)
}
