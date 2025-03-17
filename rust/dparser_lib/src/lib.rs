mod bindings;
use bindings::{D_ParseNode, D_Parser};
use std::os::raw::c_void;

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

pub fn d_user<'a, T>(pn: &'a mut D_ParseNode) -> Option<&'a mut T> {
    unsafe {
        let field_address: *mut c_void = &mut pn.user as *mut *mut c_void as *mut c_void;
        let ptr: *mut T = field_address.cast::<T>();
        Some(&mut *ptr)
    }
}

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
