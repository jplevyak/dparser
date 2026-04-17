//! `scan.rs`
//! Native Rust scanner loop. Reads memory byte-by-byte navigating the multi-dimensional
//! deterministic finite automata embedded in the `D_State` table exactly replicating `scan.c`.

use crate::binary_format::{D_SCAN_LONGEST, D_SCAN_MIXED, D_Shift};
use crate::types::Loc;

pub const SCANNER_BLOCKS: usize = 4;
pub const SCANNER_BLOCK_SHIFT: u8 = 6;
pub const SCANNER_BLOCK_MASK: u8 = 63;

/// Trait to safely traverse generic scanner sizes (uint8, uint16, uint32)
pub trait ScannerTable {
    unsafe fn next_state(&self, state: usize, sb: usize, so: usize) -> usize;
    unsafe fn shifts(&self, state: usize) -> *mut *mut D_Shift;
}

#[repr(C)]
struct SBUint8 {
    shift: *mut *mut D_Shift,
    scanner_block: [*mut u8; SCANNER_BLOCKS],
}

impl ScannerTable for *const SBUint8 {
    unsafe fn next_state(&self, state: usize, sb: usize, so: usize) -> usize {
        let st = self.add(state);
        let block_ptr = (*st).scanner_block[sb];
        if block_ptr.is_null() {
            0
        } else {
            *block_ptr.add(so) as usize
        }
    }
    unsafe fn shifts(&self, state: usize) -> *mut *mut D_Shift {
        (*self.add(state)).shift
    }
}

#[repr(C)]
struct SBUint16 {
    shift: *mut *mut D_Shift,
    scanner_block: [*mut u16; SCANNER_BLOCKS],
}

impl ScannerTable for *const SBUint16 {
    unsafe fn next_state(&self, state: usize, sb: usize, so: usize) -> usize {
        let st = self.add(state);
        let block_ptr = (*st).scanner_block[sb];
        if block_ptr.is_null() {
            0
        } else {
            *block_ptr.add(so) as usize
        }
    }
    unsafe fn shifts(&self, state: usize) -> *mut *mut D_Shift {
        (*self.add(state)).shift
    }
}

#[repr(C)]
struct SBUint32 {
    shift: *mut *mut D_Shift,
    scanner_block: [*mut u32; SCANNER_BLOCKS],
}

impl ScannerTable for *const SBUint32 {
    unsafe fn next_state(&self, state: usize, sb: usize, so: usize) -> usize {
        let st = self.add(state);
        let block_ptr = (*st).scanner_block[sb];
        if block_ptr.is_null() {
            0
        } else {
            *block_ptr.add(so) as usize
        }
    }
    unsafe fn shifts(&self, state: usize) -> *mut *mut D_Shift {
        (*self.add(state)).shift
    }
}

#[repr(C)]
struct SBTransUint8 {
    scanner_block: [*mut u8; SCANNER_BLOCKS],
}
#[repr(C)]
struct SBTransUint16 {
    scanner_block: [*mut u16; SCANNER_BLOCKS],
}
#[repr(C)]
struct SBTransUint32 {
    scanner_block: [*mut u32; SCANNER_BLOCKS],
}

#[derive(Clone, Debug)]
pub struct ShiftResult {
    pub loc: Loc,
    pub shift: crate::grammar::GrammarShift,
}

pub fn scan_buffer(
    input: &[u8],
    starting_loc: Loc,
    parse_state: &crate::grammar::GrammarState,
) -> Vec<ShiftResult> {
    let mut results = Vec::new();
    let mut loc = starting_loc;
    let mut last_loc = starting_loc;

    let mut shift_ptr: *mut *mut D_Shift = std::ptr::null_mut();

    if parse_state.scanner_table == 0 {
        // Fallback for missing scanner table mappings explicitly native
    } else {
        let mut execute_scan =
            |st: &dyn ScannerTable, get_trans: &dyn Fn(usize, usize, usize) -> usize| {
                let mut state = 0;
                let mut last_state = 0;
                let mut prev = 0;

                // Loop purely through characters matching the boundary of the `input` slice
                // `loc.s` maps to actual parsed offset locally safely
                while loc.s < input.len() {
                    let c = input[loc.s];
                    let sb = (c >> SCANNER_BLOCK_SHIFT) as usize;
                    let so = (c & SCANNER_BLOCK_MASK) as usize;

                    unsafe {
                        let next = st.next_state(state, sb, so);
                        if next == 0 {
                            break;
                        }
                        state = next - 1;

                        // Process differential `accepts_diff` table branches if embedded natively inside state node
                        if prev > 0 && parse_state.accepts_diff != 0 {
                            let trans_idx = get_trans(prev, sb, so);
                            let accepts_diff_raw = parse_state.accepts_diff as *mut *mut *mut D_Shift;
                            let mut diff_ptr = *accepts_diff_raw.add(trans_idx);
                            while !diff_ptr.is_null() && !(*diff_ptr).is_null() {
                                
                                let c_diff = &**diff_ptr;
                                let spec_raw: isize = std::mem::transmute(c_diff.speculative_code);

                                let safe_shift = crate::grammar::GrammarShift {
                                    symbol: c_diff.symbol,
                                    shift_kind: c_diff.shift_kind,
                                    op_assoc: c_diff.op_assoc,
                                    op_priority: c_diff.op_priority,
                                    term_priority: c_diff.term_priority,
                                    action_index: c_diff.action_index,
                                    speculative_code: spec_raw as i32,
                                };

                                results.push(ShiftResult {
                                    loc,
                                    shift: safe_shift,
                                });
                                diff_ptr = diff_ptr.add(1);
                            }
                        }

                        prev = state;

                        if c == b'\n' {
                            loc.line += 1;
                            loc.col = 0;
                        } else {
                            loc.col += 1;
                        }
                        loc.s += 1;

                        let current_shift = st.shifts(state);
                        if !current_shift.is_null() {
                            last_state = state;
                            last_loc = loc;
                        }
                    }
                }

                unsafe {
                    shift_ptr = st.shifts(last_state);
                }
            };

        unsafe {
            match parse_state.scanner_size {
                1 => {
                    let st = parse_state.scanner_table as *const SBUint8;
                    let tst = parse_state.transition_table as *const SBTransUint8;
                    let trans_fn = |p: usize, sb: usize, so: usize| {
                        if (*tst.add(p)).scanner_block[sb].is_null() {
                            0
                        } else {
                            *(*tst.add(p)).scanner_block[sb].add(so) as usize
                        }
                    };
                    execute_scan(&st, &trans_fn);
                }
                2 => {
                    let st = parse_state.scanner_table as *const SBUint16;
                    let tst = parse_state.transition_table as *const SBTransUint16;
                    let trans_fn = |p: usize, sb: usize, so: usize| {
                        if (*tst.add(p)).scanner_block[sb].is_null() {
                            0
                        } else {
                            *(*tst.add(p)).scanner_block[sb].add(so) as usize
                        }
                    };
                    execute_scan(&st, &trans_fn);
                }
                4 => {
                    let st = parse_state.scanner_table as *const SBUint32;
                    let tst = parse_state.transition_table as *const SBTransUint32;
                    let trans_fn = |p: usize, sb: usize, so: usize| {
                        if (*tst.add(p)).scanner_block[sb].is_null() {
                            0
                        } else {
                            *(*tst.add(p)).scanner_block[sb].add(so) as usize
                        }
                    };
                    execute_scan(&st, &trans_fn);
                }
                _ => {
                    return Vec::new();
                }
            }
        }
    }

    if !shift_ptr.is_null() {
        unsafe {
            let mut ptr = shift_ptr;
            while !(*ptr).is_null() {
                let c_shift = &**ptr;
                let spec_raw: isize = std::mem::transmute(c_shift.speculative_code);

                let safe_shift = crate::grammar::GrammarShift {
                    symbol: c_shift.symbol,
                    shift_kind: c_shift.shift_kind,
                    op_assoc: c_shift.op_assoc,
                    op_priority: c_shift.op_priority,
                    term_priority: c_shift.term_priority,
                    action_index: c_shift.action_index,
                    speculative_code: spec_raw as i32,
                };

                results.push(ShiftResult {
                    loc: last_loc,
                    shift: safe_shift,
                });
                ptr = ptr.add(1);
            }
        }
    }

    // Filter Longest/Mixed natively
    if !results.is_empty() {
        let mut longest = false;
        let scan_kind_longest = D_SCAN_LONGEST as u8;
        let scan_kind_mixed = D_SCAN_MIXED as u8;

        let end_idx = results.last().unwrap().loc.s;
        if parse_state.scan_kind == scan_kind_longest {
            longest = true;
        } else if parse_state.scan_kind == scan_kind_mixed {
            for res in results.iter().rev() {
                if res.loc.s < end_idx {
                    break;
                }
                if res.shift.shift_kind == scan_kind_longest {
                    longest = true;
                }
            }
        }

        if longest {
            results.retain(|r| r.loc.s == end_idx);
        }
    }

    results
}
