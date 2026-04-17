use crate::arena::NodeId;
use crate::parser_ctx::ParserContext;
use crate::types::ParseNode;
use crate::DispatchActionFn;

pub fn build_parse_tree<'a, G: 'static, N: 'static + Default + Clone>(
    ctx: &mut ParserContext<'a>,
    root_id: NodeId,
    parser: &mut crate::Parser<G, N>,
    dispatch_action: Option<DispatchActionFn<G, N>>,
) -> ParseNode<'a, N> {
    commit_tree(ctx, root_id, parser, dispatch_action)
}

fn commit_tree<'a, G: 'static, N: 'static + Default + Clone>(
    ctx: &mut ParserContext<'a>,
    mut pn_id: NodeId,
    parser: &mut crate::Parser<G, N>,
    dispatch_action: Option<DispatchActionFn<G, N>>,
) -> ParseNode<'a, N> {
    // Traverse LATEST
    loop {
        let node = ctx.pnode_arena.get(pn_id.0).unwrap();
        if let Some(l) = node.latest {
            pn_id = l;
        } else {
            break;
        }
    }

    let (ambiguities_opt, children_ids, safe_red_opt, start_s, end_s, end_skip_s) = {
        let pnode = ctx.pnode_arena.get_mut(pn_id.0).unwrap();
        pnode.evaluated = true;
        (pnode.ambiguities, pnode.children.clone(), pnode.reduction.clone(), pnode.start_loc.s, pnode.end_loc_s, pnode.end_skip_loc_s)
    };

    let string = if ctx.input.is_empty() {
        ""
    } else {
        let len = end_s - start_s;
        unsafe {
            std::str::from_utf8_unchecked(std::slice::from_raw_parts(
                ctx.input.as_ptr().add(start_s),
                len,
            ))
        }
    };

    let end_skip_string = if ctx.input.is_empty() {
        ""
    } else {
        let len = end_skip_s - end_s;
        unsafe {
            std::str::from_utf8_unchecked(std::slice::from_raw_parts(
                ctx.input.as_ptr().add(end_s),
                len,
            ))
        }
    };

    let mut shadow_node = ParseNode {
        symbol: ctx.pnode_arena.get(pn_id.0).unwrap().symbol,
        string,
        end_skip_string,
        start_loc: ctx.pnode_arena.get(pn_id.0).unwrap().start_loc.clone(),
        children: Vec::new(),
        user: N::default(),
    };

    // Handle ambiguities natively executing all competing derivations dynamically bounding slice
    if let Some(am_fn) = parser.ambiguity_fn {
        if ambiguities_opt.is_some() {
            let mut valid_alternatives = Vec::new();
            
            // Build the primary derivation completely recursively!
            let mut primary_shadow = shadow_node.clone();
            for child_id in children_ids.clone() {
                primary_shadow.children.push(commit_tree(ctx, child_id, parser, dispatch_action));
            }
            let mut primary_accepted = true;
            if let Some(safe_red) = safe_red_opt.clone() {
                if let Some(dispatch_fn) = dispatch_action {
                    let mut extracted_children = std::mem::take(&mut primary_shadow.children);
                    let ret = dispatch_fn(safe_red.action_index, &mut primary_shadow, &mut extracted_children, parser);
                    primary_shadow.children = extracted_children;
                    if ret == -1 {
                        primary_accepted = false;
                    }
                }
            }
            if primary_accepted {
                valid_alternatives.push(primary_shadow);
            }

            // Navigate identical alternative derivations organically!
            let mut curr = ambiguities_opt;
            while let Some(am_ptr) = curr {
                let (alt_children_ids, alt_safe_red, alt_next_ambig) = {
                    let am_node = ctx.pnode_arena.get(am_ptr.0).unwrap();
                    (am_node.children.clone(), am_node.reduction.clone(), am_node.ambiguities)
                };
                
                let mut alt_shadow = shadow_node.clone();
                for child_id in alt_children_ids {
                    alt_shadow.children.push(commit_tree(ctx, child_id, parser, dispatch_action));
                }
                
                let mut alt_accepted = true;
                if let Some(safe_red) = alt_safe_red {
                    if let Some(dispatch_fn) = dispatch_action {
                        let mut extracted_children = std::mem::take(&mut alt_shadow.children);
                        let ret = dispatch_fn(safe_red.action_index, &mut alt_shadow, &mut extracted_children, parser);
                        alt_shadow.children = extracted_children;
                        if ret == -1 {
                            alt_accepted = false;
                        }
                    }
                }
                if alt_accepted {
                    valid_alternatives.push(alt_shadow);
                }
                
                curr = alt_next_ambig;
            }

            if valid_alternatives.is_empty() {
                // If all paths natively bounded reject, we fallback mapped to default empty natively
                return shadow_node;
            }

            // Expose inherently overlapping alternatives cleanly to the designated selection logic natively!
            let selected_index = am_fn(parser, valid_alternatives.len(), &mut valid_alternatives);
            if selected_index < valid_alternatives.len() {
                return valid_alternatives.swap_remove(selected_index);
            } else {
                return valid_alternatives.swap_remove(0); // Fallback gracefully if bound improperly
            }
        }
    }

    // Recurse children normally for non-ambiguous single derivations implicitly!
    for child_id in children_ids {
        let child_container = commit_tree(ctx, child_id, parser, dispatch_action);
        shadow_node.children.push(child_container);
    }

    // Trigger final_code
    if let Some(safe_red) = safe_red_opt {
        if let Some(dispatch_fn) = dispatch_action {
            let action_idx = safe_red.action_index;
            let mut extracted_children = std::mem::take(&mut shadow_node.children);
            let ret = dispatch_fn(
                action_idx,
                &mut shadow_node,
                &mut extracted_children,
                parser,
            );
            shadow_node.children = extracted_children;
            // Native reject check safely passed bounds
            if ret == -1 {
                return shadow_node; // Mark node generically handled upstream inherently
            }
        }
    }

    shadow_node
}
