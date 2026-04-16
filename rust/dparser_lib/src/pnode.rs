//! `pnode.rs`
//! Explicit architectural boundaries for AST Node constructions natively avoiding pointers!
//! Handlers for disambiguation boundaries bridging shifts and reductions cleanly.

use crate::arena::NodeId;
use crate::arena::SNodeId;
use crate::bindings::{D_Reduction, D_Shift};
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
    reduction: Option<*mut D_Reduction>,
    _path: Option<Vec<crate::arena::ZNodeId>>, // Recursive bounds tracking bindings
    shift: Option<*mut D_Shift>,
) -> NodeId {
    let mut old_pn_id: Option<NodeId> = None;

    // Natively emulate `find_PNode` and `PNode_equal` tracking ambiguity matrices dynamically!
    // Simply linearly scanning bounds safely without hashtables for our structural tracking maps logically.
    for (id, pnode) in ctx.pnode_arena.iter() {
        let p_start_offset = if ctx.input_base_ptr.is_null() {
            pnode.parse_node.start_loc.s as usize
        } else {
            (pnode.parse_node.start_loc.s as usize).wrapping_sub(ctx.input_base_ptr as usize)
        };
        let p_end_offset = if ctx.input_base_ptr.is_null() {
            pnode.parse_node.end as usize
        } else {
            (pnode.parse_node.end as usize).wrapping_sub(ctx.input_base_ptr as usize)
        };

        if pnode.parse_node.symbol == symbol
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
        shift: shift,
        reduction: reduction,
        parse_node: crate::bindings::D_ParseNode {
            symbol,
            start_loc: crate::bindings::d_loc_t {
                s: if ctx.input_base_ptr.is_null() {
                    start_loc.s as *mut _
                } else {
                    unsafe { ctx.input_base_ptr.add(start_loc.s) as *mut _ }
                },
                ws: if ctx.input_base_ptr.is_null() {
                    start_loc.ws as *mut _
                } else {
                    unsafe { ctx.input_base_ptr.add(start_loc.ws) as *mut _ }
                },
                line: start_loc.line as i32,
                col: start_loc.col as i32,
                pathname: std::ptr::null_mut(),
            },
            end: if ctx.input_base_ptr.is_null() {
                end_loc_s as *mut _
            } else {
                unsafe { ctx.input_base_ptr.add(end_loc_s) as *mut _ }
            },
            end_skip: if ctx.input_base_ptr.is_null() {
                end_loc_s as *mut _
            } else {
                unsafe { ctx.input_base_ptr.add(end_loc_s) as *mut _ }
            },
            scope: std::ptr::null_mut(),
            user: std::ptr::null_mut(),
        },
    };

    // Evaluate explicit bounds mapping dynamically injecting shift priorities securely mimicking `reduce_actions`
    if let Some(sh) = shift {
        if !sh.is_null() {
            unsafe {
                new_pn.op_assoc = (*sh).op_assoc as u32;
                new_pn.op_priority = (*sh).op_priority;
            }
        }
    } else if let Some(r) = reduction {
        if !r.is_null() {
            unsafe {
                new_pn.op_assoc = (*r).op_assoc as u32;
                new_pn.op_priority = (*r).op_priority;
            }
        }

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
) -> SNodeId {
    let new_ps_id = crate::shift::get_or_create_snode(
        ctx,
        &mut std::collections::HashMap::new(),
        target_state_id,
        _loc,
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

        if !ctx.tables.is_null() {
            let target_state_cfg = unsafe {
                let offset = (*ctx.tables).state.add(target_state_id);
                &*offset
            };

            unsafe {
                for j in 0..target_state_cfg.reductions.n {
                    let r = *target_state_cfg.reductions.v.add(j as usize);
                    if (*r).nelements > 0 {
                        let red = crate::types::Reduction {
                            znode: z_id,
                            snode: new_ps_id,
                            new_snode: None,
                            new_depth: 0,
                            reduction_id: r as usize,
                        };
                        ctx.reductions_todo.push(red);
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
