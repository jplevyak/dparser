use std::fs::File;
use std::io::{BufReader, Read};
use std::path::PathBuf;

// Function to process the action body, respecting comments and strings
fn process_body(
    body: &str,
    globals_replacement: &str,
    child_user_replacement_fmt: &str, // format string expecting index {} and node_type NODE_TYPE
    user_replacement: &str,
    child_node_replacement_fmt: &str, // format string expecting index {}
    node_replacement: &str,
    node_type: &str, // Added node_type for $X[Y] user data access
) -> String {
    let mut output = String::new();
    let mut chars = body.chars().peekable();
    enum State {
        Code,
        LineComment,
        BlockComment,
        String,
        Char,
    }
    let mut state = State::Code;

    while let Some(&c) = chars.peek() {
        match state {
            State::Code => {
                match c {
                    '/' => {
                        chars.next(); // consume '/'
                        if let Some(&next_c) = chars.peek() {
                            if next_c == '/' {
                                chars.next(); // consume '/'
                                output.push_str("//");
                                state = State::LineComment;
                            } else if next_c == '*' {
                                chars.next(); // consume '*'
                                output.push_str("/*");
                                state = State::BlockComment;
                            } else {
                                output.push('/');
                            }
                        } else {
                            output.push('/');
                        }
                    }
                    '"' => {
                        // Basic string handling
                        chars.next();
                        output.push('"');
                        state = State::String;
                    }
                    '\'' => {
                        // Basic char handling
                        chars.next();
                        output.push('\'');
                        state = State::Char;
                    }
                    '$' => {
                        chars.next(); // consume '$'
                        if let Some(&next_c) = chars.peek() {
                            match next_c {
                                '#' => {
                                    chars.next(); // consume '#'
                                    if chars.peek().map_or(false, |c| c.is_ascii_digit()) {
                                        // Handle $#X
                                        let mut digits = String::new();
                                        while let Some(&d) = chars.peek() {
                                            if d.is_ascii_digit() {
                                                chars.next(); // consume digit
                                                digits.push(d);
                                            } else {
                                                break;
                                            }
                                        }
                                        // First, get the replacement for $nX
                                        let node_replacement =
                                            child_node_replacement_fmt.replace("{}", &digits);
                                        // Then wrap it with d_get_number_of_children
                                        let final_replacement = format!(
                                            "d_get_number_of_children({})",
                                            node_replacement
                                        );
                                        output.push_str(&final_replacement);
                                    } else {
                                        // Handle $#
                                        output.push_str("(_n_children)");
                                    }
                                }
                                '$' => {
                                    chars.next(); // consume '$'
                                    output.push_str(user_replacement);
                                }
                                'g' => {
                                    chars.next(); // consume 'g'
                                    output.push_str(globals_replacement);
                                }
                                'n' => {
                                    chars.next(); // consume 'n'
                                    let mut digits = String::new();
                                    while let Some(&d) = chars.peek() {
                                        if d.is_ascii_digit() {
                                            chars.next(); // consume digit
                                            digits.push(d);
                                        } else {
                                            break;
                                        }
                                    }
                                    if digits.is_empty() {
                                        output.push_str(node_replacement);
                                    } else {
                                        // Check for '*' after $nX for iterator
                                        if chars.peek() == Some(&'*') {
                                            chars.next(); // consume '*'
                                            let replacement = format!(
                                                "d_children_nodes(_children, {}, _offset)",
                                                digits
                                            );
                                            output.push_str(&replacement);
                                        } else {
                                            // Regular $nX (node access)
                                            let replacement =
                                                child_node_replacement_fmt.replace("{}", &digits);
                                            output.push_str(&replacement);
                                        }
                                    }
                                }
                                d if d.is_ascii_digit() => {
                                    let mut digits = String::new();
                                    while let Some(&d) = chars.peek() {
                                        if d.is_ascii_digit() {
                                            chars.next(); // consume digit
                                            digits.push(d);
                                        } else {
                                            break;
                                        }
                                    }
                                    let digits_x = digits; // Keep original digits

                                    // Check for '*' after $X for iterator
                                    if chars.peek() == Some(&'*') {
                                        chars.next(); // consume '*'
                                        let replacement = format!(
                                            "d_children_user::<{}>(_children, {}, _offset)",
                                            node_type, // Use the passed-in node_type
                                            digits_x
                                        );
                                        output.push_str(&replacement);
                                    } else {
                                        // Regular $X (accessing user data of child X)
                                        let replacement =
                                            child_user_replacement_fmt.replace("{}", &digits_x);
                                        output.push_str(&replacement);
                                    }
                                }
                                '{' => {
                                    chars.next(); // consume '{'
                                    let mut keyword = String::new();
                                    while let Some(&k) = chars.peek() {
                                        if k.is_alphabetic() {
                                            chars.next(); // consume char
                                            keyword.push(k);
                                        } else {
                                            break;
                                        }
                                    }
                                    if keyword == "reject" && chars.peek() == Some(&'}') {
                                        chars.next(); // consume '}'
                                        output.push_str(" return -1; ");
                                    } else {
                                        // Not a recognized keyword, push back the consumed chars
                                        output.push('$');
                                        output.push('{');
                                        output.push_str(&keyword);
                                    }
                                }
                                _ => {
                                    output.push('$'); // Just a dollar sign, not a recognized variable
                                }
                            }
                        } else {
                            output.push('$'); // End of input after '$'
                        }
                    }
                    _ => {
                        // Any other character
                        chars.next();
                        output.push(c);
                    }
                }
            }
            State::LineComment => {
                chars.next();
                output.push(c);
                if c == '\n' {
                    state = State::Code;
                }
            }
            State::BlockComment => {
                chars.next();
                output.push(c);
                if c == '*' {
                    if let Some('/') = chars.peek() {
                        chars.next();
                        output.push('/');
                        state = State::Code;
                    }
                }
            }
            State::String => {
                chars.next();
                output.push(c);
                if c == '\\' {
                    // Handle basic escape sequence
                    if let Some(&next_c) = chars.peek() {
                        chars.next();
                        output.push(next_c);
                    }
                } else if c == '"' {
                    state = State::Code;
                }
            }
            State::Char => {
                chars.next();
                output.push(c);
                if c == '\\' {
                    // Handle basic escape sequence
                    if let Some(&next_c) = chars.peek() {
                        chars.next();
                        output.push(next_c);
                    }
                } else if c == '\'' {
                    state = State::Code;
                }
            }
        }
    }
    // Note: This basic parser doesn't handle raw strings (r#"..."#)
    // or byte strings (b"...") specifically, treating them like normal strings/code.
    // It also doesn't report errors for unterminated comments/strings.
    output
}

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

    // Define base replacement strings and format templates
    let globals_replacement = format!("d_globals::<{}>(_parser).unwrap()", globals_type);
    // Format string expecting index {}, with node_type already substituted
    let child_user_replacement_fmt = format!(
        "d_user::<{}>(d_pn_ptr(d_child_pn_ptr(_children, {{}}), _offset)).unwrap()",
        node_type
    );
    let user_replacement = format!("d_user::<{}>(d_pn_ptr(_ps, _offset)).unwrap()", node_type);
    // Format string expecting index {}
    let child_node_replacement_fmt = "d_pn(d_child_pn_ptr(_children, {}), _offset).unwrap()";
    let node_replacement = "d_pn(_ps, _offset).unwrap()";

    output.push_str(
        r#"
use dparser_lib::bindings::*;
#[allow(unused_imports)]
use dparser_lib::{d_globals, d_child_pn_ptr, d_pn, d_pn_ptr, d_user, d_get_number_of_children, d_get_child, d_children_nodes, d_children_user}; // Added imports
use std::os::raw::c_void;
        "#,
    );

    // Regex for parsing the input structure (not for substitutions within actions)
    let global_code_regex = regex::Regex::new(r#"^(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap(); // Keep for parsing global code block header
    let header_regex = regex::Regex::new(r#"^(\w+)\s+(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap(); // Keep for parsing action function header

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

                // Transform the body using the manual processor
                let transformed_body = process_body(
                    &body,
                    &globals_replacement,
                    &child_user_replacement_fmt,
                    &user_replacement,
                    child_node_replacement_fmt,
                    &node_replacement,
                    node_type, // Pass node_type here
                );

                // Create the Rust function
                let rust_function = format!(
                    "#[unsafe(no_mangle)]\npub extern \"C\" fn {}{} {{\n  // line!({}, \"{}\")\n{} 0 }}\n\n",
                    function_name, PARAMETERS, line_number, file_name, transformed_body
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
