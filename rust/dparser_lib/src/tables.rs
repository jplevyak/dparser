use crate::binary_format::{D_ParserTables};
use binrw::{BinRead, BinReaderExt};
use std::ffi::c_void;
use std::io::Cursor;
use crate::grammar::*;

#[derive(BinRead, Copy, Clone, Debug)]
pub struct BinaryTablesHead {
    pub n_relocs: i32,
    pub n_strings: i32,
    pub d_parser_tables_loc: i32,
    pub tables_size: i32,
    pub strings_size: i32,
}

pub struct BinaryTables;

impl BinaryTables {
    pub fn from_bytes(
        bytes: &[u8],
    ) -> Result<SafeGrammarTables, &'static str> {
        let mut cursor = Cursor::new(bytes);

        let head: BinaryTablesHead = cursor
            .read_le()
            .map_err(|_| "Binary tables file is too short to contain header")?;

        let offset = cursor.position() as usize;
        let buf_size = (head.tables_size + head.strings_size) as usize;

        if bytes.len() < offset + buf_size {
            return Err("Binary tables file is truncated inside tables buffer");
        }

        // To achieve safe 8-byte alignment on all architectures, we create a Vec<u64> instead of using raw allocators.
        // The size in u64s must cleanly encapsulate buf_size natively rounding up.
        let u64_count = (buf_size + 7) / 8;
        let mut aligned_vec: Vec<u64> = vec![0; u64_count];
        
        // We can safely coerce it into a byte slice to copy the data natively without unsafe ptr copies!
        let byte_slice = bytemuck::cast_slice_mut::<u64, u8>(&mut aligned_vec);
        byte_slice[..buf_size].copy_from_slice(&bytes[offset..offset + buf_size]);
        
        cursor.set_position((offset + buf_size) as u64);

        // For the relocation patching, we extract the raw pointer. This explicitly enters the unsafe domain.
        let tables_buf = aligned_vec.as_mut_ptr() as *mut u8;
        let strings_buf = unsafe { tables_buf.add(head.tables_size as usize) };

        // Wrap the pointer patching exactly in unsafe
        unsafe {
            for _ in 0..head.n_relocs {
                let reloc_offset = if std::mem::size_of::<isize>() == 8 {
                    cursor
                        .read_le::<i64>()
                        .map_err(|_| "Truncated relocations array")? as isize
                } else {
                    cursor
                        .read_le::<i32>()
                        .map_err(|_| "Truncated relocations array")? as isize
                };

                if reloc_offset < 0
                    || reloc_offset + std::mem::size_of::<*mut c_void>() as isize
                        > head.tables_size as isize
                {
                    return Err("Invalid table relocation offset");
                }

                let intptr_ptr = tables_buf.offset(reloc_offset) as *mut isize;
                let val = std::ptr::read_unaligned(intptr_ptr);

                let ptr_dst = tables_buf.offset(reloc_offset) as *mut *mut c_void;

                if val == -1 {
                    std::ptr::write_unaligned(ptr_dst, std::ptr::null_mut());
                } else if val == -2 {
                    std::ptr::write_unaligned(ptr_dst, (-2isize) as *mut std::ffi::c_void);
                } else if val == -3 {
                    std::ptr::write_unaligned(ptr_dst, (-3isize) as *mut std::ffi::c_void);
                } else {
                    let base = tables_buf as isize;
                    std::ptr::write_unaligned(intptr_ptr, val + base);
                }
            }

            for _ in 0..head.n_strings {
                let reloc_offset = if std::mem::size_of::<isize>() == 8 {
                    cursor
                        .read_le::<i64>()
                        .map_err(|_| "Truncated string relocations array")? as isize
                } else {
                    cursor
                        .read_le::<i32>()
                        .map_err(|_| "Truncated string relocations array")? as isize
                };

                if reloc_offset < 0
                    || reloc_offset + std::mem::size_of::<*mut c_void>() as isize
                        > head.tables_size as isize
                {
                    return Err("Invalid string relocation offset");
                }

                let intptr_ptr = tables_buf.offset(reloc_offset) as *mut isize;
                let val = std::ptr::read_unaligned(intptr_ptr);
                let base = strings_buf as isize;
                std::ptr::write_unaligned(intptr_ptr, val + base);
            }
        }

        // Reinterpret the base back and keep the u64 vector locally tracking memory lifetimes properly!
        let tables = unsafe { tables_buf.add(head.d_parser_tables_loc as usize) as *mut D_ParserTables };

        // Parse explicitly into SafeGrammarTables tree representation!
        let mut safe_tables = unsafe { Self::build_safe_tables(tables) };
        safe_tables._binary_data = aligned_vec;

        Ok(safe_tables)
    }

    unsafe fn build_safe_tables(tables: *mut D_ParserTables) -> SafeGrammarTables {
        let mut safe_states = Vec::new();
        let nstates = (*tables).nstates as usize;
        let state_arr = std::slice::from_raw_parts((*tables).state, nstates);

        let max_goto_len = (nstates * (*tables).nsymbols as usize) * 2; 
        if max_goto_len == 0 {
           // Provide safe empty defaults if testing grammar is somehow 0
        }
        let goto_table = std::slice::from_raw_parts((*tables).goto_table, max_goto_len).to_vec();

        for s in 0..nstates {
            let c_st = &state_arr[s];
            
            let mut reductions = Vec::new();
            let n_reds = c_st.reductions.n as usize;
            if n_reds > 0 && !c_st.reductions.v.is_null() {
                let red_arr = std::slice::from_raw_parts(c_st.reductions.v, n_reds);
                for i in 0..n_reds {
                    let red_ptr = red_arr[i];
                    let c_red = &*red_ptr;
                    
                    let spec_raw: isize = std::mem::transmute(c_red.speculative_code);
                    let final_raw: isize = std::mem::transmute(c_red.final_code);
                    
                    reductions.push(GrammarReduction {
                        nelements: c_red.nelements,
                        symbol: c_red.symbol,
                        action_index: c_red.action_index,
                        op_assoc: c_red.op_assoc,
                        rule_assoc: c_red.rule_assoc,
                        op_priority: c_red.op_priority,
                        rule_priority: c_red.rule_priority,
                        speculative_code: spec_raw as i32,
                        final_code: final_raw as i32,
                    });
                }
            }
            
            let mut right_epsilons = Vec::new();
            let n_reps = c_st.right_epsilon_hints.n as usize;
            if n_reps > 0 && !c_st.right_epsilon_hints.v.is_null() {
                let rep_arr = std::slice::from_raw_parts(c_st.right_epsilon_hints.v, n_reps);
                for i in 0..n_reps {
                    let c_rep = &rep_arr[i];
                    let c_red = &*c_rep.reduction;
                    
                    let spec_raw: isize = std::mem::transmute(c_red.speculative_code);
                    let final_raw: isize = std::mem::transmute(c_red.final_code);
                    
                    let safe_red = GrammarReduction {
                        nelements: c_red.nelements,
                        symbol: c_red.symbol,
                        action_index: c_red.action_index,
                        op_assoc: c_red.op_assoc,
                        rule_assoc: c_red.rule_assoc,
                        op_priority: c_red.op_priority,
                        rule_priority: c_red.rule_priority,
                        speculative_code: spec_raw as i32,
                        final_code: final_raw as i32,
                    };
                    
                    right_epsilons.push(GrammarRightEpsilonHint {
                        depth: c_rep.depth,
                        preceeding_state: c_rep.preceeding_state,
                        reduction: safe_red,
                    });
                }
            }
            
            // To be implemented: Safe graph traversal flattening the scanner_table DFA into pure Vec structures.
            // For now, we stub it so it compiles safely while we isolate the scanner.
            
            safe_states.push(GrammarState {
                goto_valid: Vec::new(),
                goto_table_offset: c_st.goto_table_offset,
                reductions,
                right_epsilon_hints: right_epsilons,
                shifts: Vec::new(),
                accept: c_st.accept,
                reduces_to: c_st.reduces_to,
                scan_kind: c_st.scan_kind,
                scanner_size: c_st.scanner_size,
                scanner_table: c_st.scanner_table as usize,
                transition_table: c_st.transition_table as usize,
                accepts_diff: c_st.accepts_diff as usize,
            });
        }
        
        SafeGrammarTables {
            states: safe_states,
            goto_table,
            whitespace_state: (*tables).whitespace_state,
            save_parse_tree: (*tables).save_parse_tree != 0,
            _binary_data: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    pub const TEST_GRAMMAR_BIN: &[u8] =
        include_bytes!(concat!(env!("OUT_DIR"), "/test_grammar.bin"));

    #[test]
    fn test_parse_static_tables() {
        let result = BinaryTables::from_bytes(TEST_GRAMMAR_BIN);
        assert!(
            result.is_ok(),
            "Failed to safely parse the static embedded grammar table via binrw!"
        );

        let safe_tables = result.unwrap();
        assert!(!safe_tables.states.is_empty(), "Test table has zero states?");
    }
}
