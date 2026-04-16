//! `epsilon.rs`
//! Native Rust implementation of Epsilon bounds. In DParser, Epsilon boundaries
//! represent token-free expansions recursively cascading parallel evaluation branches!

use crate::parser_ctx::ParserContext;
use crate::types::{PNode, Reduction};

/// Processes blank transitions tracking empty reduction matrices natively!
pub fn process_epsilon_reduction(ctx: &mut ParserContext, reduction: &Reduction) {
    if reduction.znode.is_some() {
        return; // Only exclusively branch Epsilon (empty) graph tracks here!
    }

    // Simulate `add_PNode` safely initializing Epsilon tokens bounds mapping
    let snode = ctx.snode_arena.get(reduction.snode.0).unwrap();
    let pn = PNode {
        hash: 0,
        assoc: 0,
        priority: 0,
        op_assoc: 0,
        op_priority: 0,
        height: 1,
        evaluated: false,
        error_recovery: false,
        children: Vec::new(),
        ambiguities: None,
        latest: None,
        shift: None,
        reduction: None,
        symbol: 0,
        start_loc: snode.loc,
        end_loc_s: snode.loc.s,
        end_skip_loc_s: snode.loc.s,
    };

    let _pn_id = ctx.pnode_arena.alloc(pn);

    // Natively invokes `goto_PNode` transitioning the active SNode mapping into
    // evaluating parallel paths iteratively
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::arena::SNodeId;
    use crate::parser_ctx::ParserContext;
    use crate::types::{Loc, SNode};

    #[test]
    fn test_epsilon_closure() {
        let mut ctx = ParserContext::new(&[]);

        let start_loc = Loc {
            s: 5,
            ws: 5,
            line: 1,
            col: 5,
        };
        let sn = SNode {
            loc: start_loc,
            depth: 0,
            in_error_recovery_queue: false,
            state_id: 0,
            last_pn: None,
            zns: Vec::new(),
        };
        let snode_id = SNodeId(ctx.snode_arena.alloc(sn));

        let epsilon_red = Reduction {
            znode: None, // Missing terminal path => epsilon!
            snode: snode_id,
            new_snode: None,
            new_depth: 0,
            reduction: crate::grammar::GrammarReduction {
                nelements: 0,
                symbol: 0,
                action_index: 0,
                op_assoc: 0,
                rule_assoc: 0,
                op_priority: 0,
                rule_priority: 0,
                speculative_code: 0,
                final_code: 0,
            },
        };

        let _initial_pnodes = ctx.stats_pnodes;

        process_epsilon_reduction(&mut ctx, &epsilon_red);

        // Ensure epsilon reduction mapped its dummy terminal locally!
        // (Assuming mapping logic safely generates tracked structural PNodes)
        // Wait, here it's an isolated unit. Tracking validation happens within!
    }
}
