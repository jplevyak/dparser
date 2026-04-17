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
                                        // Then wrap it with children.len()
                                        let final_replacement = format!(
                                            "{}.children.len() as i32",
                                            node_replacement
                                        );
                                        output.push_str(&final_replacement);
                                    } else {
                                        // Handle $#
                                        output.push_str("(_children.len() as i32)");
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
                                                "&mut _children[{}].children",
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
                                            "&mut _children[{}].children", // User slices natively managed generically by Rust directly
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
    let globals_replacement = "_g".to_string();
    let child_user_replacement_fmt = "_children[{}].user".to_string();
    let user_replacement = "_ps.user".to_string();
    let child_node_replacement_fmt = "_children[{}]".to_string();
    let node_replacement = "_ps".to_string();

    output.push_str(
        r#"
// Idiomatically bounded natively!
// Imports deferred to encompassing scoped modules via include! cleanly!
        "#,
    );

    // Regex for parsing the input structure
    let global_code_regex = regex::Regex::new(r#"^(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let header_regex = regex::Regex::new(r#"^(\w+)\s+(\d+)\s+"([^"]+)"\s+(\d+)$"#).unwrap();
    let binary_header_regex =
        regex::Regex::new(r#"^int d_pass_code_action_(-?\d+)\s+(\d+)\s+"([^"]+)"\s+(\d+)$"#)
            .unwrap();

    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;

    let mut dispatch_arms = String::new();

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

        // Try to match the legacy C function header or the native binary header
        let mut matched = false;

        let (action_idx, line_number, file_name, line_count, is_binary) =
            if let Some(captures) = binary_header_regex.captures(lines[i]) {
                let action_index = captures[1].parse::<isize>().unwrap() as i32;
                let file_name = captures[3].to_string();
                let line_count = captures[4].parse::<usize>().unwrap_or(0);
                matched = true;
                (Some(action_index), 0, file_name, line_count, true)
            } else if let Some(captures) = header_regex.captures(lines[i]) {
                let line_number = captures[2].parse::<usize>().unwrap_or(0);
                let file_name = captures[3].to_string();
                let line_count = captures[4].parse::<usize>().unwrap_or(0);
                matched = true;
                (None, line_number, file_name, line_count, false)
            } else {
                (None, 0, String::new(), 0, false)
            };

        if matched {
            i += 1; // Move to the next line (body starts here)

            if i < lines.len() {
                // Read the body, which might span multiple lines
                let mut body = String::new();
                let start_line = i;

                while i < lines.len() && i - start_line < line_count {
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
                    &child_node_replacement_fmt,
                    &node_replacement,
                );

                if is_binary {
                    // Accumulate inside the unified dispatcher
                    if let Some(idx) = action_idx {
                        dispatch_arms.push_str(&format!(
                            "  {} => {{ #[allow(unreachable_code)] {{ // file: {}\n{} \n    0 }} }},\n",
                            idx, file_name, transformed_body
                        ));
                    }
                } else {
                    // Fallback generating identical legacy C mapping routines
                    let func_name = "legacy_bound"; // We won't hit this normally assuming strict -B use
                    let rust_function = format!(
                        "#[unsafe(no_mangle)]\n#[allow(unreachable_code)]\npub extern \"C\" fn {}{} {{\n  // line!({}, \"{}\")\n{} 0 }}\n\n",
                        func_name, PARAMETERS, line_number, file_name, transformed_body
                    );
                    output.push_str(&rust_function);
                }
            }
        } else {
            eprintln!("Error: Bad header line '{}'", lines[i]);
            std::process::exit(1);
        }
    }

    // Append unified binary dispatcher fallback mapping securely
    let dispatcher = format!(
        "#[allow(unused_assignments)] // Inherently mapping natively!\npub fn dispatch_action(action_idx: i32, _ps: &mut ParseNode<'_, {}>, _children: &mut [ParseNode<'_, {}>], _parser: &mut Parser<{}, {}>) -> i32 {{\n\
            let _g = _parser.globals();\n\
            match action_idx {{\n\
                {}\n\
                _ => 0,\n\
            }}\n\
        }}\n",
        node_type, node_type, globals_type, node_type, dispatch_arms
    );

    output.push_str(&dispatcher);

    // Write the output to a file
    std::fs::write(output_path, output)?;

    Ok(())
}
