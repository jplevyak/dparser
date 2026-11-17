//! `attrs.rs`
//! Attributes after parsing: synthesized and inherited attributes over a
//! parse tree, evaluated on demand, cached, and checked for cycles.
//!
//! ```ignore
//! use dparser::attrs::{Attr, AttrTree, NodeId};
//!
//! // env: inherited; a block gives its children its env plus its declarations.
//! fn env_eq(t: &AttrTree<'_, '_, Node>, n: NodeId, child: i32) -> Option<Env> {
//!     if child < 0 { return Some(Env::default()); }
//!     if t.name(n) != "block" { return None; }      // copy down
//!     let mut e = t.get(n, &ENV)?;
//!     /* add the block's declarations */
//!     Some(e)
//! }
//! const ENV: Attr<Env, Node> = Attr::inh("env", env_eq);
//!
//! let tree = AttrTree::new(&parser, &root);
//! let env_at_root = tree.get(tree.root(), &ENV);
//! ```

use crate::grammar::SafeGrammarTables;
use crate::types::ParseNode;
use crate::Parser;
use std::any::Any;
use std::cell::RefCell;
use std::collections::HashMap;

/// A node of an [`AttrTree`].
pub type NodeId = usize;

/// Whether an attribute is synthesized or inherited.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AttrKind {
    Syn,
    Inh,
}

/// An equation.  Synthesized: `eq(tree, node, -1)` computes the value at
/// `node`.  Inherited: `eq(tree, parent, i)` computes the value `parent`
/// gives its child `i`, and `eq(tree, root, -1)` the root's own value.
/// Returning `None` makes a synthesized value undefined and copies an
/// inherited value down from the nearest ancestor with an equation.
pub type Equation<T, N> = fn(&AttrTree<'_, '_, N>, NodeId, i32) -> Option<T>;

/// An attribute with values of type `T`, usually a `const`.  Attributes are
/// identified by name, so names must be distinct within a tree.
pub struct Attr<T, N: 'static> {
    pub name: &'static str,
    pub kind: AttrKind,
    pub equation: Equation<T, N>,
}

impl<T, N> Attr<T, N> {
    pub const fn syn(name: &'static str, equation: Equation<T, N>) -> Self {
        Attr { name, kind: AttrKind::Syn, equation }
    }
    pub const fn inh(name: &'static str, equation: Equation<T, N>) -> Self {
        Attr { name, kind: AttrKind::Inh, equation }
    }
}

enum Slot {
    InProgress,
    Done(Option<Box<dyn Any>>),
}

struct Node<'t, 'a, N> {
    node: &'t ParseNode<'a, N>,
    parent: Option<NodeId>,
    index: i32,
    children: Vec<NodeId>,
}

/// A cycle: the (attribute, node) requests on it, ending with the one that
/// closed it.
pub type Cycle = Vec<(&'static str, NodeId)>;

/// Attributes over a parse tree.  A node reached from several parents gets a
/// separate [`NodeId`] for each occurrence.
pub struct AttrTree<'t, 'a, N> {
    nodes: Vec<Node<'t, 'a, N>>,
    tables: Option<&'t SafeGrammarTables>,
    slots: RefCell<HashMap<(NodeId, &'static str), Slot>>,
    stack: RefCell<Vec<(&'static str, NodeId)>>,
    cycles: RefCell<Vec<Cycle>>,
}

impl<'t, 'a, N: 'static> AttrTree<'t, 'a, N> {
    /// An attribute tree over `root`, with symbol names from `parser`'s
    /// grammar.
    pub fn new<G>(parser: &'t Parser<G, N>, root: &'t ParseNode<'a, N>) -> Self
    where
        N: Default + Clone,
    {
        let mut t = Self::without_names(root);
        t.tables = Some(parser.tables());
        t
    }

    /// An attribute tree over `root`, without symbol names.
    pub fn without_names(root: &'t ParseNode<'a, N>) -> Self {
        let mut nodes = vec![Node { node: root, parent: None, index: -1, children: Vec::new() }];
        let mut todo = vec![0];
        while let Some(id) = todo.pop() {
            let node = nodes[id].node;
            for (i, c) in node.children.iter().enumerate() {
                nodes.push(Node { node: c, parent: Some(id), index: i as i32, children: Vec::new() });
                let cid = nodes.len() - 1;
                nodes[id].children.push(cid);
                todo.push(cid);
            }
        }
        AttrTree {
            nodes,
            tables: None,
            slots: RefCell::new(HashMap::new()),
            stack: RefCell::new(Vec::new()),
            cycles: RefCell::new(Vec::new()),
        }
    }

    pub fn root(&self) -> NodeId {
        0
    }
    pub fn parent(&self, n: NodeId) -> Option<NodeId> {
        self.nodes[n].parent
    }
    /// The index of `n` within its parent; -1 for the root.
    pub fn index(&self, n: NodeId) -> i32 {
        self.nodes[n].index
    }
    pub fn children(&self, n: NodeId) -> &[NodeId] {
        &self.nodes[n].children
    }
    pub fn child(&self, n: NodeId, i: usize) -> NodeId {
        self.nodes[n].children[i]
    }
    /// The parse node.
    pub fn node(&self, n: NodeId) -> &'t ParseNode<'a, N> {
        self.nodes[n].node
    }
    /// The node's text.
    pub fn text(&self, n: NodeId) -> &'a str {
        self.nodes[n].node.string
    }
    /// The node's symbol name ("" without names).
    pub fn name(&self, n: NodeId) -> &'t str {
        let sym = self.nodes[n].node.symbol;
        self.tables
            .and_then(|t| t.symbols.get(sym as usize))
            .map_or("", |s| s.name.as_str())
    }
    /// The rule that built the node (see [`ParseNode::production`]).
    pub fn production(&self, n: NodeId) -> i32 {
        self.nodes[n].node.production()
    }
    /// All nodes, parents before children.
    pub fn nodes(&self) -> impl Iterator<Item = NodeId> {
        0..self.nodes.len()
    }

    /// The value of `attr` at `n`: `None` if it is undefined or part of a
    /// cycle (see [`cycles`](Self::cycles)).
    pub fn get<T: Clone + 'static>(&self, n: NodeId, attr: &Attr<T, N>) -> Option<T> {
        let key = (n, attr.name);
        match self.slots.borrow().get(&key) {
            Some(Slot::Done(v)) => return v.as_ref().and_then(|v| v.downcast_ref::<T>()).cloned(),
            Some(Slot::InProgress) => {
                let stack = self.stack.borrow();
                let start = stack.iter().position(|&(a, m)| a == attr.name && m == n).unwrap_or(0);
                let mut cycle: Cycle = stack[start..].to_vec();
                cycle.push((attr.name, n));
                self.cycles.borrow_mut().push(cycle);
                return None;
            }
            None => {}
        }
        self.slots.borrow_mut().insert(key, Slot::InProgress);
        self.stack.borrow_mut().push((attr.name, n));
        let v = match (attr.kind, self.nodes[n].parent) {
            (AttrKind::Syn, _) | (AttrKind::Inh, None) => (attr.equation)(self, n, -1),
            (AttrKind::Inh, Some(p)) => match (attr.equation)(self, p, self.nodes[n].index) {
                Some(v) => Some(v),
                None => self.get(p, attr),
            },
        };
        self.stack.borrow_mut().pop();
        self.slots
            .borrow_mut()
            .insert(key, Slot::Done(v.clone().map(|v| Box::new(v) as Box<dyn Any>)));
        v
    }

    /// The cycles found so far.
    pub fn cycles(&self) -> Vec<Cycle> {
        self.cycles.borrow().clone()
    }
}
