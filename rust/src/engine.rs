//! `engine.rs`
//! The GLR parsing engine: a port of `parse.c`.
//!
//! Parse nodes (PNode), stack nodes (SNode) and links (ZNode) live in vectors
//! and refer to each other by index.  The algorithms, and the order in which
//! they visit nodes, follow parse.c so that disambiguation gives the same
//! results as the C runtime.

use smallvec::SmallVec;
use std::collections::{HashMap, HashSet, VecDeque};
use std::rc::Rc;

use crate::grammar::*;
use crate::scan::{ShiftResult, read_shift, scan_buffer_into};
use crate::symtab::ScopeId;
use crate::types::{Loc, ParseNode};
use crate::{ActionKind, Parser};

// AssocKind bits (gram.h)
const ASSOC_LEFT: u32 = 0x0001;
const ASSOC_RIGHT: u32 = 0x0002;
const ASSOC_NARY: u32 = 0x0004;
const ASSOC_UNARY: u32 = 0x0008;
const ASSOC_BINARY: u32 = 0x0010;
const ASSOC_NO: u32 = 0x0020;
const ASSOC_UNARY_RIGHT: u32 = ASSOC_UNARY | ASSOC_RIGHT;

fn is_right_assoc(x: u32) -> bool {
    x & ASSOC_RIGHT != 0
}
fn is_left_assoc(x: u32) -> bool {
    x & ASSOC_LEFT != 0
}
fn is_nary_assoc(x: u32) -> bool {
    x & ASSOC_NARY != 0
}
fn is_binary_assoc(x: u32) -> bool {
    x & ASSOC_BINARY != 0
}
fn is_unary_assoc(x: u32) -> bool {
    x & ASSOC_UNARY != 0
}
fn is_unary_binary_assoc(x: u32) -> bool {
    is_binary_assoc(x) || is_unary_assoc(x)
}
fn is_binary_nary_assoc(x: u32) -> bool {
    is_binary_assoc(x) || is_nary_assoc(x)
}

const D_PRIME2: [usize; 29] = [
    1, 3, 7, 13, 31, 61, 127, 251, 509, 1021, 2039, 4093, 8191, 16381, 32749, 65521, 131071, 262139, 524287,
    1048573, 2097143, 4194301, 8388593, 16777213, 33554393, 67108859, 134217689, 268435399, 536870909,
];
const INTEGRAL_VEC_SIZE: usize = 3;
const INITIAL_SET_SIZE_INDEX: usize = 2;
const SET_MAX_SEQUENTIAL: usize = 5;
const ERROR_RECOVERY_QUEUE_SIZE: usize = 10000;
/// Tag for the ids of shifts made by external scanners (table shifts are
/// identified by their address).
const CODE_SHIFT: usize = 1 << (usize::BITS - 1);

/// A fast hasher for the node tables (FxHash).
#[derive(Default, Clone, Copy)]
pub(crate) struct FxHasher(u64);

impl std::hash::Hasher for FxHasher {
    fn write(&mut self, bytes: &[u8]) {
        for &b in bytes {
            self.write_u64(b as u64);
        }
    }
    fn write_u64(&mut self, i: u64) {
        self.0 = (self.0.rotate_left(5) ^ i).wrapping_mul(0x51_7c_c1_b7_27_22_0a_95);
    }
    fn write_usize(&mut self, i: usize) {
        self.write_u64(i as u64);
    }
    fn write_u32(&mut self, i: u32) {
        self.write_u64(i as u64);
    }
    fn finish(&self) -> u64 {
        self.0
    }
}

type FxBuild = std::hash::BuildHasherDefault<FxHasher>;
type FxHashMap<K, V> = HashMap<K, V, FxBuild>;

/// Collect unreachable nodes once at least this many have been allocated
/// since the last collection (and at least as many as were live after it).
const GC_MIN_ALLOCS: usize = 1 << 16;

pub(crate) type PId = usize;

/// The PNodes with the same key: almost always one.
enum Bucket {
    One(PId),
    Many(Vec<PId>),
}

impl Bucket {
    fn len(&self) -> usize {
        match self {
            Bucket::One(_) => 1,
            Bucket::Many(v) => v.len(),
        }
    }
    fn get(&self, i: usize) -> PId {
        match self {
            Bucket::One(p) => *p,
            Bucket::Many(v) => v[i],
        }
    }
    fn push(&mut self, p: PId) {
        match self {
            Bucket::One(q) => *self = Bucket::Many(vec![*q, p]),
            Bucket::Many(v) => v.push(p),
        }
    }
}
type SId = usize;
/// A path down the parse stack, as built for a reduction.
type Path = SmallVec<[ZId; 8]>;
type ZId = usize;

/// A reduction: an index into the tables' reductions, followed by the
/// reductions synthesized by error recovery.
type RedId = u32;

pub(crate) struct PNode<N> {
    pub symbol: u32,
    pub start: Loc,
    pub end: usize,
    pub end_skip: usize,
    pub scope: ScopeId,
    pub initial_scope: ScopeId,
    pub assoc: u32,
    pub priority: i32,
    pub op_assoc: u32,
    pub op_priority: i32,
    pub height: u32,
    pub serial: u32,
    pub children: SmallVec<[PId; 4]>,
    pub ambiguities: Option<PId>,
    pub latest: PId,
    pub reduction: Option<RedId>,
    /// The `D_Shift` (by address) for a terminal.
    pub shift: Option<usize>,
    pub evaluated: bool,
    pub error_recovery: bool,
    pub user: N,
}

/// The set of ZNodes of an SNode: a short vector which becomes an open
/// addressed hash table keyed by PNode serial (as `set_add_znode` in parse.c).
#[derive(Default, Clone)]
struct ZSet {
    v: SmallVec<[Option<ZId>; 3]>,
    i: usize,
}

struct SNode {
    state: usize,
    initial_scope: ScopeId,
    loc: Loc,
    depth: u32,
    in_error_recovery_queue: bool,
    last_pn: Option<PId>,
    zns: ZSet,
}

struct ZNode {
    pn: PId,
    sns: SmallVec<[SId; 2]>,
}

#[derive(Clone)]
struct RedTodo {
    znode: Option<ZId>,
    snode: SId,
    reduction: RedId,
    new_snode: Option<SId>,
    new_depth: usize,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum WsMode {
    Builtin,
    User,
    Subparser,
    Null,
}

#[derive(Default, Clone, Copy, Debug)]
pub struct Stats {
    pub states: u32,
    pub scans: u32,
    pub shifts: u32,
    pub reductions: u32,
    pub compares: u32,
    pub ambiguities: u32,
}

pub(crate) struct Engine<'a, N> {
    t: Rc<SafeGrammarTables>,
    text: &'a str,
    input: &'a [u8],
    pub start: usize,
    pub end: usize,
    /// The parser location (`p->user.loc`): the start, then the error location.
    pub loc: Loc,

    pn: Vec<PNode<N>>,
    sn: Vec<SNode>,
    zn: Vec<ZNode>,

    snode_hash: FxHashMap<(usize, ScopeId), SId>,
    snode_all: Vec<SId>,
    snode_last_all: Vec<SId>,
    pnode_hash: FxHashMap<(usize, usize, u32, ScopeId), Bucket>,
    pnode_all: Vec<PId>,

    reductions_todo: VecDeque<RedTodo>,
    shifts_todo: VecDeque<SId>,
    pub accept: Option<SId>,
    error_reductions: Vec<GrammarReduction>,
    serial: u32,
    last_syntax_error_line: u32,
    pub top_scope: ScopeId,

    ws_mode: WsMode,
    ws_parser: Option<Box<Engine<'a, N>>>,
    partial_parses: bool,
    error_recovery: bool,
    shift_cache: FxHashMap<usize, GrammarShift>,
    /// Shifts made by external scanners, identified by CODE_SHIFT | index.
    code_shifts: Vec<GrammarShift>,
    // buffers reused by shift_all
    shift_results: Vec<(Loc, Option<usize>, SId)>,
    scan_results: Vec<ShiftResult>,

    committed: FxHashMap<PId, ParseNode<'a, N>>,
    pub stats: Stats,

    // node slots freed by gc(), for reuse
    free_pn: Vec<PId>,
    free_sn: Vec<SId>,
    free_zn: Vec<ZId>,
    allocs_since_gc: usize,
    live_after_gc: usize,
}

impl<'a, N: Default + Clone> Engine<'a, N> {
    pub fn new(t: Rc<SafeGrammarTables>, text: &'a str, end: usize, ws_mode: WsMode, top_scope: ScopeId) -> Self {
        Engine {
            t,
            text,
            input: text.as_bytes(),
            start: 0,
            end,
            loc: Loc { s: 0, ws: 0, line: 1, col: 0 },
            pn: Vec::new(),
            sn: Vec::new(),
            zn: Vec::new(),
            snode_hash: FxHashMap::default(),
            snode_all: Vec::new(),
            snode_last_all: Vec::new(),
            pnode_hash: FxHashMap::default(),
            pnode_all: Vec::new(),
            reductions_todo: VecDeque::new(),
            shifts_todo: VecDeque::new(),
            accept: None,
            error_reductions: Vec::new(),
            serial: 0,
            last_syntax_error_line: 0,
            top_scope,
            ws_mode,
            ws_parser: None,
            partial_parses: false,
            error_recovery: true,
            shift_cache: FxHashMap::default(),
            code_shifts: Vec::new(),
            shift_results: Vec::new(),
            scan_results: Vec::new(),
            committed: FxHashMap::default(),
            stats: Stats::default(),
            free_pn: Vec::new(),
            free_sn: Vec::new(),
            free_zn: Vec::new(),
            allocs_since_gc: 0,
            live_after_gc: 0,
        }
    }

    pub fn set_partial_parses(&mut self, b: bool) {
        self.partial_parses = b;
    }
    pub fn set_error_recovery(&mut self, b: bool) {
        self.error_recovery = b;
    }

    /// Clear the working data, keeping the allocations (for the whitespace parser).
    fn reset(&mut self, start: usize) {
        self.start = start;
        self.loc = Loc { s: start, ws: start, line: 1, col: 0 };
        self.pn.clear();
        self.sn.clear();
        self.zn.clear();
        self.snode_hash.clear();
        self.snode_all.clear();
        self.snode_last_all.clear();
        self.pnode_hash.clear();
        self.pnode_all.clear();
        self.reductions_todo.clear();
        self.shifts_todo.clear();
        self.accept = None;
        self.error_reductions.clear();
        self.committed.clear();
        self.free_pn.clear();
        self.free_sn.clear();
        self.free_zn.clear();
        self.allocs_since_gc = 0;
        self.live_after_gc = 0;
    }

    // ---------------------------------------------------------------- helpers

    fn red(&self, r: RedId) -> &GrammarReduction {
        let n = self.t.reductions.len();
        if (r as usize) < n { &self.t.reductions[r as usize] } else { &self.error_reductions[r as usize - n] }
    }

    fn is_error_reduction(&self, r: RedId) -> bool {
        r as usize >= self.t.reductions.len()
    }

    fn shift_def(&mut self, addr: usize) -> GrammarShift {
        if addr & CODE_SHIFT != 0 {
            return self.code_shifts[addr & !CODE_SHIFT].clone();
        }
        self.shift_cache.entry(addr).or_insert_with(|| read_shift(addr)).clone()
    }

    fn latest(&mut self, p: PId) -> PId {
        loop {
            let l = self.pn[p].latest;
            let ll = self.pn[l].latest;
            if l == ll {
                return l;
            }
            self.pn[p].latest = ll;
        }
    }

    fn slice(&self, s: usize, e: usize) -> &'a str {
        if s <= e { self.text.get(s..e).unwrap_or("") } else { "" }
    }

    fn is_epsilon(&self, p: PId) -> bool {
        self.pn[p].start.s == self.pn[p].end
    }

    fn equiv_scope<G>(&self, p: &Parser<G, N>, s: ScopeId) -> ScopeId {
        p.symtab.equiv_scope(s)
    }

    fn same_scope<G>(&self, p: &Parser<G, N>, a: ScopeId, b: ScopeId) -> bool {
        a == b || p.symtab.equiv_scope(a) == p.symtab.equiv_scope(b)
    }

    fn action_index_of(&self, p: PId) -> i32 {
        match self.pn[p].reduction {
            Some(r) if !self.is_error_reduction(r) => self.red(r).action_index,
            _ => i32::MIN,
        }
    }

    /// A node as seen by actions: its data, without children.
    fn view(&self, id: PId) -> ParseNode<'a, N> {
        let pn = &self.pn[id];
        ParseNode {
            symbol: pn.symbol as i32,
            string: self.slice(pn.start.s, pn.end),
            end_skip_string: self.slice(pn.end, pn.end_skip),
            start_loc: pn.start,
            end: pn.end,
            children: Vec::new(),
            user: pn.user.clone(),
            scope: pn.scope,
            action_index: self.action_index_of(id),
            error_recovery: pn.error_recovery,
            node: u32::MAX,
        }
    }

    // Access to the engine's nodes from speculative actions (see Parser::find_in_tree).
    fn spec_find(engine: *const (), node: u32, symbol: i32) -> Option<u32> {
        let e = unsafe { &*(engine as *const Self) };
        fn rec<N>(e: &Engine<'_, N>, p: PId, symbol: i32) -> Option<PId> {
            if e.pn[p].symbol as i32 == symbol {
                return Some(p);
            }
            e.pn[p].children.iter().find_map(|&c| rec(e, c, symbol))
        }
        rec(e, node as PId, symbol).map(|p| p as u32)
    }

    fn spec_children(engine: *const (), node: u32) -> Vec<u32> {
        let e = unsafe { &*(engine as *const Self) };
        e.pn[node as PId].children.iter().map(|&c| c as u32).collect()
    }

    fn spec_node(engine: *const (), node: u32) -> crate::SpecNode<N> {
        let e = unsafe { &*(engine as *const Self) };
        let pn = &e.pn[node as PId];
        crate::SpecNode {
            symbol: pn.symbol as i32,
            start: pn.start,
            end: pn.end,
            end_skip: pn.end_skip,
            user: pn.user.clone(),
            scope: pn.scope,
            action_index: e.action_index_of(node as PId),
            error_recovery: pn.error_recovery,
        }
    }

    fn spec_greedy(engine: *mut (), x: u32, y: u32) -> i32 {
        let e = unsafe { &mut *(engine as *mut Self) };
        e.cmp_greediness(x as PId, y as PId)
    }

    fn spec_height(engine: *const (), node: u32) -> u32 {
        let e = unsafe { &*(engine as *const Self) };
        e.pn[node as PId].height
    }

    /// Engine access for actions and ambiguity functions; valid only until the
    /// engine is used again.
    fn spec_access(&mut self) -> crate::SpecAccess<N> {
        crate::SpecAccess {
            engine: self as *mut Self as *mut (),
            find: Self::spec_find,
            children: Self::spec_children,
            node: Self::spec_node,
            greedy: Self::spec_greedy,
            height: Self::spec_height,
        }
    }

    /// A view of a node for a speculative action, connected to the engine.
    fn spec_view(&self, id: PId) -> ParseNode<'a, N> {
        let mut v = self.view(id);
        v.node = id as u32;
        v
    }

    // ---------------------------------------------------------------- ZNode sets

    fn zset_find(&self, set: &ZSet, pn: PId) -> Option<ZId> {
        let n = set.v.len();
        if n <= INTEGRAL_VEC_SIZE {
            return set.v.iter().flatten().copied().find(|&z| self.zn[z].pn == pn);
        }
        let h = self.pn[pn].serial as usize % n;
        let mut i = h;
        for _ in 0..SET_MAX_SEQUENTIAL {
            match set.v[i] {
                None => return None,
                Some(z) if self.zn[z].pn == pn => return Some(z),
                _ => {}
            }
            i = (i + 1) % n;
        }
        None
    }

    fn zset_add_hash(&self, set: &mut ZSet, z: ZId) {
        let n = set.v.len();
        if n > 0 {
            let h = self.pn[self.zn[z].pn].serial as usize % n;
            let mut i = h;
            for _ in 0..SET_MAX_SEQUENTIAL {
                if set.v[i].is_none() {
                    set.v[i] = Some(z);
                    return;
                }
                i = (i + 1) % n;
            }
        }
        let old = std::mem::take(&mut set.v);
        set.i = if n == 0 { INITIAL_SET_SIZE_INDEX } else { set.i + 2 };
        set.v = SmallVec::from_elem(None, D_PRIME2[set.i]);
        for zz in old.into_iter().flatten() {
            self.zset_add(set, zz);
        }
        self.zset_add(set, z);
    }

    fn zset_add(&self, set: &mut ZSet, z: ZId) {
        let n = set.v.len();
        if n < INTEGRAL_VEC_SIZE {
            set.v.push(Some(z));
            return;
        }
        if n == INTEGRAL_VEC_SIZE {
            let old = std::mem::take(&mut set.v);
            set.i = 0;
            for zz in old.into_iter().flatten() {
                self.zset_add_hash(set, zz);
            }
        }
        self.zset_add_hash(set, z);
    }

    fn snode_add_znode(&mut self, s: SId, z: ZId) {
        let mut set = std::mem::take(&mut self.sn[s].zns);
        self.zset_add(&mut set, z);
        self.sn[s].zns = set;
    }

    // ---------------------------------------------------------------- nodes

    fn alloc_pnode(&mut self, mut node: PNode<N>) -> PId {
        self.allocs_since_gc += 1;
        match self.free_pn.pop() {
            Some(id) => {
                node.latest = id;
                self.pn[id] = node;
                id
            }
            None => {
                node.latest = self.pn.len();
                self.pn.push(node);
                self.pn.len() - 1
            }
        }
    }

    fn new_znode(&mut self, pn: PId) -> ZId {
        self.allocs_since_gc += 1;
        let z = ZNode { pn, sns: SmallVec::new() };
        match self.free_zn.pop() {
            Some(id) => {
                self.zn[id] = z;
                id
            }
            None => {
                self.zn.push(z);
                self.zn.len() - 1
            }
        }
    }

    fn new_snode(&mut self, state: usize, loc: Loc, sc: ScopeId) -> SId {
        self.allocs_since_gc += 1;
        let node = SNode {
            state,
            initial_scope: sc,
            loc,
            depth: 0,
            in_error_recovery_queue: false,
            last_pn: None,
            zns: ZSet::default(),
        };
        let id = match self.free_sn.pop() {
            Some(id) => {
                self.sn[id] = node;
                id
            }
            None => {
                self.sn.push(node);
                self.sn.len() - 1
            }
        };
        self.stats.states += 1;
        self.snode_hash.insert((state, sc), id);
        self.snode_all.push(id);
        if self.t.states[state].accept {
            match self.accept {
                None => self.accept = Some(id),
                Some(a) if loc.s > self.sn[a].loc.s => self.accept = Some(id),
                _ => {}
            }
        }
        id
    }

    fn znode_depth(&self, z: Option<ZId>) -> u32 {
        match z {
            None => u32::MAX,
            Some(z) => self.zn[z].sns.iter().map(|&s| self.sn[s].depth).max().unwrap_or(0),
        }
    }

    fn add_reduction(&mut self, z: Option<ZId>, s: SId, reduction: RedId) -> Option<usize> {
        let d = self.znode_depth(z);
        let pos = self.sn[s].loc.s;
        let mut i = 0;
        while i < self.reductions_todo.len() {
            let x = &self.reductions_todo[i];
            let xpos = self.sn[x.snode].loc.s;
            if pos < xpos {
                break;
            }
            let dd = self.znode_depth(x.znode);
            if pos == xpos && d >= dd {
                if d == dd
                    && self.reductions_todo.iter().skip(i).any(|y| y.snode == s && y.znode == z && y.reduction == reduction)
                {
                    return None;
                }
                break;
            }
            i += 1;
        }
        self.reductions_todo.insert(i, RedTodo { znode: z, snode: s, reduction, new_snode: None, new_depth: 0 });
        Some(i)
    }

    fn add_shift(&mut self, s: SId) {
        let pos = self.sn[s].loc.s;
        let i = self.shifts_todo.iter().position(|&x| pos <= self.sn[x].loc.s).unwrap_or(self.shifts_todo.len());
        self.shifts_todo.insert(i, s);
    }

    fn add_snode(&mut self, state: usize, loc: Loc, sc: ScopeId) -> SId {
        if let Some(&s) = self.snode_hash.get(&(state, sc)) {
            return s;
        }
        let s = self.new_snode(state, loc, sc);
        if self.t.states[state].has_shifts {
            self.add_shift(s);
        }
        let t = self.t.clone();
        for &r in &t.states[state].reductions {
            if t.reductions[r as usize].nelements == 0 {
                self.add_reduction(None, s, r);
            }
        }
        s
    }

    // ---------------------------------------------------------------- actions

    fn speculative<G>(&mut self, p: &mut Parser<G, N>, pn: PId, action_index: i32) -> i32 {
        if !p.has_action(ActionKind::Speculative, action_index) {
            return 0;
        }
        let mut ps = self.spec_view(pn);
        ps.children = self.pn[pn].children.iter().map(|&c| self.spec_view(c)).collect();
        // the engine is not used while the action runs
        p.spec = Some(self.spec_access());
        let r = p.call_action(ActionKind::Speculative, action_index, &mut ps);
        p.spec = None;
        let node = &mut self.pn[pn];
        node.user = ps.user;
        node.scope = ps.scope;
        r
    }

    fn reduce_actions<G>(&mut self, p: &mut Parser<G, N>, pn: PId, r: RedId) -> i32 {
        let mut height = 0;
        for i in 0..self.pn[pn].children.len() {
            let c = self.pn[pn].children[i];
            let (op_assoc, op_priority, h) = (self.pn[c].op_assoc, self.pn[c].op_priority, self.pn[c].height);
            if op_assoc != 0 {
                self.pn[pn].assoc = op_assoc;
                self.pn[pn].priority = op_priority;
            }
            if h >= height {
                height = h + 1;
            }
        }
        let red = self.red(r).clone();
        let node = &mut self.pn[pn];
        node.op_assoc = red.op_assoc as u32;
        node.op_priority = red.op_priority;
        node.height = height;
        if red.rule_assoc != 0 {
            node.assoc = red.rule_assoc as u32;
            node.priority = red.rule_priority;
        }
        if !self.is_error_reduction(r) {
            return self.speculative(p, pn, red.action_index);
        }
        0
    }

    #[allow(clippy::too_many_arguments)]
    fn make_pnode<G>(
        &mut self,
        p: &mut Parser<G, N>,
        symbol: u32,
        start_loc: Loc,
        e: usize,
        prev: PId,
        r: Option<RedId>,
        path: Option<&[ZId]>,
        sh: Option<usize>,
        scope: ScopeId,
    ) -> Option<PId> {
        let serial = self.serial;
        self.serial += 1;
        let end = if r.is_none() || path.is_none() { e } else { self.pn[prev].end };
        let id = self.alloc_pnode(PNode {
            symbol,
            start: start_loc,
            end,
            end_skip: e,
            scope: self.pn[prev].scope,
            initial_scope: scope,
            assoc: 0,
            priority: 0,
            op_assoc: 0,
            op_priority: 0,
            height: 0,
            serial,
            children: SmallVec::new(),
            ambiguities: None,
            latest: 0,
            reduction: r,
            shift: sh,
            evaluated: false,
            error_recovery: false,
            user: N::default(),
        });
        if let Some(addr) = sh {
            let def = self.shift_def(addr);
            self.pn[id].op_assoc = def.op_assoc as u32;
            self.pn[id].op_priority = def.op_priority;
            if def.has_speculative_code && def.action_index != -1 && self.speculative(p, id, def.action_index) != 0 {
                return None;
            }
        } else if let Some(r) = r {
            if let Some(path) = path {
                for &z in path.iter().rev() {
                    let c = self.zn[z].pn;
                    let c = self.latest(c);
                    self.pn[id].children.push(c);
                }
            }
            if self.reduce_actions(p, id, r) != 0 {
                return None;
            }
            if let Some(path) = path {
                let n = path.len();
                if n > 1 {
                    let mut i = 0;
                    while i < n {
                        let child = self.pn[id].children[i];
                        let (c, pn) = (&self.pn[child], &self.pn[id]);
                        if c.assoc != 0
                            && pn.assoc != 0
                            && !check_child(pn.priority, pn.assoc, c.priority, c.assoc, i == 0, i == n - 1)
                        {
                            return None;
                        }
                        i += n - 1;
                    }
                }
            }
        }
        Some(id)
    }

    fn pnode_equal(&mut self, pn: PId, r: Option<RedId>, path: Option<&[ZId]>, sh: Option<usize>) -> bool {
        if sh.is_some() {
            return sh == self.pn[pn].shift;
        }
        if r != self.pn[pn].reduction {
            return false;
        }
        let n = self.pn[pn].children.len();
        let path = match path {
            None => return n == 0,
            Some(p) => p,
        };
        if n != path.len() {
            return false;
        }
        for i in 0..n {
            let x = self.pn[pn].children[i];
            let x = self.latest(x);
            let y = self.zn[path[n - i - 1]].pn;
            let y = self.latest(y);
            if x != y {
                return false;
            }
        }
        true
    }

    fn find_pnode<G>(
        &mut self,
        p: &Parser<G, N>,
        key: (usize, usize, u32, ScopeId),
        result_scope: Option<ScopeId>,
    ) -> Option<PId> {
        let n = self.pnode_hash.get(&key)?.len();
        for i in (0..n).rev() {
            let c = self.pnode_hash[&key].get(i);
            let t = self.latest(c);
            match result_scope {
                None => return Some(t),
                Some(rs) if self.same_scope(p, self.pn[t].scope, rs) => return Some(t),
                _ => {}
            }
        }
        None
    }

    fn find_equal_pnode(
        &mut self,
        key: (usize, usize, u32, ScopeId),
        r: Option<RedId>,
        path: Option<&[ZId]>,
        sh: Option<usize>,
    ) -> Option<PId> {
        let n = self.pnode_hash.get(&key)?.len();
        for i in (0..n).rev() {
            let c = self.pnode_hash[&key].get(i);
            let t = self.latest(c);
            if self.pnode_equal(t, r, path, sh) {
                return Some(t);
            }
            let mut amb = self.pn[t].ambiguities;
            while let Some(a) = amb {
                if self.pnode_equal(a, r, path, sh) {
                    return Some(t);
                }
                amb = self.pn[a].ambiguities;
            }
        }
        None
    }

    fn insert_pnode(&mut self, pn: PId) {
        let n = &self.pn[pn];
        let key = (n.start.s, n.end_skip, n.symbol, n.initial_scope);
        self.pnode_hash.entry(key).and_modify(|b| b.push(pn)).or_insert(Bucket::One(pn));
        self.pnode_all.push(pn);
    }

    #[allow(clippy::too_many_arguments)]
    fn add_pnode<G>(
        &mut self,
        p: &mut Parser<G, N>,
        symbol: u32,
        start_loc: Loc,
        e: usize,
        prev: PId,
        r: Option<RedId>,
        path: Option<&[ZId]>,
        sh: Option<usize>,
    ) -> Option<PId> {
        let scope = self.equiv_scope(p, self.pn[prev].scope);
        let key = (start_loc.s, e, symbol, scope);
        let old_pn = self.find_pnode(p, key, None);
        if old_pn.is_some() {
            if let Some(same) = self.find_equal_pnode(key, r, path, sh) {
                return Some(same);
            }
        }
        let new_pn = self.make_pnode(p, symbol, start_loc, e, prev, r, path, sh, scope);
        let mut old_pn = match old_pn {
            None => {
                let n = new_pn?;
                self.insert_pnode(n);
                return Some(n);
            }
            Some(o) => o,
        };
        let new_pn = match new_pn {
            None => return Some(old_pn),
            Some(n) => n,
        };
        // prefer to compare against the derivation leaving the symbol table in the same state
        let new_scope = self.pn[new_pn].scope;
        let matched = self.find_pnode(p, key, Some(new_scope));
        if let Some(m) = matched {
            old_pn = m;
        }
        self.stats.compares += 1;
        match self.cmp_pnodes(p, new_pn, old_pn) {
            0 => {
                if matched.is_none() {
                    // Ambiguous, but the symbol table differs: keep a separate node so
                    // this path continues with its own scope.
                    self.insert_pnode(new_pn);
                    return Some(new_pn);
                }
                self.pn[new_pn].ambiguities = self.pn[old_pn].ambiguities;
                self.pn[old_pn].ambiguities = Some(new_pn);
            }
            -1 => {
                self.insert_pnode(new_pn);
                let o = self.latest(old_pn);
                self.pn[o].latest = new_pn;
                old_pn = new_pn;
            }
            _ => {}
        }
        Some(old_pn)
    }

    fn goto_pnode(&mut self, loc: Loc, pn: PId, ps: SId) -> Option<SId> {
        let state = self.sn[ps].state;
        let symbol = self.pn[pn].symbol as usize;
        if !self.t.goto_valid(state, symbol) {
            return None;
        }
        let state_index = self.t.goto_state(state, symbol);
        let new_ps = self.add_snode(state_index, loc, self.pn[pn].scope);
        self.sn[new_ps].last_pn = Some(pn);
        if ps != new_ps && self.sn[new_ps].depth < self.sn[ps].depth + 1 {
            self.sn[new_ps].depth = self.sn[ps].depth + 1;
        }
        let z = match self.zset_find(&self.sn[new_ps].zns, pn) {
            Some(z) => z,
            None => {
                let z = self.new_znode(pn);
                self.snode_add_znode(new_ps, z);
                let t = self.t.clone();
                let st = &t.states[self.sn[new_ps].state];
                for &r in &st.reductions {
                    if t.reductions[r as usize].nelements != 0 {
                        self.add_reduction(Some(z), new_ps, r);
                    }
                }
                if self.pn[pn].shift.is_none() {
                    for h in &st.right_epsilon_hints {
                        let key = (h.preceeding_state as usize, self.sn[new_ps].initial_scope);
                        let Some(&pre_ps) = self.snode_hash.get(&key) else { continue };
                        let zs: Vec<ZId> = self.sn[pre_ps].zns.v.iter().flatten().copied().collect();
                        for zz in zs {
                            if let Some(i) = self.add_reduction(Some(zz), pre_ps, h.reduction) {
                                self.reductions_todo[i].new_snode = Some(new_ps);
                                self.reductions_todo[i].new_depth = h.depth as usize;
                            }
                        }
                    }
                }
                z
            }
        };
        if !self.zn[z].sns.contains(&ps) {
            self.zn[z].sns.push(ps);
        }
        Some(new_ps)
    }

    // ---------------------------------------------------------------- whitespace

    fn white_space<G>(&mut self, p: &mut Parser<G, N>, loc: &mut Loc) {
        match self.ws_mode {
            WsMode::Null => {}
            WsMode::Builtin => crate::whitespace::white_space(self.input, self.end, loc),
            WsMode::User => {
                if let Some(f) = p.white_space_fn {
                    let g = p.globals_mut();
                    f(&self.input[..self.end], loc, g);
                }
            }
            WsMode::Subparser => self.parse_whitespace(p, loc),
        }
    }

    fn parse_whitespace<G>(&mut self, p: &mut Parser<G, N>, loc: &mut Loc) {
        let t = self.t.clone();
        let (text, end, top) = (self.text, self.end, self.top_scope);
        let ws = self.ws_parser.get_or_insert_with(|| {
            let mut e = Engine::new(t.clone(), text, end, WsMode::Null, top);
            e.partial_parses = true;
            e.error_recovery = false;
            Box::new(e)
        });
        ws.reset(loc.s);
        ws.top_scope = top;
        if ws.exhaustive_parse(p, t.whitespace_state as usize) == 0 {
            if let Some(a) = ws.accept {
                let al = ws.sn[a].loc;
                let (old_col, old_line) = (loc.col, loc.line);
                *loc = al;
                if loc.line == 1 {
                    loc.col = old_col + loc.col;
                }
                loc.line = old_line + (al.line - 1);
            }
        }
    }

    // ---------------------------------------------------------------- shifting

    fn shift_all<G>(&mut self, p: &mut Parser<G, N>, pos: usize) {
        let loc = self.sn[self.shifts_todo[0]].loc;
        // (loc, shift, snode)
        let mut results = std::mem::take(&mut self.shift_results);
        let mut scanned = std::mem::take(&mut self.scan_results);
        results.clear();
        while let Some(&s) = self.shifts_todo.front() {
            if self.sn[s].loc.s != pos {
                break;
            }
            self.shifts_todo.pop_front();
            self.stats.scans += 1;
            let state = self.sn[s].state;
            let st = &self.t.states[state];
            if st.has_scanner_code {
                if let Some(scan) = p.scan_fn() {
                    let mut l = loc;
                    let mut def = GrammarShift {
                        symbol: 0,
                        shift_kind: D_SCAN_ALL,
                        op_assoc: 0,
                        op_priority: 0,
                        term_priority: 0,
                        action_index: 0,
                        has_speculative_code: false,
                    };
                    let input = &self.input[..self.end];
                    let (mut oa, mut op) = (0u8, 0i32);
                    if scan(state, input, &mut l, &mut def.symbol, &mut def.term_priority, &mut oa, &mut op) != 0 {
                        def.op_assoc = oa;
                        def.op_priority = op;
                        self.code_shifts.push(def);
                        results.push((l, Some(CODE_SHIFT | (self.code_shifts.len() - 1)), s));
                    }
                }
            }
            let st = &self.t.states[state];
            if st.scanner_table != 0 {
                scanned.clear();
                scan_buffer_into(self.input, self.end, loc, st, &mut scanned);
                results.extend(scanned.iter().map(|r| (r.loc, Some(r.shift), s)));
            }
        }
        let n = results.len();
        for i in 0..n {
            let Some(shift) = results[i].1 else { continue };
            let def = self.shift_def(shift);
            if def.shift_kind == D_SCAN_TRAILING {
                let (symbol, sn) = (def.symbol, results[i].2);
                results[i].1 = None;
                for j in i + 1..n {
                    if let Some(sj) = results[j].1 {
                        if sn == results[j].2 && symbol == self.shift_def(sj).symbol {
                            results[i].1 = Some(sj);
                            results[j].1 = None;
                        }
                    }
                }
            }
            if let Some(si) = results[i].1 {
                let tp = self.shift_def(si).term_priority;
                if tp != 0 {
                    for j in 0..n {
                        let Some(sj) = results[j].1 else { continue };
                        if results[i].0.s == results[j].0.s && j != i {
                            let tpj = self.shift_def(sj).term_priority;
                            if tp < tpj {
                                results[i].1 = None;
                                break;
                            }
                            if tp > tpj {
                                results[j].1 = None;
                            }
                        }
                    }
                }
            }
        }
        let mut skip_loc: Option<Loc> = None;
        for &(rloc, shift, s) in &results {
            let Some(shift) = shift else { continue };
            self.stats.shifts += 1;
            let symbol = self.shift_def(shift).symbol as u32;
            let (sloc, last_pn) = (self.sn[s].loc, self.sn[s].last_pn.expect("snode without last_pn"));
            if let Some(new_pn) = self.add_pnode(p, symbol, sloc, rloc.s, last_pn, None, None, Some(shift)) {
                if skip_loc.is_none_or(|sl| sl.s != rloc.s) {
                    let mut sl = rloc;
                    self.white_space(p, &mut sl);
                    sl.ws = rloc.s;
                    skip_loc = Some(sl);
                }
                self.goto_pnode(skip_loc.unwrap(), new_pn, s);
            }
        }
        self.shift_results = results;
        self.scan_results = scanned;
    }

    // ---------------------------------------------------------------- reducing

    fn build_paths(&self, z: ZId, n: usize) -> Vec<Path> {
        let mut paths: Vec<Path> = Vec::new();
        if n == 0 {
            return paths;
        }
        paths.push(Path::new());
        self.build_paths_internal(z, &mut paths, 0, n, n);
        paths
    }

    fn build_paths_internal(&self, z: ZId, paths: &mut Vec<Path>, mut parent: usize, n: usize, n_to_go: usize) {
        paths[parent].push(z);
        if n_to_go <= 1 {
            return;
        }
        for k in 0..self.zn[z].sns.len() {
            let s = self.zn[z].sns[k];
            let mut l = 0;
            for j in 0..self.sn[s].zns.v.len() {
                if let Some(zz) = self.sn[s].zns.v[j] {
                    if k + l > 0 {
                        let prefix = Path::from_slice(&paths[parent][..n - (n_to_go - 1)]);
                        paths.push(prefix);
                        parent = paths.len() - 1;
                    }
                    self.build_paths_internal(zz, paths, parent, n, n_to_go - 1);
                    l += 1;
                }
            }
        }
    }

    fn reduce_one<G>(&mut self, p: &mut Parser<G, N>, r: RedTodo) {
        let sn = r.snode;
        let red = self.red(r.reduction).clone();
        let symbol = red.symbol as u32;
        match r.znode {
            None => {
                // epsilon reduction
                let (loc, last_pn) = (self.sn[sn].loc, self.sn[sn].last_pn.expect("snode without last_pn"));
                if let Some(pn) = self.add_pnode(p, symbol, loc, loc.s, last_pn, Some(r.reduction), None, None) {
                    self.goto_pnode(loc, pn, sn);
                }
            }
            Some(z) => {
                let n = red.nelements as usize;
                let paths = self.build_paths(z, n);
                for path in paths {
                    if let Some(new_snode) = r.new_snode {
                        // prune paths by the new right epsilon node
                        if !self.zn[path[r.new_depth]].sns.contains(&new_snode) {
                            continue;
                        }
                    }
                    if self.check_path_priorities(&path) {
                        continue;
                    }
                    self.stats.reductions += 1;
                    let last_pn = self.zn[path[0]].pn;
                    let first_z = path[n - 1];
                    let start = self.pn[self.zn[first_z].pn].start;
                    let loc = self.sn[sn].loc;
                    if let Some(pn) = self.add_pnode(p, symbol, start, loc.s, last_pn, Some(r.reduction), Some(&path), None)
                    {
                        let mut j = 0;
                        while j < self.zn[first_z].sns.len() {
                            let s = self.zn[first_z].sns[j];
                            self.goto_pnode(loc, pn, s);
                            j += 1;
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- priorities

    fn check_assoc_priority(&self, pn0: PId, pn1: PId, pn2: Option<PId>) -> i32 {
        let (p0, p1) = (&self.pn[pn0], &self.pn[pn1]);
        if !is_unary_binary_assoc(p0.op_assoc) {
            if is_unary_binary_assoc(p1.op_assoc) {
                // second token is operator: check expression pn0 (child of pn1)
                if p0.assoc != 0 && !check_child(p1.op_priority, p1.op_assoc, p0.priority, p0.assoc, false, true) {
                    return -1;
                }
            }
        } else {
            // pn0 is an operator
            if p1.op_assoc != 0 {
                if !check_child(p1.op_priority, p1.op_assoc, p0.op_priority, p0.op_assoc, false, true) {
                    return -1;
                }
            } else if let Some(pn2) = pn2 {
                let p2 = &self.pn[pn2];
                if p2.op_assoc != 0 && !check_child(p2.op_priority, p2.op_assoc, p0.op_priority, p0.op_assoc, false, true)
                {
                    return -1;
                }
            }
            // check expression pn1 (child of pn0)
            if p1.assoc != 0 && !check_child(p0.op_priority, p0.op_assoc, p1.priority, p1.assoc, true, false) {
                return -1;
            }
        }
        0
    }

    fn check_path_priorities(&self, path: &[ZId]) -> bool {
        path.len() > 1
            && (self.pn[self.zn[path[0]].pn].op_assoc != 0 || self.pn[self.zn[path[1]].pn].op_assoc != 0)
            && self.check_path_priorities_internal(path) != 0
    }

    fn check_path_priorities_internal(&self, path: &[ZId]) -> i32 {
        let zpn = |z: ZId| self.zn[z].pn;
        let mut i = 0;
        if path.len() < i + 1 {
            return 0;
        }
        let mut pn0 = zpn(path[i]);
        if self.pn[pn0].op_assoc == 0 {
            // deal with top expression directly
            i = 1;
            if path.len() < i + 1 {
                return 0;
            }
            let pn1 = zpn(path[i]);
            let (p0, p1) = (&self.pn[pn0], &self.pn[pn1]);
            if p1.op_assoc == 0 {
                return 0;
            }
            if p0.assoc != 0 && !check_child(p1.op_priority, p1.op_assoc, p0.priority, p0.assoc, false, true) {
                return -1;
            }
            pn0 = pn1;
        }
        if path.len() > i + 1 {
            // entirely in the path
            let pn1 = zpn(path[i + 1]);
            if path.len() > i + 2 {
                return self.check_assoc_priority(pn0, pn1, Some(zpn(path[i + 2])));
            }
            // one level from the stack beyond the path
            let z = path[i + 1];
            let mut one = false;
            for &s in &self.zn[z].sns {
                for zz in self.sn[s].zns.v.iter().flatten() {
                    one = true;
                    if self.check_assoc_priority(pn0, pn1, Some(zpn(*zz))) == 0 {
                        return 0;
                    }
                }
            }
            if !one {
                return self.check_assoc_priority(pn0, pn1, None);
            }
        } else {
            // two levels from the stack beyond the path
            let z = path[i];
            for &s in &self.zn[z].sns {
                for &zz in self.sn[s].zns.v.iter().flatten() {
                    for &ss in &self.zn[zz].sns {
                        for &zzz in self.sn[ss].zns.v.iter().flatten() {
                            if self.check_assoc_priority(pn0, zpn(zz), Some(zpn(zzz))) == 0 {
                                return 0;
                            }
                        }
                    }
                }
            }
            return 0;
        }
        -1
    }

    fn heapify(&self, a: &mut [PId], i: usize) {
        let mut i = i;
        loop {
            let (l, r) = (2 * i + 1, 2 * i + 2);
            let mut largest = i;
            if l < a.len() && self.pn[a[l]].height > self.pn[a[largest]].height {
                largest = l;
            }
            if r < a.len() && self.pn[a[r]].height > self.pn[a[largest]].height {
                largest = r;
            }
            if largest == i {
                return;
            }
            a.swap(i, largest);
            i = largest;
        }
    }

    fn heap_insert(&self, a: &mut Vec<PId>, pn: PId) {
        a.push(pn);
        for i in (0..a.len() / 2).rev() {
            self.heapify(a, i);
        }
    }

    fn heap_pop(&self, a: &mut Vec<PId>) -> Option<PId> {
        if a.is_empty() {
            return None;
        }
        let pn = a.swap_remove(0);
        for i in (0..a.len() / 2).rev() {
            self.heapify(a, i);
        }
        Some(pn)
    }

    fn get_children(&mut self, pn: PId, ps: &mut HashSet<PId>, ps2: &HashSet<PId>, ph: &mut Vec<PId>) {
        if !ps2.contains(&pn) {
            for i in 0..self.pn[pn].children.len() {
                let c = self.pn[pn].children[i];
                let c = self.latest(c);
                if ps.insert(c) && !ps2.contains(&c) {
                    self.heap_insert(ph, c);
                }
            }
        }
    }

    fn get_unshared_pnodes(&mut self, x: PId, y: PId) -> (Vec<PId>, Vec<PId>) {
        let (mut hx, mut hy) = (Vec::new(), Vec::new());
        let (mut sx, mut sy) = (HashSet::new(), HashSet::new());
        let mut x = Some(self.latest(x));
        let mut y = Some(self.latest(y));
        sx.insert(x.unwrap());
        sy.insert(y.unwrap());
        loop {
            match (x, y) {
                (None, None) => break,
                (Some(xx), _) if y.is_none() || self.pn[xx].height > self.pn[y.unwrap()].height => {
                    self.get_children(xx, &mut sx, &sy, &mut hx);
                    x = self.heap_pop(&mut hx);
                }
                (_, Some(yy)) => {
                    self.get_children(yy, &mut sy, &sx, &mut hy);
                    y = self.heap_pop(&mut hy);
                }
                _ => unreachable!(),
            }
        }
        let pvx = sx.iter().filter(|p| !sy.contains(p)).copied().collect();
        let pvy = sy.iter().filter(|p| !sx.contains(p)).copied().collect();
        (pvx, pvy)
    }

    fn greedycmp(&self, x: PId, y: PId) -> std::cmp::Ordering {
        let (x, y) = (&self.pn[x], &self.pn[y]);
        x.start
            .s
            .cmp(&y.start.s)
            .then(x.symbol.cmp(&y.symbol))
            .then(x.end.cmp(&y.end))
            .then(x.serial.cmp(&y.serial))
    }

    fn cmp_greediness(&mut self, x: PId, y: PId) -> i32 {
        let (mut pvx, mut pvy) = self.get_unshared_pnodes(x, y);
        pvx.sort_by(|&a, &b| self.greedycmp(a, b));
        pvy.sort_by(|&a, &b| self.greedycmp(a, b));
        let (mut ix, mut iy) = (0, 0);
        loop {
            if pvx.len() <= ix || pvy.len() <= iy {
                return 0;
            }
            let (xi, yi) = (pvx[ix], pvy[iy]);
            let (x, y) = (&self.pn[xi], &self.pn[yi]);
            if xi == yi {
                ix += 1;
                iy += 1;
            } else if x.start.s < y.start.s {
                ix += 1;
            } else if x.start.s > y.start.s {
                iy += 1;
            } else if x.symbol < y.symbol {
                ix += 1;
            } else if x.symbol > y.symbol {
                iy += 1;
            } else if x.end > y.end {
                return -1;
            } else if x.end < y.end {
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

    fn prioritycmp(&self, x: PId, y: PId) -> std::cmp::Ordering {
        let (x, y) = (&self.pn[x], &self.pn[y]);
        (y.assoc != 0)
            .cmp(&(x.assoc != 0))
            .then(x.height.cmp(&y.height))
            .then(y.priority.cmp(&x.priority))
            .then(x.start.s.cmp(&y.start.s))
            .then(y.end.cmp(&x.end))
            .then(x.serial.cmp(&y.serial))
    }

    fn cmp_priorities(&mut self, x: PId, y: PId) -> i32 {
        let (mut vx, mut vy) = self.get_unshared_pnodes(x, y);
        vx.sort_by(|&a, &b| self.prioritycmp(a, b));
        vy.sort_by(|&a, &b| self.prioritycmp(a, b));
        for (a, b) in vx.iter().zip(vy.iter()) {
            let (pa, pb) = (self.pn[*a].priority, self.pn[*b].priority);
            if pa > pb {
                return -1;
            }
            if pa < pb {
                return 1;
            }
        }
        0
    }

    /// -1 to prefer x, 1 to prefer y, 0 if they are ambiguous.
    fn cmp_pnodes<G>(&mut self, p: &Parser<G, N>, x: PId, y: PId) -> i32 {
        if !p.dont_use_deep_priorities_for_disambiguation && self.pn[x].assoc != 0 && self.pn[y].assoc != 0 {
            let r = self.cmp_priorities(x, y);
            if r != 0 {
                return r;
            }
        }
        if !p.dont_use_greediness_for_disambiguation {
            let r = self.cmp_greediness(x, y);
            if r != 0 {
                return r;
            }
        }
        if !p.dont_use_height_for_disambiguation {
            if self.pn[x].height < self.pn[y].height {
                return -1;
            }
            if self.pn[x].height > self.pn[y].height {
                return 1;
            }
        }
        0
    }

    // ---------------------------------------------------------------- stacks

    fn binary_op_znode(&self, s: SId) -> Option<ZId> {
        let zns = &self.sn[s].zns.v;
        if zns.len() != 1 {
            return None;
        }
        let mut z = zns[0]?;
        if self.pn[self.zn[z].pn].op_assoc == ASSOC_UNARY_RIGHT {
            if self.zn[z].sns.len() != 1 {
                return None;
            }
            let s2 = self.zn[z].sns[0];
            if self.sn[s2].zns.v.len() != 1 {
                return None;
            }
            z = self.sn[s2].zns.v[0]?;
        }
        if !is_binary_assoc(self.pn[self.zn[z].pn].op_assoc) {
            return None;
        }
        Some(z)
    }

    /// Compare stacks with operators on top of identical substacks, removing
    /// the one with the lower priority binary operator.
    fn cmp_stacks(&mut self) {
        let pos = self.sn[self.shifts_todo[0]].loc.s;
        let at_pos = |e: &Self, i: usize| i < e.shifts_todo.len() && e.sn[e.shifts_todo[i]].loc.s == pos;
        let mut ai = 0;
        'outer: while at_pos(self, ai) {
            let a = self.shifts_todo[ai];
            if let Some(az) = self.binary_op_znode(a) {
                let mut bi = ai + 1;
                while at_pos(self, bi) {
                    let b = self.shifts_todo[bi];
                    if let Some(bz) = self.binary_op_znode(b) {
                        let (asn, bsn) = (&self.zn[az].sns, &self.zn[bz].sns);
                        let same = asn.len() == bsn.len() && asn.iter().all(|s| bsn.contains(s));
                        let (sa, sb) = (self.sn[a].state, self.sn[b].state);
                        let related = self.t.states[sa].reduces_to == sb as i32 || self.t.states[sb].reduces_to == sa as i32;
                        if same && related {
                            let (pa, pb) = (self.pn[self.zn[az].pn].op_priority, self.pn[self.zn[bz].pn].op_priority);
                            if pa > pb {
                                self.shifts_todo.remove(bi);
                                break;
                            }
                            if pa < pb {
                                self.shifts_todo.remove(ai);
                                // parse.c continues with the stack after the next one
                                ai += 1;
                                continue 'outer;
                            }
                        }
                    }
                    bi += 1;
                }
            }
            ai += 1;
        }
    }

    /// Free the nodes no parse path can reach (parse.c frees them by reference
    /// counting).  Only called between reductions and shifts, when the parse
    /// state is entirely in the work lists and the current node tables.
    fn maybe_gc(&mut self) {
        if self.allocs_since_gc < GC_MIN_ALLOCS.max(self.live_after_gc) {
            return;
        }
        self.allocs_since_gc = 0;
        let mut mp = vec![false; self.pn.len()];
        let mut ms = vec![false; self.sn.len()];
        let mut mz = vec![false; self.zn.len()];
        let (mut ps, mut ss, mut zs): (Vec<PId>, Vec<SId>, Vec<ZId>) = (Vec::new(), Vec::new(), Vec::new());
        ss.extend(self.shifts_todo.iter());
        ss.extend(self.snode_all.iter());
        ss.extend(self.snode_last_all.iter());
        ss.extend(self.accept);
        for r in &self.reductions_todo {
            ss.push(r.snode);
            ss.extend(r.new_snode);
            zs.extend(r.znode);
        }
        ps.extend(self.pnode_all.iter());
        loop {
            if let Some(s) = ss.pop() {
                if !std::mem::replace(&mut ms[s], true) {
                    ps.extend(self.sn[s].last_pn);
                    zs.extend(self.sn[s].zns.v.iter().flatten());
                }
            } else if let Some(z) = zs.pop() {
                if !std::mem::replace(&mut mz[z], true) {
                    ps.push(self.zn[z].pn);
                    ss.extend(self.zn[z].sns.iter());
                }
            } else if let Some(p) = ps.pop() {
                if !std::mem::replace(&mut mp[p], true) {
                    let n = &self.pn[p];
                    ps.extend(n.children.iter());
                    ps.extend(n.ambiguities);
                    ps.push(n.latest);
                }
            } else {
                break;
            }
        }
        self.free_pn.clear();
        for (i, &m) in mp.iter().enumerate() {
            if !m {
                let n = &mut self.pn[i];
                n.children = SmallVec::new();
                n.user = N::default();
                self.free_pn.push(i);
            }
        }
        self.free_sn.clear();
        for (i, &m) in ms.iter().enumerate() {
            if !m {
                self.sn[i].zns = ZSet::default();
                self.free_sn.push(i);
            }
        }
        self.free_zn.clear();
        for (i, &m) in mz.iter().enumerate() {
            if !m {
                self.zn[i].sns = SmallVec::new();
                self.free_zn.push(i);
            }
        }
        self.committed.retain(|&p, _| mp[p]);
        self.live_after_gc = (mp.len() - self.free_pn.len()) + (ms.len() - self.free_sn.len()) + (mz.len() - self.free_zn.len());
    }

    fn free_old_nodes(&mut self) {
        let mut all = std::mem::take(&mut self.pnode_all);
        for &pn in &all {
            for i in 0..self.pn[pn].children.len() {
                let mut c = self.pn[pn].children[i];
                while c != self.pn[c].latest {
                    c = self.pn[c].latest;
                }
                self.pn[pn].children[i] = c;
            }
        }
        all.clear();
        self.pnode_all = all;
        self.pnode_hash.clear();
        self.snode_hash.clear();
        std::mem::swap(&mut self.snode_last_all, &mut self.snode_all);
        self.snode_all.clear();
    }

    // ---------------------------------------------------------------- errors

    fn report_syntax_error<G>(&self, p: &Parser<G, N>) {
        // the farthest non-empty location reached
        let mut z: Option<ZId> = None;
        let empty = |e: &Self, z: ZId| e.pn[e.zn[z].pn].start.s == e.pn[e.zn[z].pn].end;
        for &s in self.snode_last_all.iter().rev() {
            for &zz in self.sn[s].zns.v.iter().flatten() {
                match z {
                    None => z = Some(zz),
                    Some(cur) if empty(self, cur) && !empty(self, zz) => z = Some(zz),
                    Some(cur) if self.pn[self.zn[cur].pn].start.s < self.pn[self.zn[zz].pn].start.s => z = Some(zz),
                    _ => {}
                }
            }
        }
        let after = z.and_then(|z| {
            let pn = &self.pn[self.zn[z].pn];
            (pn.start.s != pn.end).then(|| String::from_utf8_lossy(&self.input[pn.start.s..pn.end]).into_owned())
        });
        match after {
            Some(a) => eprintln!("{}:{}: syntax error after '{}'", p.pathname, self.loc.line, a),
            None => eprintln!("{}:{}: syntax error", p.pathname, self.loc.line),
        }
    }

    /// Returns true if the parse cannot continue.
    fn error_recovery<G>(&mut self, p: &mut Parser<G, N>) -> bool {
        let Some(&head) = self.snode_last_all.last() else { return true };
        self.loc = self.sn[head].loc;
        if !self.error_recovery {
            return true;
        }
        if self.loc.line > self.last_syntax_error_line {
            self.last_syntax_error_line = self.loc.line;
            p.syntax_errors += 1;
            p.loc = self.loc;
            match p.syntax_error_fn {
                Some(f) => f(p),
                None => self.report_syntax_error(p),
            }
        }
        let mut q: Vec<SId> = Vec::new();
        for &s in self.snode_last_all.iter().rev() {
            if self.sn[s].in_error_recovery_queue {
                continue;
            }
            self.sn[s].in_error_recovery_queue = true;
            if q.len() < ERROR_RECOVERY_QUEUE_SIZE - 1 {
                q.push(s);
            }
        }
        let s0 = self.sn[head].loc.s;
        let (mut best_sn, mut best_s, mut best_er): (Option<SId>, usize, Option<(u16, u16)>) = (None, 0, None);
        let t = self.t.clone();
        let mut head_i = 0;
        while head_i < q.len() {
            let s = q[head_i];
            head_i += 1;
            for er in &t.states[self.sn[s].state].error_recovery_hints {
                if let Some(ss) = find_substr(&self.input[..self.end], s0, &er.string) {
                    let better = match best_sn {
                        None => true,
                        Some(b) => {
                            ss < best_s
                                || (ss == best_s
                                    && (self.sn[b].depth < self.sn[s].depth
                                        || (self.sn[b].depth == self.sn[s].depth && best_er.unwrap().0 < er.depth)))
                        }
                    };
                    if better {
                        best_sn = Some(s);
                        best_s = ss;
                        best_er = Some((er.depth, er.symbol));
                    }
                }
            }
            for z in self.sn[s].zns.v.clone().into_iter().flatten() {
                for &x in &self.zn[z].sns {
                    if self.sn[x].in_error_recovery_queue {
                        continue;
                    }
                    self.sn[x].in_error_recovery_queue = true;
                    if q.len() < ERROR_RECOVERY_QUEUE_SIZE - 1 {
                        q.push(x);
                    }
                }
            }
        }
        for &s in &q {
            self.sn[s].in_error_recovery_queue = false;
        }
        let Some(best_sn) = best_sn else { return true };
        let (depth, symbol) = best_er.unwrap();
        self.error_reductions.push(GrammarReduction {
            nelements: depth + 1,
            symbol,
            action_index: i32::MIN,
            op_assoc: 0,
            rule_assoc: 0,
            op_priority: 0,
            rule_priority: 0,
        });
        let rr = (self.t.reductions.len() + self.error_reductions.len() - 1) as RedId;
        let mut best_loc = self.loc;
        best_loc.line += self.input[best_loc.s.min(best_s)..best_s].iter().filter(|&&c| c == b'\n').count() as u32;
        best_loc.s = best_s;
        let mut best_pn: Option<PId> = None;
        for &zn in self.sn[best_sn].zns.v.iter().flatten() {
            let pn = self.zn[zn].pn;
            if best_pn.is_none_or(|b| self.pn[b].start.s < self.pn[pn].start.s) {
                best_pn = Some(pn);
            }
        }
        self.white_space(p, &mut best_loc);
        let loc = self.loc;
        let new_pn = self
            .add_pnode(p, 0, loc, best_loc.s, best_pn.expect("error recovery state without nodes"), None, None, None)
            .expect("error recovery node");
        let new_sn = self.new_snode(self.sn[best_sn].state, best_loc, self.pn[new_pn].initial_scope);
        self.sn[new_sn].last_pn = Some(new_pn);
        let z = self.new_znode(new_pn);
        self.snode_add_znode(new_sn, z);
        self.zn[z].sns.push(best_sn);
        self.free_old_nodes();
        self.free_old_nodes();
        self.reduce_one(p, RedTodo { znode: Some(z), snode: new_sn, reduction: rr, new_snode: None, new_depth: 0 });
        let current: Vec<SId> = self.snode_hash.values().copied().collect();
        for s in current {
            for zz in self.sn[s].zns.v.clone().into_iter().flatten() {
                let pn = self.zn[zz].pn;
                if self.pn[pn].reduction == Some(rr) {
                    self.pn[pn].evaluated = true;
                    self.pn[pn].error_recovery = true;
                }
            }
        }
        self.shifts_todo.is_empty() && self.reductions_todo.is_empty()
    }

    // ---------------------------------------------------------------- commit

    fn has_final<G>(&self, p: &mut Parser<G, N>, pn: PId) -> bool {
        match self.pn[pn].reduction {
            Some(r) if !self.is_error_reduction(r) => p.has_action(ActionKind::Final, self.red(r).action_index),
            _ => false,
        }
    }

    fn is_unreduced_epsilon<G>(&self, p: &mut Parser<G, N>, pn: PId) -> bool {
        self.is_epsilon(pn) && self.has_final(p, pn)
    }

    fn final_actionless<G>(&self, p: &mut Parser<G, N>, pn: PId) -> bool {
        !self.has_final(p, pn) && self.pn[pn].children.iter().all(|&c| self.final_actionless(p, c))
    }

    fn is_internal(&self, symbol: u32) -> bool {
        self.t.symbol_kind(symbol as usize) == D_SYMBOL_INTERNAL
    }

    fn is_internal_or_ebnf(&self, symbol: u32) -> bool {
        matches!(self.t.symbol_kind(symbol as usize), D_SYMBOL_INTERNAL | D_SYMBOL_EBNF)
    }

    fn splice_child<G>(&self, p: &Parser<G, N>, node: &mut ParseNode<'a, N>, child: ParseNode<'a, N>, fixup: bool) {
        let sym = child.symbol as u32;
        let splice =
            fixup && if p.fixup_ebnf_productions { self.is_internal_or_ebnf(sym) } else { self.is_internal(sym) };
        if splice {
            node.children.extend(child.children);
        } else {
            node.children.push(child);
        }
    }

    /// A tree for `ambiguity_fn` to inspect: no final actions are run, and
    /// nested ambiguities show their first alternative.
    fn preview<G>(&mut self, p: &Parser<G, N>, pn: PId) -> ParseNode<'a, N> {
        let pn = self.latest(pn);
        let mut node = self.view(pn);
        let fixup = !p.dont_fixup_internal_productions && self.is_internal_or_ebnf(self.pn[pn].symbol);
        for i in 0..self.pn[pn].children.len() {
            let c = self.pn[pn].children[i];
            let child = self.preview(p, c);
            self.splice_child(p, &mut node, child, fixup);
        }
        node
    }

    fn resolve_ambiguities<G>(&mut self, p: &mut Parser<G, N>, pn: PId) -> Option<PId> {
        let efa = self.is_epsilon(pn) && self.final_actionless(p, pn);
        let mut pns = vec![pn];
        let mut amb = self.pn[pn].ambiguities;
        while let Some(a) = amb {
            let a = self.latest(a);
            amb = self.pn[a].ambiguities;
            if !p.dont_merge_epsilon_trees && efa && self.is_epsilon(a) && self.final_actionless(p, a) {
                continue;
            }
            if !pns.contains(&a) {
                pns.push(a);
            }
        }
        if pns.len() == 1 {
            return Some(pns[0]);
        }
        self.stats.ambiguities += pns.len() as u32 - 1;
        match p.ambiguity_fn {
            Some(f) => {
                let mut alternatives: Vec<ParseNode<'a, N>> = pns
                    .iter()
                    .map(|&a| {
                        let mut v = self.preview(p, a);
                        v.node = a as u32;
                        v
                    })
                    .collect();
                p.spec = Some(self.spec_access());
                let i = f(p, alternatives.len(), &mut alternatives);
                p.spec = None;
                Some(pns[i.min(pns.len() - 1)])
            }
            None => {
                let loc = self.pn[pn].start;
                eprintln!("{}:{}: unresolved ambiguity", p.pathname, loc.line);
                p.loc = loc;
                None
            }
        }
    }

    fn take_committed(&mut self, pn: PId) -> ParseNode<'a, N> {
        if self.is_epsilon(pn) {
            if let Some(t) = self.committed.get(&pn) {
                return t.clone();
            }
        } else if let Some(t) = self.committed.remove(&pn) {
            return t;
        }
        // evaluated without a tree: created by error recovery
        self.view(pn)
    }

    /// Resolve ambiguities and run final actions bottom up (`commit_tree`).
    pub fn commit_tree<G>(&mut self, p: &mut Parser<G, N>, pn0: PId) -> Option<ParseNode<'a, N>> {
        let pn0 = self.latest(pn0);
        if self.pn[pn0].evaluated {
            return Some(self.take_committed(pn0));
        }
        let unreduced_epsilon = self.is_unreduced_epsilon(p, pn0);
        if !unreduced_epsilon {
            self.pn[pn0].evaluated = true;
        }
        let mut pn = pn0;
        if self.pn[pn].ambiguities.is_some() {
            pn = self.resolve_ambiguities(p, pn)?;
        }
        let internal = self.is_internal_or_ebnf(self.pn[pn].symbol);
        let fixup = !p.dont_fixup_internal_productions && internal;
        let mut node = self.view(pn);
        for i in 0..self.pn[pn].children.len() {
            let c = self.pn[pn].children[i];
            let child = self.commit_tree(p, c)?;
            self.splice_child(p, &mut node, child, fixup);
        }
        let action_index = node.action_index;
        if self.has_final(p, pn) {
            p.call_action(ActionKind::Final, action_index, &mut node);
        }
        if !unreduced_epsilon {
            if !p.save_parse_tree && !internal {
                node.children.clear();
            }
            if self.is_epsilon(pn0) {
                self.committed.insert(pn0, node.clone());
            }
        }
        Some(node)
    }

    /// Commit the actions on the single parse stack under `sn` (`commit_stack`).
    fn commit_stack<G>(&mut self, p: &mut Parser<G, N>, sn: SId) -> i32 {
        // walk down the stack, then commit from the bottom up
        let mut chain: Vec<ZId> = Vec::new();
        let mut s = sn;
        loop {
            if self.sn[s].zns.v.len() != 1 {
                return -1;
            }
            let Some(z) = self.sn[s].zns.v[0] else { return -1 };
            if self.zn[z].sns.len() > 1 {
                return -2;
            }
            if self.is_unreduced_epsilon(p, self.zn[z].pn) {
                return -3;
            }
            chain.push(z);
            match self.zn[z].sns.first() {
                Some(&next) => s = next,
                None => break,
            }
        }
        for &z in chain.iter().rev() {
            let pn = self.latest(self.zn[z].pn);
            if self.pn[pn].evaluated {
                continue;
            }
            match self.commit_tree(p, pn) {
                Some(t) => {
                    self.committed.insert(pn, t);
                }
                None => return -4,
            }
        }
        0
    }

    // ---------------------------------------------------------------- driver

    /// Parse from `self.start` in `state` (`exhaustive_parse`).  Returns 0 on
    /// success, 1 on a syntax error, -1 if committing actions failed.
    pub fn exhaustive_parse<G>(&mut self, p: &mut Parser<G, N>, state: usize) -> i32 {
        self.loc.s = self.start;
        self.loc.ws = self.start;
        let mut loc = self.loc;
        self.white_space(p, &mut loc);
        let sn = self.add_snode(state, loc, self.top_scope);
        // a node standing for the start of the input, carrying the top scope
        let tpn = self.alloc_pnode(PNode {
            symbol: 0,
            start: loc,
            end: loc.s,
            end_skip: loc.s,
            scope: self.top_scope,
            initial_scope: self.top_scope,
            assoc: 0,
            priority: 0,
            op_assoc: 0,
            op_priority: 0,
            height: 0,
            serial: u32::MAX,
            children: SmallVec::new(),
            ambiguities: None,
            latest: 0,
            reduction: None,
            shift: None,
            evaluated: false,
            error_recovery: false,
            user: N::default(),
        });
        let pn = self.add_pnode(p, 0, loc, loc.s, tpn, None, None, None).expect("initial node");
        self.sn[sn].last_pn = Some(pn);
        let z = self.new_znode(pn);
        self.snode_add_znode(sn, z);
        let mut epos: Option<usize> = None;
        let mut progress: u32 = 0;
        loop {
            // reduce all
            while let Some(front) = self.reductions_todo.front() {
                let pos = self.sn[front.snode].loc.s;
                if let Some(&s) = self.shifts_todo.front() {
                    if self.sn[s].loc.s < pos {
                        break;
                    }
                }
                if epos.is_none_or(|e| pos > e) {
                    epos = Some(pos);
                    self.free_old_nodes();
                    self.maybe_gc();
                }
                while let Some(r) = self.reductions_todo.front() {
                    if self.sn[r.snode].loc.s != pos {
                        break;
                    }
                    let r = self.reductions_todo.pop_front().unwrap();
                    self.reduce_one(p, r);
                }
            }
            // done?
            if self.shifts_todo.is_empty() {
                if let Some(a) = self.accept {
                    if self.sn[a].loc.s == self.end || self.partial_parses {
                        return 0;
                    }
                }
                if self.error_recovery(p) {
                    return 1;
                }
                continue;
            } else if !p.dont_compare_stacks && self.shifts_todo.len() > 1 {
                self.cmp_stacks();
            }
            // shift all
            let pos = self.sn[self.shifts_todo[0]].loc.s;
            if epos.is_none_or(|e| pos > e) {
                epos = Some(pos);
                self.free_old_nodes();
                self.maybe_gc();
            }
            progress += 1;
            let mut ready = progress > p.commit_actions_interval;
            if ready && self.shifts_todo.len() == 1 && self.reductions_todo.is_empty() {
                if self.commit_stack(p, self.shifts_todo[0]) == -4 {
                    return -1;
                }
                ready = false;
                progress = 0;
            }
            self.shift_all(p, pos);
            if ready && self.reductions_todo.len() == 1 {
                let s = self.reductions_todo[0].snode;
                if self.commit_stack(p, s) == -4 {
                    return -1;
                }
                progress = 0;
            }
        }
    }

    fn other_accepts(&self, sn: SId, x: SId) -> bool {
        x != sn && self.sn[x].state == self.sn[sn].state && self.sn[x].loc.s == self.sn[sn].loc.s
    }

    /// The root of the parse: the accepting stack's node, with any other
    /// accepting derivations merged in as ambiguities.
    pub fn root(&mut self) -> Option<PId> {
        let sn = self.accept?;
        let ambiguous = self.sn[sn].zns.v.len() != 1
            || self.snode_all.iter().chain(self.snode_last_all.iter()).any(|&x| self.other_accepts(sn, x));
        if !ambiguous {
            return Some(self.zn[self.sn[sn].zns.v[0]?].pn);
        }
        let mut pn: Option<PId> = None;
        let mut last: Option<PId> = None;
        let mut first_z: Option<ZId> = None;
        let mut add = |e: &mut Self, x: PId| {
            let x = e.latest(x);
            match pn {
                None => pn = Some(x),
                Some(p0) if x != p0 && e.pn[x].ambiguities.is_none() && Some(x) != last => {
                    e.pn[x].ambiguities = e.pn[p0].ambiguities;
                    e.pn[p0].ambiguities = Some(x);
                    if last.is_none() {
                        last = Some(x);
                    }
                }
                _ => {}
            }
        };
        for z in self.sn[sn].zns.v.clone().into_iter().flatten() {
            add(self, self.zn[z].pn);
            first_z.get_or_insert(z);
        }
        for pass in 0..2 {
            let list: Vec<SId> =
                if pass == 0 { self.snode_all.iter().rev().copied().collect() } else { self.snode_last_all.iter().rev().copied().collect() };
            for x in list {
                if self.other_accepts(sn, x) {
                    for z in self.sn[x].zns.v.clone().into_iter().flatten() {
                        add(self, self.zn[z].pn);
                    }
                }
            }
        }
        self.sn[sn].zns = ZSet { v: SmallVec::from_elem(first_z, 1), i: 0 };
        pn
    }
}

/// Find `s` in `input[from..]`; returns the position just after it.
fn find_substr(input: &[u8], from: usize, s: &[u8]) -> Option<usize> {
    if s.is_empty() || from > input.len() {
        return None;
    }
    input[from..].windows(s.len()).position(|w| w == s).map(|i| from + i + s.len())
}

#[rustfmt::skip]
const CHILD_TABLE: [[[u16; 6]; 3]; 4] = {
    const X: u16 = 666; // impossible
    [
        // binary parent, child on left
        // priority of child vs parent, or = with child|parent associativity
        //  >  <  =LL =LR =RL =RR
        [[1, 0, 1, 1, 0, 0],   // binary child
         [1, 1, 1, 1, X, X],   // left unary child
         [1, 0, X, X, 1, 1]],  // right unary child
        // binary parent, child on right
        [[1, 0, 0, 0, 1, 1],
         [1, 0, 1, 1, X, X],
         [1, 1, X, X, 1, 1]],
        // left unary parent
        [[1, 0, 0, X, 0, X],
         [1, 1, 1, X, X, X],
         [1, 0, X, X, 1, X]],
        // right unary parent
        [[1, 0, X, 0, X, 0],
         [1, 0, X, 1, X, X],
         [1, 1, X, X, X, 1]],
    ]
};

/// True if the child is legal under the parent (`check_child` in parse.c).
fn check_child(ppri: i32, passoc: u32, cpri: i32, cassoc: u32, _left: bool, right: bool) -> bool {
    if passoc & ASSOC_NO != 0 && cassoc & ASSOC_NO != 0 && ppri == cpri {
        return false;
    }
    if is_nary_assoc(cassoc) || is_nary_assoc(passoc) {
        return true;
    }
    let p = if is_binary_nary_assoc(passoc) {
        usize::from(right)
    } else if is_left_assoc(passoc) {
        2
    } else {
        3
    };
    let c = if is_binary_nary_assoc(cassoc) {
        0
    } else if is_left_assoc(cassoc) {
        1
    } else {
        2
    };
    let r = if cpri > ppri {
        0
    } else if cpri < ppri {
        1
    } else {
        2 + (if is_right_assoc(cassoc) { 2 } else { 0 }) + (if is_right_assoc(passoc) { 1 } else { 0 })
    };
    CHILD_TABLE[p][c][r] != 0
}
