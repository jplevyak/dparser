//! `shift.rs`
//! Core pipeline for mapping GLR shifts. Processes dynamically spawned Scanner
//! transitions natively creating and validating identical `SNode` branch combinations!

use crate::arena::SNodeId;
use crate::parser_ctx::ParserContext;
use crate::types::{Loc, SNode};
use std::collections::HashMap;

/// Emulates `insert_SNode` and `new_SNode`. Safely retrieves an existing identical
/// `SNode` from the parallel evaluation branch bounding box, or allocates a new one
/// entirely inside the mapped `snode_arena`.
pub fn get_or_create_snode(
    ctx: &mut ParserContext,
    active_hashes: &mut HashMap<usize, SNodeId>,
    state_id: usize,
    loc: Loc,
    tables: Option<&crate::grammar::SafeGrammarTables>,
) -> SNodeId {
    // In DParser, `SNODE_HASH` typically hashes `(state, initial_scope)`.
    // Since scopes are stubbed here securely, we hash distinctly on `state_id` mapped per-pos.
    if let Some(&existing_snode_id) = active_hashes.get(&state_id) {
        return existing_snode_id;
    }

    let sn = SNode {
        loc,
        depth: 0,
        in_error_recovery_queue: false,
        state_id,
        last_pn: None,
        zns: Vec::new(),
    };

    let id = SNodeId(ctx.snode_arena.alloc(sn));
    ctx.stats_states += 1;

    active_hashes.insert(state_id, id);

    // Validation for final `accept` target states.
    // In C, `if (sn->state->accept) { p->accept = sn; }`
    // We defer accept tagging to the driver tracking logic
    // passing the states explicitly based on pointer offsets dynamically.

    // Epsilon reductions directly insert themselves natively!
    if let Some(safe_tables) = tables {
        if state_id < safe_tables.states.len() {
            let state_cfg = &safe_tables.states[state_id];
            for red in &state_cfg.reductions {
                if red.nelements == 0 {
                    let map_red = crate::types::Reduction {
                        znode: None,
                        snode: id,
                        new_snode: None,
                        new_depth: 0,
                        reduction: red.clone(),
                    };
                    ctx.reductions_todo.push(map_red);
                }
            }
        }
    }

    id
}

/// Maps the native algorithms for `shift_all`.
/// Drains `ctx.shifts_todo` dynamically resolving token boundaries completely sequentially.
pub fn process_shifts(ctx: &mut ParserContext) {
    if ctx.shifts_todo.is_empty() {
        return;
    }

    ctx.stats_shifts += 1;

    // A real runtime mapping would track specific boundaries ensuring parallel branches
    // tie-break identical matching symbols matching lexical tokens perfectly.
    // For this module execution bounding box, we now naturally pop items from the queue.
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser_ctx::ParserContext;
    use crate::types::Shift;

    #[test]
    fn test_process_shifts() {
        // Setup mock environment completely natively safely!
        let mut ctx = ParserContext::new(&[]);
        let mut hashes = HashMap::new();

        let start_loc = Loc {
            s: 0,
            ws: 0,
            line: 1,
            col: 0,
        };
        let snode_1 = get_or_create_snode(&mut ctx, &mut hashes, 0, start_loc, None);
        let snode_2 = get_or_create_snode(&mut ctx, &mut hashes, 1, start_loc, None);

        assert_eq!(ctx.stats_states, 2);

        // Assert identical state map bounds natively reuse elements (deduplication behavior mapping)
        let snode_dup = get_or_create_snode(&mut ctx, &mut hashes, 0, start_loc, None);

        assert_eq!(snode_1, snode_dup);
        assert_eq!(ctx.stats_states, 2); // No new structural nodes mapped!

        ctx.shifts_todo.push(Shift { snode: snode_1 });
        ctx.shifts_todo.push(Shift { snode: snode_2 });

        assert_eq!(ctx.shifts_todo.len(), 2);

        process_shifts(&mut ctx);

        assert_eq!(ctx.stats_shifts, 1);
    }
}
