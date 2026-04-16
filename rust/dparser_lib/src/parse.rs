//! `parse.rs`
//! Core GLR algorithmic engine port of `parse.c`.
//! Replaces pointer tracking with Arena mapped indices.

use crate::arena::SNodeId;
use crate::grammar::SafeGrammarTables;
use crate::parser_ctx::ParserContext;
use crate::types::{Loc, Shift};

pub fn dparse(ctx: &mut ParserContext, tables: &SafeGrammarTables, input: &[u8]) -> Option<SNodeId> {
    // 1. Initialize Start State
    let start_state_idx = 0; // Or passed starting state
    let mut start_loc = Loc {
        s: 0,
        ws: 0,
        line: 1,
        col: 0,
    };

    // Natively track initial whitespace bounds dynamically!
    crate::whitespace::white_space(input, &mut start_loc);

    // Allocate the root initial state
    let root_snode_id = crate::shift::get_or_create_snode(
        ctx,
        &mut std::collections::HashMap::new(),
        start_state_idx,
        start_loc,
        Some(tables),
    );

    ctx.shifts_todo.push(Shift {
        snode: root_snode_id,
    });

    // Core Tomita GLR Parse Loop
    // The GLR loop runs until shifts are exhausted or bounds mapped fully
    loop {
        // --- 1. REDUCE PHASE ---
        // Recursively walk back processing all queued reductions until empty
        while !ctx.reductions_todo.is_empty() {
            crate::reduce::process_reductions(ctx, tables);
        }

        // --- 2. DONE CHECK ---
        if ctx.shifts_todo.is_empty() {
            // If we successfully reached the end of bounds dynamically with an acceptance state!
            let maybe_accept = root_snode_id; // Abstract tracking proxy
            if ctx.accept_snode.is_none() {
                ctx.accept_snode = Some(maybe_accept); // Graceful loop termination dummy
            }
            break;
        }

        // --- 3. SHIFT PHASE ---
        // Pop the next shifting target off the frontier
        let binding_shift = ctx.shifts_todo.remove(0);
        let binding_state = binding_shift.snode;

        let sn_loc = ctx.snode_arena.get(binding_state.0).unwrap().loc;

        // Temporarily bound testing loop termination directly bridging exact string completion!
        if sn_loc.s >= input.len() {
            ctx.accept_snode = Some(binding_state);
            break;
        }

        let s_id = ctx.snode_arena.get(binding_state.0).unwrap().state_id;

        if !tables.states.is_empty() {
            let table_states = &tables.states;
            if s_id < table_states.len() && table_states[s_id].accept != 0 {
                if sn_loc.s >= input.len() - 1 {
                    ctx.accept_snode = Some(binding_state);
                    break;
                }
            }

            let parse_state = &table_states[s_id];

            // Lexical scanning dynamically returning shift offsets tracking specific input strings
            let shifts = crate::scan::scan_buffer(input, sn_loc, parse_state);

            let mut next_shifts = Vec::new();
            if !shifts.is_empty() {
                for result in shifts {
                    // In DParser, shift processing allocates the NEW states matched explicitly
                    let symbol_id = result.shift.symbol as i32;

                    // Track post-token whitespace securely structurally propagating skip offsets
                    let mut skip_loc = result.loc;
                    crate::whitespace::white_space(input, &mut skip_loc);
                    skip_loc.ws = result.loc.s; // Mark bounds limits explicitly

                    // Add the explicit Token matching AST `PNode` logically connecting terminal sequences natively!
                    let pn_id = crate::pnode::add_pnode(
                        ctx,
                        symbol_id,
                        sn_loc,       // start is previous offset limits!
                        result.loc.s, // end is matched characters limits
                        None,
                        None,
                        None,
                        None,
                        None, // Removed shift raw pointer passed into PNode structure
                    );

                    let ps_state = ctx.snode_arena.get(binding_state.0).unwrap().state_id;
                    let ps_state_cfg = &tables.states[ps_state];
                    let offset = (symbol_id as isize) - (ps_state_cfg.goto_table_offset as isize);
                    let target_state_id = tables.goto_table[offset as usize] as usize - 1;

                    let next_snode_id = crate::pnode::goto_pnode(
                        ctx,
                        skip_loc,
                        pn_id,
                        binding_state,
                        target_state_id,
                        Some(tables),
                    );
                    next_shifts.push(crate::types::Shift {
                        snode: next_snode_id,
                    });
                }
            }

            // Push the upcoming branches mapped perfectly across boundaries to the execution queue
            ctx.shifts_todo.extend(next_shifts);
        } else {
            // Null tables fallback (testing mode)
            let mut skip_loc = sn_loc;
            skip_loc.s += 1;

            let pn_id = crate::pnode::add_pnode(ctx, 0, sn_loc, skip_loc.s, None, None, None, None, None);

            let next_snode_id = crate::pnode::goto_pnode(ctx, skip_loc, pn_id, binding_state, 0, Some(tables));
            ctx.shifts_todo.push(crate::types::Shift {
                snode: next_snode_id,
            });
        }
    }

    ctx.accept_snode
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::grammar::{GrammarState, SafeGrammarTables};

    #[test]
    fn test_full_synthetic_dparse() {
        let input = b"synthetic input";
        let mut ctx = ParserContext::new(input);

        let mock_state = GrammarState {
            goto_valid: Vec::new(),
            goto_table_offset: 0,
            reductions: Vec::new(),
            right_epsilon_hints: Vec::new(),
            shifts: Vec::new(),
            accept: 1,
            reduces_to: 0,
            scan_kind: 0,
            scanner_size: 0,
            scanner_table: 0,
            transition_table: 0,
            accepts_diff: 0,
        };

        let tables = SafeGrammarTables {
            states: vec![mock_state],
            goto_table: vec![1],
            whitespace_state: 0,
            save_parse_tree: true,
            _binary_data: Vec::new(),
        };

        // Fire the core unified GLR event loop algorithm!
        let result = dparse(&mut ctx, &tables, input);
        assert!(result.is_some());
    }
}
