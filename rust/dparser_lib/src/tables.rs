use crate::bindings::{D_ParserTables, D_ReductionCode};
use std::ffi::c_void;
use std::os::raw::c_int;

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct BinaryTablesHead {
    pub n_relocs: c_int,
    pub n_strings: c_int,
    pub d_parser_tables_loc: c_int,
    pub tables_size: c_int,
    pub strings_size: c_int,
}

pub struct BinaryTables {
    // We hold the raw vector mapping the relocations stably on the heap.
    _buf: Vec<u8>,
    pub tables: *mut D_ParserTables,
}

impl BinaryTables {
    pub unsafe fn from_bytes(
        bytes: &[u8],
        spec_code: D_ReductionCode,
        final_code: D_ReductionCode,
    ) -> Result<Self, &'static str> {
        let mut offset = 0;

        if bytes.len() < std::mem::size_of::<BinaryTablesHead>() {
            return Err("Binary tables file is too short to contain header");
        }

        let mut head = BinaryTablesHead {
            n_relocs: 0,
            n_strings: 0,
            d_parser_tables_loc: 0,
            tables_size: 0,
            strings_size: 0,
        };
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr().add(offset),
            &mut head as *mut _ as *mut u8,
            std::mem::size_of::<BinaryTablesHead>(),
        );
        offset += std::mem::size_of::<BinaryTablesHead>();

        let buf_size = (head.tables_size + head.strings_size) as usize;

        if bytes.len() < offset + buf_size {
            return Err("Binary tables file is truncated inside tables buffer");
        }

        // Ensure 8-byte alignment for the buffer to safely interpret points and intptr_ts natively on arm architectures
        let layout = std::alloc::Layout::from_size_align(buf_size, 8).unwrap();
        let buf_ptr = std::alloc::alloc_zeroed(layout);
        if buf_ptr.is_null() {
            std::alloc::handle_alloc_error(layout);
        }
        let mut buf = Vec::from_raw_parts(buf_ptr, buf_size, buf_size);

        let tables_buf = buf.as_mut_ptr();
        let strings_buf = tables_buf.add(head.tables_size as usize);

        // Copy raw tables body bytes securely
        std::ptr::copy_nonoverlapping(bytes.as_ptr().add(offset), tables_buf, buf_size);
        offset += buf_size;

        for _ in 0..head.n_relocs {
            if bytes.len() < offset + std::mem::size_of::<isize>() {
                return Err("Truncated relocations array");
            }
            let mut reloc_offset: isize = 0;
            std::ptr::copy_nonoverlapping(
                bytes.as_ptr().add(offset),
                &mut reloc_offset as *mut _ as *mut u8,
                std::mem::size_of::<isize>(),
            );
            offset += std::mem::size_of::<isize>();

            if reloc_offset < 0 || reloc_offset + std::mem::size_of::<*mut c_void>() as isize > head.tables_size as isize {
                return Err("Invalid table relocation offset");
            }

            let intptr_ptr = tables_buf.offset(reloc_offset) as *mut isize;
            let val = std::ptr::read_unaligned(intptr_ptr);

            let ptr_dst = tables_buf.offset(reloc_offset) as *mut *mut c_void;

            if val == -1 {
                std::ptr::write_unaligned(ptr_dst, std::ptr::null_mut());
            } else if val == -2 {
                std::ptr::write_unaligned(ptr_dst, std::mem::transmute(spec_code));
            } else if val == -3 {
                std::ptr::write_unaligned(ptr_dst, std::mem::transmute(final_code));
            } else {
                let base = tables_buf as isize;
                std::ptr::write_unaligned(intptr_ptr, val + base);
            }
        }

        for _ in 0..head.n_strings {
            if bytes.len() < offset + std::mem::size_of::<isize>() {
                return Err("Truncated string relocations array");
            }
            let mut reloc_offset: isize = 0;
            std::ptr::copy_nonoverlapping(
                bytes.as_ptr().add(offset),
                &mut reloc_offset as *mut _ as *mut u8,
                std::mem::size_of::<isize>(),
            );
            offset += std::mem::size_of::<isize>();

            if reloc_offset < 0 || reloc_offset + std::mem::size_of::<*mut c_void>() as isize > head.tables_size as isize {
                return Err("Invalid string relocation offset");
            }

            let intptr_ptr = tables_buf.offset(reloc_offset) as *mut isize;
            let val = std::ptr::read_unaligned(intptr_ptr);
            let base = strings_buf as isize;
            std::ptr::write_unaligned(intptr_ptr, val + base);
        }

        let tables = tables_buf.add(head.d_parser_tables_loc as usize) as *mut D_ParserTables;

        Ok(BinaryTables { _buf: buf, tables })
    }
}
