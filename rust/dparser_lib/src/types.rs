//! `types.rs`
//! Primary internal graph node types mapped to native safe Rust structures via Arena IDs.

use crate::arena::{NodeId, SNodeId, ZNodeId};

pub type AssocKind = u32;

/// A locational trace tied to a byte array offset
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Loc {
    pub s: usize,   // string pointer or offset
    pub ws: usize,  // whitespace mapped offset
    pub line: u32,
    pub col: u32,
}

// DParseNode replaced directly with bindings::D_ParseNode to safely map C memory mappings exactly!
pub type DParseNode = crate::bindings::D_ParseNode;

/// The internal structural Parse Node (PNode)
#[derive(Clone, Debug)]
pub struct PNode {
    pub hash: u32,
    pub assoc: AssocKind,
    pub priority: i32,
    pub op_assoc: AssocKind,
    pub op_priority: i32,
    pub height: u32,
    pub evaluated: bool,
    pub error_recovery: bool,
    
    pub children: Vec<NodeId>,
    pub ambiguities: Option<NodeId>,
    pub latest: Option<NodeId>,
    
    pub shift: Option<*mut crate::bindings::D_Shift>,
    pub reduction: Option<*mut crate::bindings::D_Reduction>,
    
    pub parse_node: crate::bindings::D_ParseNode,
}

/// State Node tracking parser iterations iteratively tracking Graph Stacks
#[derive(Clone, Debug)]
pub struct SNode {
    pub loc: Loc,
    pub depth: u32,
    pub in_error_recovery_queue: bool,
    pub state_id: usize, // Identifier mapped to D_State equivalent index
    
    pub last_pn: Option<NodeId>,
    pub zns: Vec<ZNodeId>,
}

/// Graph Traversal / Link Nodes mapping parallel GSS evaluations
#[derive(Clone, Debug)]
pub struct ZNode {
    pub pn: Option<NodeId>,
    pub sns: Vec<SNodeId>,
}

/// Tracking Shift transitions in GSS
#[derive(Clone, Debug)]
pub struct Shift {
    pub snode: SNodeId,
}

/// Tracking Reduction branches to trace down GSS paths dynamically
#[derive(Clone, Debug)]
pub struct Reduction {
    pub znode: Option<ZNodeId>,
    pub snode: SNodeId,
    pub new_snode: Option<SNodeId>,
    pub new_depth: i32,
    pub reduction_id: usize, // Target reduction instruction ID from Tables
}
