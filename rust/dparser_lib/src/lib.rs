pub mod bindings;
pub use bindings::{
    d_loc_t, dparse, free_D_ParseNode, free_D_Parser, new_D_Parser, D_AmbiguityFn, D_ParseNode,
    D_Parser, D_ParserTables, D_SyntaxErrorFn,
};
use regex::Regex;
use std::fs::File;
use std::io::{BufReader, Read};
use std::os::raw::{c_char, c_int, c_void};
use std::path::PathBuf;

pub fn d_globals<'a, T>(_parser: *mut D_Parser) -> Option<&'a mut T> {
    unsafe {
        if _parser.is_null() {
            return None;
        }
        if (*_parser).initial_globals.is_null() {
            return None;
        }
        let ptr: *mut T = (*_parser).initial_globals.cast::<T>();
        Some(&mut *ptr)
    }
}

pub fn d_child_pn(
    children: *mut *mut c_void,
    i: i32,
    offset: i32,
) -> Option<&'static mut D_ParseNode> {
    unsafe {
        if children.is_null() {
            return None;
        }
        let child_ptr: *mut *mut c_void = children.offset(i.try_into().unwrap());
        if child_ptr.is_null() {
            return None;
        }
        let child: *mut c_void = *child_ptr;
        let parse_node_ptr_raw: *mut u8 = child
            .cast::<u8>()
            .wrapping_offset(offset.try_into().unwrap());
        let parse_node_ptr: *mut D_ParseNode = parse_node_ptr_raw.cast::<D_ParseNode>();
        Some(&mut *parse_node_ptr)
    }
}

pub fn d_child_pn_ptr(children: *mut *mut c_void, i: i32, offset: i32) -> *mut c_void {
    unsafe {
        let child_ptr: *mut *mut c_void = children.offset(i.try_into().unwrap());
        let child: *mut c_void = *child_ptr;
        let parse_node_ptr_raw: *mut u8 = child
            .cast::<u8>()
            .wrapping_offset(offset.try_into().unwrap());
        *parse_node_ptr_raw.cast::<*mut c_void>()
    }
}

pub fn d_pn(pn: *mut c_void, offset: i32) -> Option<&'static mut D_ParseNode> {
    unsafe {
        if pn.is_null() {
            return None;
        }
        let parse_node_ptr_raw: *mut u8 =
            pn.cast::<u8>().wrapping_offset(offset.try_into().unwrap());
        let parse_node_ptr: *mut D_ParseNode = parse_node_ptr_raw.cast::<D_ParseNode>();
        Some(&mut *parse_node_ptr)
    }
}

pub fn d_user<'a, T: 'static + Default>(pn: &'a mut D_ParseNode) -> Option<&'a mut T> {
    unsafe {
        let field_address: *mut *mut c_void = &mut pn.user;
        let ptr: *mut T = (*field_address).cast::<T>();

        if ptr.is_null() {
            let new_t = Box::new(T::default());
            *field_address = Box::into_raw(new_t) as *mut c_void;
            let ptr: *mut T = (*field_address).cast::<T>();
            Some(&mut *ptr)
        } else {
            Some(&mut *ptr)
        }
    }
}

impl d_loc_t {
    pub fn str(&self) -> Result<&str, std::str::Utf8Error> {
        if self.s.is_null() || self.ws.is_null() {
            return Ok("");
        }
        unsafe {
            let len = self.ws.offset_from(self.s) as usize;
            let slice = std::slice::from_raw_parts(self.s as *const u8, len);
            std::str::from_utf8(slice)
        }
    }

    pub fn pathname(&self) -> Result<&str, std::str::Utf8Error> {
        if self.pathname.is_null() {
            return Ok("");
        }
        unsafe {
            let c_str = std::ffi::CStr::from_ptr(self.pathname);
            c_str.to_str()
        }
    }

    pub fn column(&self) -> i32 {
        self.col
    }

    pub fn line(&self) -> i32 {
        self.line
    }
}

impl D_ParseNode {
    pub fn str(&self) -> Result<&str, std::str::Utf8Error> {
        if self.start_loc.s.is_null() || self.end.is_null() {
            return Ok("");
        }
        unsafe {
            let len = self.end.offset_from(self.start_loc.s) as usize;
            let slice = std::slice::from_raw_parts(self.start_loc.s as *const u8, len);
            std::str::from_utf8(slice)
        }
    }

    pub fn end_skip_str(&self) -> Result<&str, std::str::Utf8Error> {
        if self.end.is_null() || self.end_skip.is_null() {
            return Ok("");
        }

        unsafe {
            let len = self.end_skip.offset_from(self.end) as usize;
            let slice = std::slice::from_raw_parts(self.end as *const u8, len);
            std::str::from_utf8(slice)
        }
    }
}

pub struct Parser<G: 'static, N: 'static> {
    parser: *mut D_Parser,
    initial_globals_box: Option<Box<G>>,
    _phantom_n: std::marker::PhantomData<N>,
}

impl<G: 'static, N: 'static> Parser<G, N> {
    pub fn new(tables: *mut D_ParserTables) -> Self {
        unsafe {
            let parser = new_D_Parser(tables, std::mem::size_of::<Box<N>> as c_int);
            (*parser).syntax_error_fn = Some(default_syntax_error_fn);
            (*parser).ambiguity_fn = Some(default_ambiguity_fn);
            (*parser).free_node_fn = Some(default_free_node_fn::<N>);
            Parser {
                parser,
                initial_globals_box: None,
                _phantom_n: std::marker::PhantomData,
            }
        }
    }

    pub fn parse(&self, input: &str) -> Option<ParseNodeWrapper<'_, Self>> {
        unsafe {
            let mut input_bytes = input.as_bytes().to_vec();
            input_bytes.push(0);
            let buf = input_bytes.as_mut_ptr() as *mut c_char;
            let buf_len = input_bytes.len() as c_int - 1;
            let result = dparse(self.parser, buf, buf_len);
            if result.is_null() {
                None
            } else {
                Some(ParseNodeWrapper {
                    node: result,
                    parser: self,
                })
            }
        }
    }

    pub fn set_syntax_error_fn(&mut self, func: D_SyntaxErrorFn) {
        unsafe {
            (*self.parser).syntax_error_fn = func;
        }
    }

    pub fn set_ambiguity_fn(&mut self, func: D_AmbiguityFn) {
        unsafe {
            (*self.parser).ambiguity_fn = func;
        }
    }

    pub fn get_parser_ptr(&self) -> *mut D_Parser {
        self.parser
    }

    pub fn set_initial_globals(&mut self, globals: G) {
        unsafe {
            let boxed_globals: Box<dyn std::any::Any> = Box::new(globals);
            (*self.parser).initial_globals = Box::into_raw(boxed_globals) as *mut c_void;
            // Reconstruct the Box to store it.
            let raw_ptr = (*self.parser).initial_globals as *mut dyn std::any::Any;
            self.initial_globals_box = Some(Box::from_raw(raw_ptr).downcast::<G>().unwrap());
        }
    }
}

impl<G: 'static, N: 'static> Drop for Parser<G, N> {
    fn drop(&mut self) {
        unsafe {
            free_D_Parser(self.parser);
        }
    }
}

pub trait ParserPtr {
    fn get_parser_ptr(&self) -> *mut D_Parser;
}

impl<G: 'static, N: 'static> ParserPtr for Parser<G, N> {
    fn get_parser_ptr(&self) -> *mut D_Parser {
        self.parser
    }
}

pub struct ParseNodeWrapper<'a, P: ParserPtr + 'static> {
    pub node: *mut D_ParseNode,
    pub parser: &'a P,
}

impl<'a, P: ParserPtr + 'static> Drop for ParseNodeWrapper<'a, P> {
    fn drop(&mut self) {
        unsafe {
            free_D_ParseNode(self.parser.get_parser_ptr(), self.node);
        }
    }
}

extern "C" fn default_syntax_error_fn(parser: *mut D_Parser) {
    unsafe {
        let loc = (*parser).loc;
        let line = loc.line;
        let col = loc.col;
        let pathname = if !loc.pathname.is_null() {
            std::ffi::CStr::from_ptr(loc.pathname)
                .to_str()
                .unwrap_or("unknown")
        } else {
            "unknown"
        };
        eprintln!(
            "Syntax error in file '{}', line {}, column {}",
            pathname, line, col
        );
    }
}

extern "C" fn default_free_node_fn<T: 'static>(node: *mut D_ParseNode) {
    unsafe {
        if !node.is_null() {
            let user_ptr = (*node).user as *mut T;
            if !user_ptr.is_null() {
                drop(Box::from_raw(user_ptr));
            }
        }
    }
}

extern "C" fn default_ambiguity_fn(
    parser: *mut D_Parser,
    _n: c_int,
    _v: *mut *mut D_ParseNode,
) -> *mut D_ParseNode {
    unsafe {
        let loc = (*parser).loc;
        let line = loc.line;
        let col = loc.col;
        let pathname = if !loc.pathname.is_null() {
            std::ffi::CStr::from_ptr(loc.pathname)
                .to_str()
                .unwrap_or("unknown")
        } else {
            "unknown"
        };
        eprintln!(
            "Ambiguity detected in file '{}', line {}, column {}",
            pathname, line, col
        );
        std::ptr::null_mut()
    }
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

    let globals = format!("d_globals::<{}>(_parser).unwrap()", globals_type);
    let child_user = format!(
        "d_user::<{}>(d_pn(d_child_pn_ptr(_children, $1, _offset), _offset).unwrap()).unwrap()",
        node_type
    );
    let user = format!(
        "d_user::<{}>(d_pn(_ps, _offset).unwrap()).unwrap()",
        node_type
    );

    output.push_str(
        r#"
use dparser_lib::bindings::*;
use dparser_lib::{d_globals, d_child_pn_ptr, d_pn, d_user};
use std::os::raw::c_void;
        "#,
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
                let body = dollar_var_regex
                    .replace_all(&body, child_user.clone())
                    .to_string();
                let body = dollar_g_regex
                    .replace_all(&body, globals.clone())
                    .to_string();
                let body = dollar_n_regex
                    .replace_all(
                        &body,
                        "d_pn(d_child_pn_ptr(_children, $1, _offset), _offset).unwrap()",
                    )
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
