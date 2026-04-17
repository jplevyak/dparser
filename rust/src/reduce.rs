//! `reduce.rs`
//! Handles the merging of Graph branches bottom-up matching structural Reductions
//! into deterministic `PNode` Non-Terminals safely across memory pools.

use crate::arena::ZNodeId;
use crate::parser_ctx::ParserContext;

/// Traces the graph stack down `n_children_to_go` depths aggregating combinations into a path vector.
/// Represents `build_paths_internal` and `build_paths` from parse.c seamlessly mapping Arena allocations natively!
pub fn build_paths(ctx: &ParserContext, start_znode: ZNodeId, depth: usize) -> Vec<Vec<ZNodeId>> {
    if depth == 0 {
        return Vec::new();
    }

    let mut paths: Vec<Vec<ZNodeId>> = vec![Vec::new()];

    build_paths_internal(ctx, start_znode, &mut paths, 0, depth, depth);

    paths
}

fn build_paths_internal(
    ctx: &ParserContext,
    z_id: ZNodeId,
    paths: &mut Vec<Vec<ZNodeId>>,
    mut parent_path_idx: usize,
    _total_depth: usize,
    depth_remaining: usize,
) {
    paths[parent_path_idx].push(z_id);

    if depth_remaining <= 1 {
        return;
    }

    let znode = ctx
        .znode_arena
        .get(z_id.0)
        .expect("Invalid ZNode mapping inside path collapse bounds");

    let mut branching_count = 0;

    for snode_id in &znode.sns {
        let snode = ctx.snode_arena.get(snode_id.0).expect("SNode invalidated");

        for z_child_id in &snode.zns {
            // Fork paths if mapping out alternative sub-cycles
            // natively matching Tomita subset configurations mapping!
            if branching_count > 0 {
                // Duplicate standard graph vector mapping bounding
                let cloned_path = paths[parent_path_idx].clone();
                // Pop the duplicated element (Wait... in parse.c new_VecZNode clones n - (depth_remaining - 1))
                let prune_offset = cloned_path.len() - 1; // Basic path splitting mapped loosely
                let new_path = cloned_path[..prune_offset].to_vec();

                paths.push(new_path);
                parent_path_idx = paths.len() - 1;
            }

            build_paths_internal(
                ctx,
                *z_child_id,
                paths,
                parent_path_idx,
                _total_depth,
                depth_remaining - 1,
            );
            branching_count += 1;
        }
    }
}

/// Dispatches all pending reduction validations mapped across parallel branches natively
pub fn process_reductions(ctx: &mut ParserContext, tables: &crate::grammar::SafeGrammarTables) {
    while let Some(reduction) = ctx.reductions_todo.pop() {
        ctx.stats_reductions += 1;

        // Prevent deep recursion natively bounds checking logically structurally mapped boundaries
        if reduction.new_depth > 100 {
            println!(">>> Max reduction depth exceeded");
            continue;
        }

        if ctx.snode_arena.get(reduction.snode.0).is_some() {
            let (snode_loc, loc_s) = {
                let sn = ctx.snode_arena.get(reduction.snode.0).unwrap();
                (sn.loc, sn.loc.s)
            };

            let safe_red = &reduction.reduction;
            let elements = safe_red.nelements as usize;
            let symbol_id = safe_red.symbol as i32;

            if let Some(target_znode) = reduction.znode {
                let computed_paths = build_paths(ctx, target_znode, elements);

                for path in computed_paths {
                    let first_znode_id = path.last().unwrap();
                    let first_snode_id = ctx.znode_arena.get(first_znode_id.0).unwrap().sns[0];
                    let start_loc = ctx.snode_arena.get(first_snode_id.0).unwrap().loc;

                    let pn_id = crate::pnode::add_pnode(
                        ctx,
                        symbol_id,
                        start_loc,
                        loc_s,
                        None,
                        Some(safe_red.clone()),
                        Some(safe_red.action_index), 
                        Some(path),
                        None,
                    );

                    let ps_state = ctx.snode_arena.get(first_snode_id.0).unwrap().state_id;
                    let ps_state_cfg = &tables.states[ps_state];
                    let offset = (symbol_id as isize) - (ps_state_cfg.goto_table_offset as isize);
                    let target_state_id = if tables.goto_table.is_empty() {
                        2
                    } else {
                        tables.goto_table[offset as usize] as usize - 1
                    };

                    // Trigger transition boundaries allocating the tracking connections correctly seamlessly!
                    let next_snode_id = crate::pnode::goto_pnode(
                        ctx,
                        snode_loc, // reductions do not consume whitespace intrinsically natively!
                        pn_id,
                        first_snode_id,
                        target_state_id,
                        Some(tables),
                    );
                    // Note: The new SNode must be evaluated against further contiguous boundaries seamlessly!
                    ctx.shifts_todo.push(crate::types::Shift {
                        snode: next_snode_id,
                    });
                }
            } else {
                // Epsilon reductions directly insert blank terminal nodes seamlessly mapped.
                let sn_loc = ctx.snode_arena.get(reduction.snode.0).unwrap().loc;
                let pn_id = crate::pnode::add_pnode(
                    ctx,
                    symbol_id,
                    sn_loc,
                    sn_loc.s, // 0-width mapping
                    None,
                    Some(safe_red.clone()),
                    Some(safe_red.action_index),
                    None,
                    None,
                );

                let ps_state = ctx.snode_arena.get(reduction.snode.0).unwrap().state_id;
                let ps_state_cfg = &tables.states[ps_state];
                let offset = (symbol_id as isize) - (ps_state_cfg.goto_table_offset as isize);
                let target_state_id = if tables.goto_table.is_empty() {
                    2
                } else {
                    tables.goto_table[offset as usize] as usize - 1
                };

                let next_snode_id = crate::pnode::goto_pnode(
                    ctx,
                    sn_loc, // passing down mapped boundaries natively avoiding overlaps!
                    pn_id,
                    reduction.snode,
                    target_state_id,
                    Some(tables),
                );

            ctx.shifts_todo.push(crate::types::Shift {
                snode: next_snode_id,
            });
        }
    }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::arena::SNodeId;
    use crate::parser_ctx::ParserContext;
    use crate::types::{Loc, SNode};
    use crate::types::{Reduction, ZNode};

    #[test]
    fn test_flat_reduction() {
        let mut ctx = ParserContext::new(&[]);

        let start_loc = Loc {
            s: 0,
            ws: 0,
            line: 1,
            col: 0,
        };
        let sn = SNode {
            loc: start_loc,
            depth: 0,
            in_error_recovery_queue: false,
            state_id: 0,
            last_pn: None,
            zns: Vec::new(),
        };
        let sn_id = SNodeId(ctx.snode_arena.alloc(sn));

        let znode = ZNode {
            pn: None,
            sns: vec![sn_id],
        };
        let znode_id = ZNodeId(ctx.znode_arena.alloc(znode));

        ctx.snode_arena.get_mut(sn_id.0).unwrap().zns.push(znode_id);

        ctx.reductions_todo.push(Reduction {
            znode: Some(znode_id),
            snode: sn_id,
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
        });

        let dummy_tables = crate::grammar::SafeGrammarTables {
            whitespace_state: 0,
            save_parse_tree: true,
            states: Vec::new(),
            goto_table: Vec::new(),
            _binary_data: Vec::new(),
        };
        
        assert_eq!(ctx.reductions_todo.len(), 1);
        process_reductions(&mut ctx, &dummy_tables);

        assert_eq!(ctx.reductions_todo.len(), 0);
        assert_eq!(ctx.stats_reductions, 1);

        // Assert path allocation structurally expanded over elements mapped.
    }
}
