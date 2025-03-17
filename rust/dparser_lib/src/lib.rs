mod bindings;
use bindings::{
    d_loc_t, dparse, free_D_ParseNode, free_D_Parser, new_D_Parser, D_AmbiguityFn, D_ParseNode,
    D_Parser, D_ParserTables, D_SyntaxErrorFn,
};
use std::os::raw::{c_char, c_int, c_void};

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
        d_pn(child, offset)
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

    pub fn col(&self) -> i32 {
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
    node: *mut D_ParseNode,
    parser: &'a P,
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
