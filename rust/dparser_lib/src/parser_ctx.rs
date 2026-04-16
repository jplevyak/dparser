//! `parser_ctx.rs`
//! The GLR memory and state execution context wrapping safely allocated Arenas.

use crate::arena::{Arena, SNodeId};
use crate::types::{PNode, Reduction, SNode, Shift, ZNode};

pub struct ParserContext<'a> {
    pub input: &'a [u8],

    // Core Graph Allocated Pools replacing DParser `freelists` natively
    pub pnode_arena: Arena<PNode>,
    pub snode_arena: Arena<SNode>,
    pub znode_arena: Arena<ZNode>,

    // Core GLR algorithmic parallel tracking sets
    pub reductions_todo: Vec<Reduction>,
    pub shifts_todo: Vec<Shift>,

    pub error_reductions: Vec<Reduction>,

    pub accept_snode: Option<SNodeId>,
    pub last_syntax_error_line: i32,

    // Stat Tracking
    pub stats_states: u32,
    pub stats_pnodes: u32,
    pub stats_scans: u32,
    pub stats_shifts: u32,
    pub stats_reductions: u32,
    pub stats_compares: u32,
    pub stats_ambiguities: u32,
}

impl<'a> ParserContext<'a> {
    pub fn new(
        input: &'a [u8],
    ) -> Self {
        Self {
            input,

            pnode_arena: Arena::with_capacity(2048),
            snode_arena: Arena::with_capacity(1024),
            znode_arena: Arena::with_capacity(1024),

            reductions_todo: Vec::new(),
            shifts_todo: Vec::new(),
            error_reductions: Vec::new(),

            accept_snode: None,
            last_syntax_error_line: 0,

            stats_states: 0,
            stats_pnodes: 0,
            stats_scans: 0,
            stats_shifts: 0,
            stats_reductions: 0,
            stats_compares: 0,
            stats_ambiguities: 0,
        }
    }
}
