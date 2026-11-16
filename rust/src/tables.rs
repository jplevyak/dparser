//! `tables.rs`
//! Loads the binary tables written by `make_dparser -B`.

use crate::binary_format::{D_ParserTables, D_Reduction};
use crate::grammar::*;
use binrw::{BinRead, BinReaderExt};
use std::collections::HashMap;
use std::ffi::{c_char, c_void};
use std::io::Cursor;

#[derive(BinRead, Copy, Clone, Debug)]
pub struct BinaryTablesHead {
    pub n_relocs: i32,
    pub n_strings: i32,
    pub d_parser_tables_loc: i32,
    pub tables_size: i32,
    pub strings_size: i32,
}

pub struct BinaryTables;

/// The relocated table buffer: every pointer read from it is checked to lie
/// inside it.
struct Buffer {
    base: usize,
    size: usize,
}

impl Buffer {
    fn contains(&self, ptr: usize, len: usize) -> bool {
        ptr >= self.base && len <= self.size && ptr - self.base <= self.size - len
    }

    fn check<T>(&self, ptr: *const T, count: usize) -> Result<(), &'static str> {
        let len = count
            .checked_mul(std::mem::size_of::<T>())
            .ok_or("Table array is too large")?;
        if count == 0 || self.contains(ptr as usize, len) {
            Ok(())
        } else {
            Err("Table pointer outside of the tables buffer")
        }
    }

    unsafe fn slice<'b, T>(&self, ptr: *const T, count: usize) -> Result<&'b [T], &'static str> {
        if count == 0 || ptr.is_null() {
            return Ok(&[]);
        }
        self.check(ptr, count)?;
        Ok(unsafe { std::slice::from_raw_parts(ptr, count) })
    }

    unsafe fn c_string(&self, ptr: *const c_char) -> Result<Vec<u8>, &'static str> {
        if ptr.is_null() {
            return Ok(Vec::new());
        }
        let start = ptr as usize;
        if !self.contains(start, 1) {
            return Err("String outside of the tables buffer");
        }
        let max = self.base + self.size - start;
        let bytes = unsafe { std::slice::from_raw_parts(ptr as *const u8, max) };
        match bytes.iter().position(|&b| b == 0) {
            Some(n) => Ok(bytes[..n].to_vec()),
            None => Err("Unterminated string in the tables buffer"),
        }
    }
}

impl BinaryTables {
    pub fn from_bytes(bytes: &[u8]) -> Result<SafeGrammarTables, &'static str> {
        let mut cursor = Cursor::new(bytes);

        let head: BinaryTablesHead = cursor
            .read_le()
            .map_err(|_| "Binary tables file is too short to contain header")?;
        if head.tables_size < 0 || head.strings_size < 0 || head.n_relocs < 0 || head.n_strings < 0 {
            return Err("Invalid binary tables header");
        }

        let offset = cursor.position() as usize;
        let buf_size = (head.tables_size as usize) + (head.strings_size as usize);

        if bytes.len() < offset + buf_size {
            return Err("Binary tables file is truncated inside tables buffer");
        }

        // An aligned copy of the tables, in which pointers are relocated.
        let u64_count = buf_size.div_ceil(8);
        let mut aligned_vec: Vec<u64> = vec![0; u64_count];
        let byte_slice = bytemuck::cast_slice_mut::<u64, u8>(&mut aligned_vec);
        byte_slice[..buf_size].copy_from_slice(&bytes[offset..offset + buf_size]);

        cursor.set_position((offset + buf_size) as u64);

        let tables_buf = aligned_vec.as_mut_ptr() as *mut u8;
        let strings_buf = unsafe { tables_buf.add(head.tables_size as usize) };
        let ptr_size = std::mem::size_of::<*mut c_void>() as isize;

        let read_offset = |cursor: &mut Cursor<&[u8]>, what: &'static str| -> Result<isize, &'static str> {
            if std::mem::size_of::<isize>() == 8 {
                cursor.read_le::<i64>().map(|v| v as isize).map_err(|_| what)
            } else {
                cursor.read_le::<i32>().map(|v| v as isize).map_err(|_| what)
            }
        };

        unsafe {
            for _ in 0..head.n_relocs {
                let reloc_offset = read_offset(&mut cursor, "Truncated relocations array")?;
                if reloc_offset < 0 || reloc_offset + ptr_size > head.tables_size as isize {
                    return Err("Invalid table relocation offset");
                }
                let intptr_ptr = tables_buf.offset(reloc_offset) as *mut isize;
                let val = std::ptr::read_unaligned(intptr_ptr);
                // -1 is NULL; -2 and -3 mark speculative and final code, which
                // is dispatched by action index, and -4 marks external code
                // (scanners, whitespace functions): they stay as markers.
                if val == -1 {
                    std::ptr::write_unaligned(intptr_ptr, 0);
                } else if !(-4..=-2).contains(&val) {
                    std::ptr::write_unaligned(intptr_ptr, val + tables_buf as isize);
                }
            }

            for _ in 0..head.n_strings {
                let reloc_offset = read_offset(&mut cursor, "Truncated string relocations array")?;
                if reloc_offset < 0 || reloc_offset + ptr_size > head.tables_size as isize {
                    return Err("Invalid string relocation offset");
                }
                let intptr_ptr = tables_buf.offset(reloc_offset) as *mut isize;
                let val = std::ptr::read_unaligned(intptr_ptr);
                std::ptr::write_unaligned(intptr_ptr, val + strings_buf as isize);
            }
        }

        if head.d_parser_tables_loc < 0
            || head.d_parser_tables_loc as usize + std::mem::size_of::<D_ParserTables>() > head.tables_size as usize
        {
            return Err("Invalid d_parser_tables_loc");
        }
        let tables = unsafe { tables_buf.add(head.d_parser_tables_loc as usize) as *const D_ParserTables };
        let buffer = Buffer { base: tables_buf as usize, size: buf_size };

        let mut safe_tables = unsafe { Self::build_safe_tables(&*tables, &buffer)? };
        safe_tables._binary_data = aligned_vec;
        Ok(safe_tables)
    }

    unsafe fn build_safe_tables(
        tables: &D_ParserTables,
        buf: &Buffer,
    ) -> Result<SafeGrammarTables, &'static str> {
        let nstates = tables.nstates as usize;
        let nsymbols = tables.nsymbols as usize;
        let state_arr = unsafe { buf.slice(tables.state, nstates)? };
        let nvalid_bytes = nsymbols.div_ceil(8);

        // Reductions are shared between states; identify them by address.
        let mut reductions: Vec<GrammarReduction> = Vec::new();
        let mut reduction_ids: HashMap<usize, ReductionId> = HashMap::new();
        let mut reduction_id = |ptr: *const D_Reduction| -> Result<ReductionId, &'static str> {
            if let Some(&id) = reduction_ids.get(&(ptr as usize)) {
                return Ok(id);
            }
            buf.check(ptr, 1)?;
            let c_red = unsafe { &*ptr };
            let id = reductions.len() as ReductionId;
            reductions.push(GrammarReduction {
                nelements: c_red.nelements,
                symbol: c_red.symbol,
                action_index: c_red.action_index,
                op_assoc: c_red.op_assoc,
                rule_assoc: c_red.rule_assoc,
                op_priority: c_red.op_priority,
                rule_priority: c_red.rule_priority,
            });
            reduction_ids.insert(ptr as usize, id);
            Ok(id)
        };

        let mut safe_states = Vec::with_capacity(nstates);
        let mut goto_len = 0usize;
        for c_st in state_arr {
            let goto_valid = unsafe { buf.slice(c_st.goto_valid, nvalid_bytes)? }.to_vec();
            if !goto_valid.is_empty() {
                for sym in 0..nsymbols {
                    if goto_valid[sym >> 3] & (1 << (sym & 7)) != 0 {
                        let idx = sym as i64 - c_st.goto_table_offset as i64;
                        if idx < 0 {
                            return Err("Invalid goto table offset");
                        }
                        goto_len = goto_len.max(idx as usize + 1);
                    }
                }
            }

            let mut state_reductions = Vec::new();
            for &red_ptr in unsafe { buf.slice(c_st.reductions.v, c_st.reductions.n as usize)? } {
                state_reductions.push(reduction_id(red_ptr)?);
            }

            let mut right_epsilon_hints = Vec::new();
            for c_rep in unsafe { buf.slice(c_st.right_epsilon_hints.v, c_st.right_epsilon_hints.n as usize)? } {
                if c_rep.preceeding_state as usize >= nstates {
                    return Err("Invalid right epsilon hint state");
                }
                right_epsilon_hints.push(GrammarRightEpsilonHint {
                    depth: c_rep.depth,
                    preceeding_state: c_rep.preceeding_state,
                    reduction: reduction_id(c_rep.reduction)?,
                });
            }

            let mut error_recovery_hints = Vec::new();
            for c_erh in
                unsafe { buf.slice(c_st.error_recovery_hints.v, c_st.error_recovery_hints.n as usize)? }
            {
                error_recovery_hints.push(GrammarErrorRecoveryHint {
                    depth: c_erh.depth,
                    symbol: c_erh.symbol,
                    string: unsafe { buf.c_string(c_erh.string)? },
                });
            }

            if !c_st.scanner_table.is_null() && !buf.contains(c_st.scanner_table as usize, 1) {
                return Err("Scanner table outside of the tables buffer");
            }
            if !matches!(c_st.scanner_size, 0 | 1 | 2 | 4) {
                return Err("Invalid scanner size");
            }

            safe_states.push(GrammarState {
                goto_valid,
                goto_table_offset: c_st.goto_table_offset,
                reductions: state_reductions,
                right_epsilon_hints,
                error_recovery_hints,
                has_shifts: c_st.shifts != 0,
                has_scanner_code: c_st.scanner_code.is_some(),
                accept: c_st.accept != 0,
                reduces_to: c_st.reduces_to,
                scan_kind: c_st.scan_kind,
                scanner_size: c_st.scanner_size,
                scanner_table: c_st.scanner_table as usize,
                transition_table: c_st.transition_table as usize,
                accepts_diff: c_st.accepts_diff as usize,
            });
        }

        let goto_table = unsafe { buf.slice(tables.goto_table, goto_len)? }.to_vec();
        for st in &safe_states {
            for sym in 0..nsymbols {
                if st.goto_valid.get(sym >> 3).is_some_and(|b| b & (1 << (sym & 7)) != 0) {
                    let target = goto_table[(sym as i64 - st.goto_table_offset as i64) as usize] as usize;
                    if target == 0 || target > nstates {
                        return Err("Invalid goto table entry");
                    }
                }
            }
        }

        let mut symbols = Vec::with_capacity(nsymbols);
        for s in unsafe { buf.slice(tables.symbols, nsymbols)? } {
            let name = unsafe { buf.c_string(s.name)? };
            symbols.push(GrammarSymbol {
                kind: s.kind,
                name: String::from_utf8_lossy(&name).into_owned(),
                start_symbol: s.start_symbol,
            });
        }

        let mut passes = Vec::new();
        for p in unsafe { buf.slice(tables.passes, tables.npasses as usize)? } {
            let name = unsafe { buf.c_string(p.name)? };
            passes.push(GrammarPass {
                name: String::from_utf8_lossy(&name).into_owned(),
                kind: p.kind,
                index: p.index,
            });
        }

        if tables.whitespace_state as usize >= nstates.max(1) {
            return Err("Invalid whitespace state");
        }

        Ok(SafeGrammarTables {
            symbol_kinds: symbols.iter().map(|s| s.kind).collect(),
            states: safe_states,
            goto_table,
            reductions,
            whitespace_state: tables.whitespace_state,
            has_default_white_space: !tables.default_white_space.is_null(),
            save_parse_tree: tables.save_parse_tree != 0,
            symbols,
            passes,
            _binary_data: Vec::new(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    pub const TEST_GRAMMAR_BIN: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/test_grammar.bin"));

    #[test]
    fn test_parse_static_tables() {
        let safe_tables = BinaryTables::from_bytes(TEST_GRAMMAR_BIN).expect("tables load");
        assert!(!safe_tables.states.is_empty(), "Test table has zero states?");
        assert!(!safe_tables.symbols.is_empty());
        assert!(!safe_tables.goto_table.is_empty());
    }

    #[test]
    fn truncated_tables_are_rejected() {
        assert!(BinaryTables::from_bytes(&TEST_GRAMMAR_BIN[..10]).is_err());
        assert!(BinaryTables::from_bytes(&TEST_GRAMMAR_BIN[..TEST_GRAMMAR_BIN.len() / 2]).is_err());
    }
}
