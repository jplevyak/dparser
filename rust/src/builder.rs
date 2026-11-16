//! `builder.rs`
//! Generates the Rust action dispatcher from the actions file written by
//! `make_dparser -B -a`.  Call [`build_actions`] from a build script.

use std::collections::HashSet;
use std::path::PathBuf;

/// What an action body uses, for the code wrapped around it.
#[derive(Default)]
struct Uses {
    globals: bool,
    parser: bool,
}

/// Translate the `$` specifiers in an action body, leaving comments, strings
/// and character literals alone.
fn process_body(body: &str, uses: &mut Uses) -> Result<String, String> {
    let chars: Vec<char> = body.chars().collect();
    let mut out = String::with_capacity(body.len() * 2);
    let mut i = 0;
    let digits = |i: &mut usize| -> String {
        let mut d = String::new();
        while *i < chars.len() && chars[*i].is_ascii_digit() {
            d.push(chars[*i]);
            *i += 1;
        }
        d
    };
    while i < chars.len() {
        let c = chars[i];
        match c {
            '/' if chars.get(i + 1) == Some(&'/') => {
                while i < chars.len() && chars[i] != '\n' {
                    out.push(chars[i]);
                    i += 1;
                }
            }
            '/' if chars.get(i + 1) == Some(&'*') => {
                out.push_str("/*");
                i += 2;
                let mut depth = 1;
                while i < chars.len() && depth > 0 {
                    if chars[i] == '*' && chars.get(i + 1) == Some(&'/') {
                        depth -= 1;
                        out.push_str("*/");
                        i += 2;
                    } else if chars[i] == '/' && chars.get(i + 1) == Some(&'*') {
                        depth += 1;
                        out.push_str("/*");
                        i += 2;
                    } else {
                        out.push(chars[i]);
                        i += 1;
                    }
                }
            }
            'r' if (i == 0 || !(chars[i - 1].is_alphanumeric() || chars[i - 1] == '_'))
                && matches!(chars.get(i + 1), Some('"') | Some('#')) =>
            {
                // raw string r"..." or r#"..."#
                let mut j = i + 1;
                let mut hashes = 0;
                while chars.get(j) == Some(&'#') {
                    hashes += 1;
                    j += 1;
                }
                if chars.get(j) != Some(&'"') {
                    out.push(c);
                    i += 1;
                    continue;
                }
                let start = i;
                j += 1;
                loop {
                    if j >= chars.len() {
                        break;
                    }
                    if chars[j] == '"' && (0..hashes).all(|k| chars.get(j + 1 + k) == Some(&'#')) {
                        j += 1 + hashes;
                        break;
                    }
                    j += 1;
                }
                out.extend(&chars[start..j.min(chars.len())]);
                i = j;
            }
            '"' => {
                out.push(c);
                i += 1;
                while i < chars.len() {
                    out.push(chars[i]);
                    if chars[i] == '\\' && i + 1 < chars.len() {
                        out.push(chars[i + 1]);
                        i += 2;
                        continue;
                    }
                    i += 1;
                    if chars[i - 1] == '"' {
                        break;
                    }
                }
            }
            '\'' => {
                // a character literal ('x', '\n', '\u{..}'), or a lifetime/label
                let is_char = match chars.get(i + 1) {
                    Some('\\') => true,
                    Some(_) => chars.get(i + 2) == Some(&'\''),
                    None => false,
                };
                out.push(c);
                i += 1;
                if is_char {
                    while i < chars.len() {
                        out.push(chars[i]);
                        if chars[i] == '\\' && i + 1 < chars.len() {
                            out.push(chars[i + 1]);
                            i += 2;
                            continue;
                        }
                        i += 1;
                        if chars[i - 1] == '\'' {
                            break;
                        }
                    }
                }
            }
            '$' => {
                i += 1;
                match chars.get(i) {
                    Some('#') => {
                        i += 1;
                        let d = digits(&mut i);
                        if d.is_empty() {
                            out.push_str("(_ps.children.len() as i32)");
                        } else {
                            out.push_str(&format!("(_ps.children[{}].children.len() as i32)", d));
                        }
                    }
                    Some('$') => {
                        i += 1;
                        out.push_str("_ps.user");
                    }
                    Some('g') => {
                        i += 1;
                        uses.globals = true;
                        out.push_str("_g");
                    }
                    Some('n') => {
                        i += 1;
                        let d = digits(&mut i);
                        if d.is_empty() {
                            out.push_str("_ps");
                        } else if chars.get(i) == Some(&'*') {
                            i += 1;
                            out.push_str(&format!("&mut _ps.children[{}].children", d));
                        } else {
                            out.push_str(&format!("_ps.children[{}]", d));
                        }
                    }
                    Some(d) if d.is_ascii_digit() => {
                        let d = digits(&mut i);
                        if chars.get(i) == Some(&'*') {
                            i += 1;
                            out.push_str(&format!("&mut _ps.children[{}].children", d));
                        } else {
                            out.push_str(&format!("_ps.children[{}].user", d));
                        }
                    }
                    Some('{') => {
                        let close = chars[i..].iter().position(|&c| c == '}').map(|p| i + p);
                        let Some(close) = close else { return Err("unterminated ${...}".into()) };
                        let inner: String = chars[i + 1..close].iter().collect();
                        let mut words = inner.trim().splitn(2, char::is_whitespace);
                        let keyword = words.next().unwrap_or("");
                        let args = words.next().unwrap_or("").trim();
                        match keyword {
                            "reject" => out.push_str("return -1"),
                            "scope" => out.push_str("_ps.scope"),
                            "parser" => {
                                uses.parser = true;
                                out.push_str("_parser");
                            }
                            "child" => {
                                // ${child 0, 2, 1}: child 1 of child 2 of element 0
                                let mut path = args.split(',').map(str::trim);
                                let first = path.next().filter(|s| !s.is_empty());
                                let Some(first) = first else { return Err("${child} needs an element".into()) };
                                out.push_str(&format!("_ps.children[{}]", first));
                                for p in path {
                                    out.push_str(&format!(".children[{}]", p));
                                }
                            }
                            _ => return Err(format!("unsupported ${{{}}} in a Rust action", keyword)),
                        }
                        i = close + 1;
                    }
                    _ => out.push('$'),
                }
            }
            _ => {
                out.push(c);
                i += 1;
            }
        }
    }
    Ok(out)
}

fn invalid(msg: String) -> std::io::Error {
    std::io::Error::new(std::io::ErrorKind::InvalidData, msg)
}

/// Generate `output_path` (Rust) from the actions file `input_path` written by
/// `make_dparser -B -a`.  `globals_type` and `node_type` name your global and
/// node types.  The output defines `dispatch_action`, to pass to
/// [`Parser::new`](crate::Parser::new).
pub fn build_actions(
    input_path: &PathBuf,
    output_path: &PathBuf,
    globals_type: &str,
    node_type: &str,
) -> std::io::Result<()> {
    let content = std::fs::read_to_string(input_path)?;
    let global_code_regex = regex::Regex::new(r#"^(\d+)\s+"([^"]*)"\s+(\d+)$"#).unwrap();
    let action_regex = regex::Regex::new(
        r#"^int d_(final|speculative|pass(\d+)|pass)_code_action_(-?\d+)\s+(\d+)\s+"([^"]*)"\s+(\d+)$"#,
    )
    .unwrap();

    let lines: Vec<&str> = content.lines().collect();
    let read_body = |i: &mut usize, count: usize| -> String {
        *i += 1;
        let start = *i;
        let mut body = String::new();
        while *i < lines.len() && *i - start < count {
            body.push_str(lines[*i]);
            body.push('\n');
            *i += 1;
        }
        body
    };

    let mut output = String::from("// Generated by dparser::build_actions.  Do not edit.\n");
    let mut mutable_speculative_globals = false;
    // external code: ${scan} calls by state, ${scanner}, ${declare whitespace}, ${token}
    let mut scans: Vec<(usize, Vec<(u32, i32, String)>)> = Vec::new();
    let mut scanner: Option<String> = None;
    let mut white_space: Option<String> = None;
    let mut tokens = String::new();
    let mut seen: HashSet<(String, i32)> = HashSet::new();
    let mut arms = String::new();
    let mut i = 0;
    while i < lines.len() {
        let line = lines[i];
        if line == "declare mutable_speculative_globals" {
            mutable_speculative_globals = true;
            i += 1;
        } else if let Some(rest) = line.strip_prefix("scan ") {
            // scan <state> <symbol> <term_priority> <function or call>
            let mut f = rest.splitn(4, ' ');
            let bad = || invalid(format!("bad line '{}'", line));
            let state: usize = f.next().and_then(|x| x.parse().ok()).ok_or_else(bad)?;
            let symbol: u32 = f.next().and_then(|x| x.parse().ok()).ok_or_else(bad)?;
            let tp: i32 = f.next().and_then(|x| x.parse().ok()).ok_or_else(bad)?;
            let call = f.next().ok_or_else(bad)?.trim().to_string();
            match scans.iter_mut().find(|(s, _)| *s == state) {
                Some((_, v)) => v.push((symbol, tp, call)),
                None => scans.push((state, vec![(symbol, tp, call)])),
            }
            i += 1;
        } else if let Some(rest) = line.strip_prefix("scanner ") {
            scanner = Some(rest.trim().to_string());
            i += 1;
        } else if let Some(rest) = line.strip_prefix("whitespace ") {
            white_space = Some(rest.trim().to_string());
            i += 1;
        } else if let Some(rest) = line.strip_prefix("token ") {
            let mut f = rest.split_whitespace();
            if let (Some(name), Some(n)) = (f.next(), f.next()) {
                tokens.push_str(&format!("pub const {}: u16 = {};\n", name, n));
            }
            i += 1;
        } else if let Some(c) = global_code_regex.captures(line) {
            let count = c[3].parse::<usize>().unwrap_or(0);
            output.push_str(&format!("// {}:{}\n", &c[2], &c[1]));
            output.push_str(&read_body(&mut i, count));
        } else if let Some(c) = action_regex.captures(line) {
            let kind = match &c[1] {
                "final" | "pass" => "::dparser::ActionKind::Final".to_string(),
                "speculative" => "::dparser::ActionKind::Speculative".to_string(),
                _ => format!("::dparser::ActionKind::Pass({})", &c[2]),
            };
            let speculative = &c[1] == "speculative";
            let idx: i32 = c[3].parse().map_err(|_| invalid(format!("bad action index in '{}'", line)))?;
            let (line_no, file) = (c[4].to_string(), c[5].to_string());
            let count = c[6].parse::<usize>().unwrap_or(0);
            let body = read_body(&mut i, count);
            // The same code may be written more than once (e.g. `_` defaults
            // for internal productions); keep the first.
            if !seen.insert((kind.clone(), idx)) {
                continue;
            }
            let mut uses = Uses::default();
            let body = process_body(&body, &mut uses).map_err(|e| invalid(format!("{}:{}: {}", file, line_no, e)))?;
            let globals = if !uses.globals {
                String::new()
            } else if speculative && !mutable_speculative_globals {
                // Speculative actions may run for parses that are abandoned, so
                // they only read the globals (see ${declare mutable_speculative_globals}).
                format!(
                    "let _g: &{} = &*_globals.expect(\"the action uses $g but parse() was given no globals\");\n",
                    globals_type
                )
            } else {
                format!(
                    "let _g: &mut {} = _globals.expect(\"the action uses $g but parse() was given no globals\");\n",
                    globals_type
                )
            };
            arms.push_str(&format!(
                "        ({kind}, {idx}) => {{\n            // {file}:{line_no}\n            if _probe {{ return Some(0); }}\n            {globals}            Some((|| -> i32 {{\n{body}\n                0\n            }})())\n        }}\n"
            ));
        } else if line.is_empty() {
            i += 1;
        } else {
            return Err(invalid(format!("bad header line '{}' in {}", line, input_path.display())));
        }
    }

    output.push_str(&format!(
        r#"
#[allow(dead_code, unused_variables, unused_mut, unused_braces, unreachable_code, clippy::all)]
pub fn dispatch_action(
    _kind: ::dparser::ActionKind,
    _action_idx: i32,
    _probe: bool,
    _ps: &mut ::dparser::ParseNode<'_, {node}>,
    _globals: Option<&mut {globals}>,
    _parser: &mut ::dparser::Parser<{globals}, {node}>,
) -> Option<i32> {{
    match (_kind, _action_idx) {{
{arms}        _ => None,
    }}
}}
"#,
        node = node_type,
        globals = globals_type,
        arms = arms
    ));

    // External scanners: each ${scan f} terminal of a state is tried in turn
    // (as the C code generated for it); ${scanner f} handles the other states.
    let mut scan_arms = String::new();
    for (state, calls) in &scans {
        scan_arms.push_str(&format!("        {} => {{\n", state));
        for (symbol, tp, call) in calls {
            let args = "_input, _loc, _op_assoc, _op_priority";
            let call = match call.strip_suffix(')') {
                Some(prefix) => format!("{}, {})", prefix, args),
                None => format!("{}({})", call, args),
            };
            scan_arms.push_str(&format!(
                "            let r = {};\n            if r != 0 {{ *_symbol = {}; *_term_priority = {}; return r; }}\n",
                call, symbol, tp
            ));
        }
        scan_arms.push_str("            0\n        }\n");
    }
    let default_scan = match &scanner {
        Some(f) => format!("{}(_input, _loc, _symbol, _term_priority, _op_assoc, _op_priority)", f),
        None => "0".to_string(),
    };
    let has_scan = !scans.is_empty() || scanner.is_some();
    output.push_str(&tokens);
    output.push_str(&format!(
        r#"
#[allow(dead_code, unused_variables, unreachable_code, clippy::all)]
pub fn dispatch_scan(
    _state: usize,
    _input: &[u8],
    _loc: &mut ::dparser::Loc,
    _symbol: &mut u16,
    _term_priority: &mut i32,
    _op_assoc: &mut u8,
    _op_priority: &mut i32,
) -> i32 {{
    match _state {{
{scan_arms}        _ => {default_scan},
    }}
}}

/// Everything generated for the grammar: `Parser::with_actions(tables, actions())`.
#[allow(dead_code)]
pub fn actions() -> ::dparser::Actions<{globals}, {node}> {{
    ::dparser::Actions {{
        dispatch: Some(dispatch_action),
        scan: {scan},
        white_space: {white_space},
    }}
}}
"#,
        globals = globals_type,
        node = node_type,
        scan = if has_scan { "Some(dispatch_scan)" } else { "None" },
        white_space = match &white_space {
            Some(f) => format!("Some({})", f),
            None => "None".to_string(),
        },
    ));
    std::fs::write(output_path, output)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(name: &str, actions: &str) -> std::io::Result<String> {
        let dir = std::env::temp_dir().join(format!("dparser_builder_{}_{}", name, std::process::id()));
        std::fs::create_dir_all(&dir)?;
        let input: PathBuf = dir.join("g.actions");
        let output: PathBuf = dir.join("actions.rs");
        std::fs::write(&input, actions)?;
        let result = build_actions(&input, &output, "G", "N").and_then(|_| std::fs::read_to_string(&output));
        let _ = std::fs::remove_dir_all(&dir);
        result
    }

    const ACTIONS: &str = "int d_speculative_code_action_1020002 2 \"g.g\" 1\n $g.n += 10; \n\
                           int d_final_code_action_1020002 2 \"g.g\" 1\n $g.n += 100; \n\
                           int d_pass0_code_action_1030003 3 \"g.g\" 1\n $$.x = $0.x; \n";

    #[test]
    fn arms_by_kind() {
        let out = run("kinds", ACTIONS).unwrap();
        assert!(out.contains("(::dparser::ActionKind::Speculative, 1020002)"), "{}", out);
        assert!(out.contains("(::dparser::ActionKind::Final, 1020002)"), "{}", out);
        assert!(out.contains("(::dparser::ActionKind::Pass(0), 1030003)"), "{}", out);
        assert!(out.contains("_ps.user.x = _ps.children[0].user.x;"), "{}", out);
    }

    #[test]
    fn speculative_globals_are_read_only_unless_declared() {
        let out = run("ro", ACTIONS).unwrap();
        assert!(out.contains("let _g: &G = "), "{}", out);
        assert!(out.contains("let _g: &mut G = "), "{}", out);
        let out = run("rw", &format!("declare mutable_speculative_globals\n{}", ACTIONS)).unwrap();
        assert!(!out.contains("let _g: &G = "), "{}", out);
    }

    #[test]
    fn legacy_headers_and_no_global_code() {
        let out = run("legacy", "int d_pass_code_action_7 3 \"g.g\" 1\n $$.n = 1; \n").unwrap();
        assert!(out.contains("(::dparser::ActionKind::Final, 7)"), "{}", out);
    }

    #[test]
    fn duplicate_actions_are_dropped() {
        let a = "int d_final_code_action_-1 5 \"g.g\" 1\n x(); \nint d_final_code_action_-1 5 \"g.g\" 1\n x(); \n";
        let out = run("dup", a).unwrap();
        assert_eq!(out.matches("ActionKind::Final, -1)").count(), 1, "{}", out);
    }

    #[test]
    fn specifiers() {
        let mut u = Uses::default();
        let b = process_body("$$ = $n1.string; ${child 0, 2}; ${scope}; ${reject}; $#; $#2; ${parser}", &mut u).unwrap();
        assert_eq!(
            b,
            "_ps.user = _ps.children[1].string; _ps.children[0].children[2]; _ps.scope; return -1; \
             (_ps.children.len() as i32); (_ps.children[2].children.len() as i32); _parser"
        );
        assert!(u.parser && !u.globals);
    }

    #[test]
    fn literals_and_lifetimes() {
        let mut u = Uses::default();
        let b = process_body(
            "let s: &'static str = \"$1\"; let c = '$'; let r = r#\"$2\"#; /* $3 */ // $4\n$5",
            &mut u,
        )
        .unwrap();
        assert_eq!(
            b,
            "let s: &'static str = \"$1\"; let c = '$'; let r = r#\"$2\"#; /* $3 */ // $4\n_ps.children[5].user"
        );
    }

    #[test]
    fn unknown_specifier_is_an_error() {
        let mut u = Uses::default();
        assert!(process_body("${nonsense}", &mut u).is_err());
    }
}
