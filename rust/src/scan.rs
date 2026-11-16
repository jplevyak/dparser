//! `scan.rs`
//! The scanner: runs a state's DFA over the input, as `scan.c` does.

use crate::binary_format::D_Shift;
use crate::grammar::{D_SCAN_LONGEST, D_SCAN_MIXED, D_SCAN_TRAILING, GrammarShift, GrammarState};
use crate::types::Loc;

pub const SCANNER_BLOCKS: usize = 4;
pub const SCANNER_BLOCK_SHIFT: u8 = 6;
pub const SCANNER_BLOCK_MASK: u8 = 63;

/// One terminal matched by the scanner: where it ends, and the `D_Shift`
/// (identified by its address in the tables).
#[derive(Clone, Copy, Debug)]
pub struct ShiftResult {
    pub loc: Loc,
    pub shift: usize,
}

/// Read the shift at `addr` (a `D_Shift` in the tables).
pub fn read_shift(addr: usize) -> GrammarShift {
    let s = unsafe { &*(addr as *const D_Shift) };
    GrammarShift {
        symbol: s.symbol,
        shift_kind: s.shift_kind,
        op_assoc: s.op_assoc,
        op_priority: s.op_priority,
        term_priority: s.term_priority,
        action_index: s.action_index,
        has_speculative_code: !s.speculative_code.is_null(),
    }
}

#[repr(C)]
struct SB<T> {
    shift: *mut *mut D_Shift,
    scanner_block: [*mut T; SCANNER_BLOCKS],
}

#[repr(C)]
struct SBTrans<T> {
    scanner_block: [*mut T; SCANNER_BLOCKS],
}

trait Cell: Copy {
    fn get(self) -> usize;
}
impl Cell for u8 {
    fn get(self) -> usize {
        self as usize
    }
}
impl Cell for u16 {
    fn get(self) -> usize {
        self as usize
    }
}
impl Cell for u32 {
    fn get(self) -> usize {
        self as usize
    }
}

/// Run the DFA; returns the shift list of the last accepting state.
unsafe fn run<T: Cell>(
    input: &[u8],
    end: usize,
    loc: &mut Loc,
    last_loc: &mut Loc,
    parse_state: &GrammarState,
    results: &mut Vec<ShiftResult>,
) -> *mut *mut D_Shift {
    let st = parse_state.scanner_table as *const SB<T>;
    let tst = parse_state.transition_table as *const SBTrans<T>;
    let accepts_diff = parse_state.accepts_diff as *const *const *const D_Shift;
    let (mut state, mut last, mut prev) = (0usize, 0usize, 0usize);
    let mut s = loc.s;
    let (mut line, mut col) = (loc.line, loc.col);
    // Characters at or beyond 'end' read as '\0', which has no transitions.
    let next_char = |s: &mut usize| -> u8 {
        let c = if *s < end { input[*s] } else { 0 };
        *s += 1;
        c
    };
    let mut c = next_char(&mut s);
    loop {
        let sb = (c >> SCANNER_BLOCK_SHIFT) as usize;
        let so = (c & SCANNER_BLOCK_MASK) as usize;
        let block = unsafe { (*st.add(state)).scanner_block[sb] };
        let next = if block.is_null() { 0 } else { unsafe { (*block.add(so)).get() } };
        if next == 0 || s > end {
            break;
        }
        state = next - 1;
        if prev != 0 && !accepts_diff.is_null() {
            let tblock = unsafe { (*tst.add(prev)).scanner_block[sb] };
            let t = if tblock.is_null() { 0 } else { unsafe { (*tblock.add(so)).get() } };
            let mut diff = unsafe { *accepts_diff.add(t) };
            while !diff.is_null() && unsafe { !(*diff).is_null() } {
                results.push(ShiftResult { loc: *loc, shift: unsafe { *diff } as usize });
                diff = unsafe { diff.add(1) };
            }
        }
        prev = state;
        if c == b'\n' {
            line += 1;
            col = 0;
        } else {
            col += 1;
        }
        loc.s = s;
        loc.line = line;
        loc.col = col;
        if unsafe { !(*st.add(state)).shift.is_null() } {
            last = state;
            *last_loc = *loc;
        }
        c = next_char(&mut s);
    }
    unsafe { (*st.add(last)).shift }
}

/// Scan from `starting_loc` in `parse_state`, as `scan_buffer` in scan.c.
pub fn scan_buffer(input: &[u8], end: usize, starting_loc: Loc, parse_state: &GrammarState) -> Vec<ShiftResult> {
    let mut results = Vec::new();
    scan_buffer_into(input, end, starting_loc, parse_state, &mut results);
    results
}

/// As [`scan_buffer`], appending the results to `out`.
pub fn scan_buffer_into(
    input: &[u8],
    end: usize,
    starting_loc: Loc,
    parse_state: &GrammarState,
    out: &mut Vec<ShiftResult>,
) {
    if parse_state.scanner_table == 0 {
        return;
    }
    let base = out.len();
    let mut loc = starting_loc;
    let mut last_loc = starting_loc;
    let shift = unsafe {
        match parse_state.scanner_size {
            1 => run::<u8>(input, end, &mut loc, &mut last_loc, parse_state, out),
            2 => run::<u16>(input, end, &mut loc, &mut last_loc, parse_state, out),
            4 => run::<u32>(input, end, &mut loc, &mut last_loc, parse_state, out),
            _ => std::ptr::null_mut(),
        }
    };
    if !shift.is_null() {
        let mut p = shift;
        unsafe {
            while !(*p).is_null() {
                out.push(ShiftResult { loc: last_loc, shift: *p as usize });
                p = p.add(1);
            }
        }
    }
    if out.len() == base {
        return;
    }
    let kind = |r: &ShiftResult| read_shift(r.shift).shift_kind;
    let end_s = out[out.len() - 1].loc.s;
    let mut longest = parse_state.scan_kind == D_SCAN_LONGEST;
    let mut i = out.len();
    if parse_state.scan_kind == D_SCAN_MIXED {
        // results[base..i] end before end_s
        while i > base && out[i - 1].loc.s >= end_s {
            if kind(&out[i - 1]) == D_SCAN_LONGEST {
                longest = true;
            }
            i -= 1;
        }
    }
    let keep = |out: &mut Vec<ShiftResult>, f: &dyn Fn(usize, &ShiftResult) -> bool| {
        let mut w = base;
        for r in base..out.len() {
            if f(r, &out[r]) {
                out[w] = out[r];
                w += 1;
            }
        }
        out.truncate(w);
    };
    if longest {
        // keep only 'longest' (and trailing context)
        keep(out, &|_, r| r.loc.s == end_s || kind(r) == D_SCAN_TRAILING);
    } else if parse_state.scan_kind == D_SCAN_MIXED {
        // only keep non-longest among the shorter matches; the matches ending
        // at end_s (none of them longest) are all kept
        keep(out, &|j, r| j >= i || kind(r) != D_SCAN_LONGEST);
    }
}
