//! `priority.rs`
//! Implements DParser's core disambiguation engine safely inside the mapping Arena boundaries.
//! Evaluates GLR overlapping tree branches explicitly using Tomita's logic recursively matching bounds.

use crate::arena::{Arena, NodeId};
use crate::types::PNode;

/// Compares raw element priorities identically to `compare_priorities`.
fn compare_priorities(arena: &Arena<PNode>, pvx: &[NodeId], pvy: &[NodeId]) -> i32 {
    let mut i = 0;
    while i < pvx.len() && i < pvy.len() {
        let x = arena.get(pvx[i].0).unwrap();
        let y = arena.get(pvy[i].0).unwrap();

        if x.priority > y.priority {
            return -1;
        }
        if x.priority < y.priority {
            return 1;
        }
        i += 1;
    }

    0
}

pub fn cmp_priorities(arena: &Arena<PNode>, pn0_id: NodeId, pn1_id: NodeId) -> i32 {
    let (mut pvx, mut pvy) = get_unshared_pnodes(arena, Some(pn0_id), Some(pn1_id));

    let priority_cmp = |a: &NodeId, b: &NodeId| -> std::cmp::Ordering {
        let x = arena.get(a.0).unwrap();
        let y = arena.get(b.0).unwrap();

        // sort those with no priority to the bottom
        let x_assoc = if x.assoc != 0 { 1 } else { 0 };
        let y_assoc = if y.assoc != 0 { 1 } else { 0 };
        let assoc_cmp = x_assoc.cmp(&y_assoc);
        if assoc_cmp != std::cmp::Ordering::Equal {
            return assoc_cmp.reverse();
        } // higher assoc first

        // by smallest height
        let h_cmp = x.height.cmp(&y.height);
        if h_cmp != std::cmp::Ordering::Equal {
            return h_cmp;
        } // smaller height first

        // by highest priority
        let p_cmp = x.priority.cmp(&y.priority);
        if p_cmp != std::cmp::Ordering::Equal {
            return p_cmp.reverse();
        } // higher priority first

        // by earliest start
        let s_cmp = x.start_loc.s.cmp(&y.start_loc.s);
        if s_cmp != std::cmp::Ordering::Equal {
            return s_cmp;
        }

        // by longest length
        let l_cmp = x.end_loc_s.cmp(&y.end_loc_s);
        if l_cmp != std::cmp::Ordering::Equal {
            return l_cmp.reverse();
        }

        std::cmp::Ordering::Equal
    };

    pvx.sort_by(priority_cmp);
    pvy.sort_by(priority_cmp);

    compare_priorities(arena, &pvx, &pvy)
}

pub fn cmp_pnodes(arena: &Arena<PNode>, pn0_id: NodeId, pn1_id: NodeId) -> i32 {
    let x = arena.get(pn0_id.0).unwrap();
    let y = arena.get(pn1_id.0).unwrap();

    if x.assoc != 0 && y.assoc != 0 {
        let r = cmp_priorities(arena, pn0_id, pn1_id);
        if r != 0 {
            return r;
        }
    }

    let r = cmp_greediness(arena, pn0_id, pn1_id);
    if r != 0 {
        return r;
    }

    let x_height = arena.get(pn0_id.0).unwrap().height;
    let y_height = arena.get(pn1_id.0).unwrap().height;

    if x_height < y_height {
        return -1;
    }
    if x_height > y_height {
        return 1;
    }

    0
}

use std::collections::{BinaryHeap, HashSet};

#[derive(Clone, Copy, Eq, PartialEq)]
struct HeightNode(u32, NodeId);

impl Ord for HeightNode {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.0.cmp(&other.0) // Max-heap natively prioritizing highest trees
    }
}

impl PartialOrd for HeightNode {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

/// Natively explores AST branches mathematically ignoring identically shared nodes
/// avoiding repetitive graph calculations over DParser limits natively.
fn get_unshared_pnodes(
    arena: &Arena<PNode>,
    mut x: Option<NodeId>,
    mut y: Option<NodeId>,
) -> (Vec<NodeId>, Vec<NodeId>) {
    let mut hx: BinaryHeap<HeightNode> = BinaryHeap::new();
    let mut hy: BinaryHeap<HeightNode> = BinaryHeap::new();

    let mut sx = HashSet::new();
    let mut sy = HashSet::new();

    if let Some(n) = x {
        sx.insert(n.0);
    }
    if let Some(n) = y {
        sy.insert(n.0);
    }

    loop {
        if x.is_none() && y.is_none() {
            break;
        }

        let x_height = x.map_or(0, |id| arena.get(id.0).unwrap().height);
        let y_height = y.map_or(0, |id| arena.get(id.0).unwrap().height);

        if y.is_none() || (x.is_some() && x_height > y_height) {
            let x_id = x.unwrap();
            let pn = arena.get(x_id.0).unwrap();

            if !sy.contains(&x_id.0) {
                for child_id in &pn.children {
                    if sx.insert(child_id.0) {
                        // Set Addition
                        if !sy.contains(&child_id.0) {
                            let ch_node = arena.get(child_id.0).unwrap();
                            hx.push(HeightNode(ch_node.height, *child_id));
                        }
                    }
                }
            }
            x = hx.pop().map(|n| n.1);
        } else {
            let y_id = y.unwrap();
            let pn = arena.get(y_id.0).unwrap();

            if !sx.contains(&y_id.0) {
                for child_id in &pn.children {
                    if sy.insert(child_id.0) {
                        if !sx.contains(&child_id.0) {
                            let ch_node = arena.get(child_id.0).unwrap();
                            hy.push(HeightNode(ch_node.height, *child_id));
                        }
                    }
                }
            }
            y = hy.pop().map(|n| n.1);
        }
    }

    let mut pvx = Vec::new();
    for id in sx.iter() {
        if !sy.contains(id) {
            pvx.push(NodeId(*id));
        }
    }

    let mut pvy = Vec::new();
    for id in sy.iter() {
        if !sx.contains(id) {
            pvy.push(NodeId(*id));
        }
    }

    (pvx, pvy)
}
pub fn cmp_greediness(arena: &Arena<PNode>, pn0_id: NodeId, pn1_id: NodeId) -> i32 {
    let (mut pvx, mut pvy) = get_unshared_pnodes(arena, Some(pn0_id), Some(pn1_id));

    // Natively sort the slices using the greedy criteria matching DParser exactly!
    let greedy_cmp = |a: &NodeId, b: &NodeId| -> std::cmp::Ordering {
        let x = arena.get(a.0).unwrap();
        let y = arena.get(b.0).unwrap();

        // first by earliest start
        let cmp1 = x.start_loc.s.cmp(&y.start_loc.s);
        if cmp1 != std::cmp::Ordering::Equal {
            return cmp1;
        }

        // second by symbol
        let cmp2 = x.symbol.cmp(&y.symbol);
        if cmp2 != std::cmp::Ordering::Equal {
            return cmp2;
        }

        // third by length
        let x_len = x.end_loc_s;
        let y_len = y.end_loc_s;

        let cmp3 = x_len.cmp(&y_len);
        if cmp3 != std::cmp::Ordering::Equal {
            return cmp3;
        } // matching standard C cmp bounds.

        std::cmp::Ordering::Equal
    };

    pvx.sort_by(greedy_cmp);
    pvy.sort_by(greedy_cmp);

    let mut ix = 0;
    let mut iy = 0;

    loop {
        if ix >= pvx.len() || iy >= pvy.len() {
            return 0;
        }

        let x_id = pvx[ix];
        let y_id = pvy[iy];

        if x_id.0 == y_id.0 {
            ix += 1;
            iy += 1;
            continue;
        }

        let x = arena.get(x_id.0).unwrap();
        let y = arena.get(y_id.0).unwrap();

        if x.start_loc.s < y.start_loc.s {
            ix += 1;
        } else if x.start_loc.s > y.start_loc.s {
            iy += 1;
        } else if x.symbol < y.symbol {
            ix += 1;
        } else if x.symbol > y.symbol {
            iy += 1;
        } else if x.end_loc_s > y.end_loc_s {
            return -1;
        } else if x.end_loc_s < y.end_loc_s {
            return 1;
        } else if x.children.len() < y.children.len() {
            return -1;
        } else if x.children.len() > y.children.len() {
            return 1;
        } else {
            ix += 1;
            iy += 1;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::arena::{Arena, NodeId};
    use crate::types::{Loc, PNode};

    #[test]
    fn test_cmp_greediness_bounds() {
        let mut pnodes = Arena::new();

        // Setup mock trees structurally overlapping matching identical offsets precisely
        let pn0 = PNode {
            hash: 0,
            assoc: 1, // IS_LEFT_ASSOC mock
            priority: 2,
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
            symbol: 10,
            start_loc: Loc {
                s: 0,
                ws: 0,
                line: 1,
                col: 1,
            },
            end_loc_s: 5,
            end_skip_loc_s: 5,
        };

        let pn1 = pn0.clone();
        let mut pn2 = pn1.clone();
        pn2.end_loc_s = 4; // Shorter sequence inherently!
        let pn1_id = NodeId(pnodes.alloc(pn1));
        let pn2_id = NodeId(pnodes.alloc(pn2));

        let result = cmp_greediness(&pnodes, pn1_id, pn2_id);

        // Assert native behavior natively bounds checks successfully preferring pn1
        assert_eq!(result, -1);
    }
}
