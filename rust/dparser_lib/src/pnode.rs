//! `pnode.rs`
//! Explicit architectural boundaries for AST Node constructions natively avoiding pointers!
//! Handlers for disambiguation boundaries bridging shifts and reductions cleanly.

use crate::arena::NodeId;
use crate::arena::SNodeId;
use crate::parser_ctx::ParserContext;
use crate::types::{Loc, PNode};
// Temporary SNode mappings

/// Emulates `insert_PNode` and `make_PNode`. Safely retrieves an existing identical
/// `PNode` from the parallel evaluation branch mapping, building out ambiguity resolutions.
pub fn add_pnode(
    ctx: &mut ParserContext,
    symbol: i32,
    start_loc: Loc,
    end_loc_s: usize,
    _last_pn: Option<NodeId>, // Parent structural bindings
    reduction: Option<crate::grammar::GrammarReduction>,
    _pass_code: Option<i32>,
    _path: Option<Vec<crate::arena::ZNodeId>>, // Recursive bounds tracking bindings
    shift: Option<crate::grammar::GrammarShift>,
) -> NodeId {
    let mut old_pn_id: Option<NodeId> = None;

    // Natively emulate `find_PNode` and `PNode_equal` tracking ambiguity matrices dynamically!
    // Simply linearly scanning bounds safely without hashtables for our structural tracking maps logically.
    for (id, pnode) in ctx.pnode_arena.iter() {
        // Track physical node offsets matching legacy layout gracefully based on slices!
        let p_start_offset = pnode.start_loc.s;
        
        let p_end_offset = pnode.end_loc_s;

        if pnode.symbol == symbol
            && p_start_offset == start_loc.s
            && p_end_offset == end_loc_s
        {
            // Validation bounds matched!
            old_pn_id = Some(NodeId(id));
            break;
        }
    }

    // Allocate the structurally matched `PNode`
    let mut new_pn = PNode {
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
        shift: shift.clone(),
        reduction: reduction.clone(),
        symbol: symbol as i32,
        start_loc,
        end_loc_s,
        end_skip_loc_s: end_loc_s,
    };

    // Evaluate explicit bounds mapping dynamically injecting shift priorities securely mimicking `reduce_actions`
    if let Some(sh) = &shift {
        new_pn.op_assoc = sh.op_assoc as u32;
        new_pn.op_priority = sh.op_priority;
    } else if let Some(r) = &reduction {
        new_pn.op_assoc = r.op_assoc as u32;
        new_pn.op_priority = r.op_priority;

        // Populate children natively avoiding pointers natively!
        if let Some(p) = _path {
            for z_id in p.iter().rev() {
                let node = ctx.znode_arena.get(z_id.0).unwrap().pn;
                if let Some(c_id) = node {
                    new_pn.children.push(c_id);
                }
            }
        }
    }

    let allocated_id = NodeId(ctx.pnode_arena.alloc(new_pn));
    ctx.stats_pnodes += 1;

    // Fallback ambiguity tracking matrix natively evaluating overlaps correctly cleanly
    if let Some(old_id) = old_pn_id {
        // Run disambiguation comparisons!
        let cmp_result = crate::priority::cmp_pnodes(&ctx.pnode_arena, allocated_id, old_id);

        match cmp_result {
            0 => {
                // Ambiguous bounds mathematically equivalent - Track as parallel overlaps!
                let old_amb = ctx.pnode_arena.get(old_id.0).unwrap().ambiguities;
                ctx.pnode_arena.get_mut(allocated_id.0).unwrap().ambiguities = old_amb;
                ctx.pnode_arena.get_mut(old_id.0).unwrap().ambiguities = Some(allocated_id);
                return old_id;
            }
            -1 => {
                // We matched a shorter boundary mapping successfully overriding earlier logic dynamically
                ctx.pnode_arena.get_mut(old_id.0).unwrap().latest = Some(allocated_id);
                return allocated_id; // Replacement mappings bounds
            }
            1 => {
                // Discard structurally inferior node functionally mapped (not implemented arena freeing mapping natively)
                return old_id;
            }
            _ => {
                return old_id;
            }
        }
    }

    allocated_id
}

/// Natively triggers `SNode` branch evaluations extending graphs cleanly natively propagating states.
/// Mirrors `goto_PNode` tracking the transitions explicit bindings natively avoiding pointer mappings exactly!
pub fn goto_pnode(
    ctx: &mut ParserContext,
    _loc: Loc,
    pn_id: NodeId,
    ps_id: SNodeId,
    target_state_id: usize,
    tables: Option<&crate::grammar::SafeGrammarTables>,
) -> SNodeId {
    let new_ps_id = crate::shift::get_or_create_snode(
        ctx,
        &mut std::collections::HashMap::new(),
        target_state_id,
        _loc,
        tables,
    );

    // Bind previous limits implicitly assigning AST connections elegantly cleanly!
    ctx.snode_arena.get_mut(new_ps_id.0).unwrap().last_pn = Some(pn_id);

    // `ZNode` bindings resolving dynamically explicitly linking `pre_ps` configurations natively mappings
    // This executes reductions dynamically triggering cascading Tomita sequences elegantly!
    let mut z_id: Option<crate::arena::ZNodeId> = None;
    let new_snode = ctx.snode_arena.get_mut(new_ps_id.0).unwrap();

    for z in new_snode.zns.iter() {
        if ctx.znode_arena.get(z.0).unwrap().pn == Some(pn_id) {
            z_id = Some(*z);
            break;
        }
    }

    if z_id.is_none() {
        let z = crate::types::ZNode {
            pn: Some(pn_id),
            sns: Vec::new(),
        };
        let new_z_id = crate::arena::ZNodeId(ctx.znode_arena.alloc(z));
        ctx.snode_arena
            .get_mut(new_ps_id.0)
            .unwrap()
            .zns
            .push(new_z_id);
        z_id = Some(new_z_id);

        if let Some(safe_tables) = tables {
            if target_state_id < safe_tables.states.len() {
                let target_state_cfg = &safe_tables.states[target_state_id];
                for red in &target_state_cfg.reductions {
                    if red.nelements > 0 {
                        let map_red = crate::types::Reduction {
                            znode: z_id,
                            snode: new_ps_id,
                            new_snode: None,
                            new_depth: 0,
                            reduction: red.clone(),
                        };
                        ctx.reductions_todo.push(map_red);
                    }
                }
            }
        }
    }

    let znode = ctx.znode_arena.get_mut(z_id.unwrap().0).unwrap();
    if !znode.sns.contains(&ps_id) {
        znode.sns.push(ps_id);
    }

    new_ps_id
}
