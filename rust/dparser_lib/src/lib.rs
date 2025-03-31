pub mod bindings;
pub mod builder;
pub use bindings::{
    d_get_child, d_get_number_of_children, d_loc_t, dparse, free_D_ParseNode, free_D_Parser,
    new_D_Parser, D_AmbiguityFn, D_ParseNode, D_Parser, D_ParserTables, D_SyntaxErrorFn,
};
pub use builder::build_actions;
use std::os::raw::{c_char, c_int, c_void};
use std::vec::Vec; // Import Vec

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

pub fn d_child_pn_ptr(children: *mut *mut c_void, i: i32) -> *mut c_void {
    unsafe {
        let child_ptr: *mut *mut c_void = children.offset(i.try_into().unwrap());
        *child_ptr as *mut c_void
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

pub fn d_pn_ptr(pn: *mut c_void, offset: i32) -> *mut D_ParseNode {
    if pn.is_null() {
        return std::ptr::null_mut();
    }
    let parse_node_ptr_raw: *mut u8 = pn.cast::<u8>().wrapping_offset(offset.try_into().unwrap());
    parse_node_ptr_raw as *mut D_ParseNode
}

pub fn d_user<'a, T: 'static + Default>(pn: *mut D_ParseNode) -> Option<&'a mut T> {
    unsafe {
        let field_address: *mut *mut c_void = &mut (*pn).user;
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

pub fn d_user_ptr<T: 'static + Default>(pn: *mut D_ParseNode) -> *mut T {
    unsafe {
        let field_address: *mut *mut c_void = &mut (*pn).user;
        let ptr: *mut T = (*field_address).cast::<T>();
        if ptr.is_null() {
            let new_t = Box::new(T::default());
            *field_address = Box::into_raw(new_t) as *mut c_void;
            field_address as *mut T
        } else {
            ptr
        }
    }
}

// Helper to get children nodes as a Vec
pub fn d_children_nodes(
    children: *mut *mut c_void,
    i: i32,
    offset: i32,
) -> Vec<&'static mut D_ParseNode> {
    let mut nodes = Vec::new();
    unsafe {
        if let Some(parent_node) = d_child_pn(children, i, offset) {
            let num_children = d_get_number_of_children(parent_node);
            for j in 0..num_children {
                if let Some(child_node) = d_get_child(parent_node, j).as_mut() {
                    nodes.push(child_node);
                }
            }
        }
    }
    nodes
}

// Helper to get children user data as a Vec
pub fn d_children_user<'a, T: 'static + Default>(
    children: *mut *mut c_void,
    i: i32,
    offset: i32,
) -> Vec<&'a mut T> {
    let mut users = Vec::new();
    unsafe {
        if let Some(parent_node) = d_child_pn(children, i, offset) {
            let num_children = d_get_number_of_children(parent_node);
            for j in 0..num_children {
                if let Some(child_node) = d_get_child(parent_node, j).as_mut() {
                    if let Some(user_data) = d_user::<T>(child_node) {
                        // Need to ensure the lifetime 'a is appropriate.
                        // This might require careful handling depending on usage context.
                        // For now, assuming 'a can be derived correctly.
                        // Reinterpreting the lifetime might be necessary if 'a is shorter than 'static.
                        let user_data_ptr = user_data as *mut T;
                        users.push(&mut *user_data_ptr);
                    }
                }
            }
        }
    }
    users
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
        self.col as i32
    }

    pub fn line(&self) -> i32 {
        self.line as i32
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
    _phantom_g: std::marker::PhantomData<G>,
    _phantom_n: std::marker::PhantomData<N>,
}

impl<G: 'static, N: 'static> Parser<G, N> {
    pub fn new(tables: *mut D_ParserTables) -> Self {
        unsafe {
            let sizeof_n = std::mem::size_of::<N>() as c_int;
            let parser = new_D_Parser(tables, sizeof_n);
            (*parser).syntax_error_fn = Some(default_syntax_error_fn);
            (*parser).ambiguity_fn = Some(default_ambiguity_fn);
            (*parser).free_node_fn = Some(default_free_node_fn::<N>);
            Parser {
                parser,
                _phantom_g: std::marker::PhantomData,
                _phantom_n: std::marker::PhantomData,
            }
        }
    }

    pub fn parse(
        &mut self,
        input: &str,
        initial_globals: &mut G,
    ) -> Option<ParseNodeWrapper<'_, Self>> {
        unsafe {
            (*self.parser).initial_globals = initial_globals as *mut G as *mut c_void;
            let mut input_bytes = input.as_bytes().to_vec();
            input_bytes.push(0);
            let buf = input_bytes.as_mut_ptr() as *mut c_char;
            let buf_len = input_bytes.len() as c_int - 1;
            let result = dparse(self.parser, buf, buf_len);
            if result == bindings::NO_DPN {
                Some(ParseNodeWrapper {
                    node: std::ptr::null_mut(),
                    parser: self,
                })
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

    pub fn set_save_parse_tree(&mut self, b: bool) {
        unsafe {
            (*self.parser).save_parse_tree = if b { 1 } else { 0 };
        }
    }

    pub fn get_parser_ptr(&self) -> *mut D_Parser {
        self.parser
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
            let node = if self.node.is_null() {
                bindings::NO_DPN
            } else {
                self.node
            };
            free_D_ParseNode(self.parser.get_parser_ptr(), node);
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
