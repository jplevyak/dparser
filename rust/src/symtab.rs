//! `symtab.rs`
//! The symbol table (a port of `dsymtab.c`), usable from speculative actions.
//!
//! Scopes and symbols live in a [`SymTab`] owned by the parser and are
//! referred to by [`ScopeId`] and [`SymId`].  The parser keeps parse paths
//! whose scopes differ apart, so speculative actions can declare and look up
//! symbols (for example C typedef names) safely.
//!
//! In actions, `${scope}` is the current scope (a `ScopeId`, which actions
//! may assign) and `${parser}.symtab` is the table.  Use the `speculative_*`
//! and `update_sym` operations in speculative actions: they create a new scope
//! instance for this parse path instead of changing a scope other paths share.

use std::collections::HashMap;

/// A scope (`D_Scope *`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ScopeId(pub u32);

/// A symbol (`D_Sym *`).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct SymId(pub u32);

pub const D_SCOPE_INHERIT: u32 = 0;
pub const D_SCOPE_RECURSIVE: u32 = 1;
pub const D_SCOPE_PARALLEL: u32 = 2;
pub const D_SCOPE_SEQUENTIAL: u32 = 3;

#[derive(Clone, Debug)]
pub struct Sym {
    pub name: String,
    /// The scope the symbol was declared in.
    pub scope: ScopeId,
    /// For a version created by an update, the original symbol.
    pub update_of: Option<SymId>,
    /// User data (`D_UserSym`), copied when the symbol is updated.
    pub user: u64,
}

#[derive(Clone, Debug, Default)]
struct Scope {
    kind: u32,
    depth: u32,
    /// Symbols declared here, newest first (top-level scopes use `hash`).
    ll: Vec<SymId>,
    hash: Option<HashMap<String, Vec<SymId>>>,
    /// Updated versions of symbols, newest first.
    updates: Vec<SymId>,
    search: Option<ScopeId>,
    dynamic: Option<ScopeId>,
    up: Option<ScopeId>,
    up_updates: Option<ScopeId>,
}

#[derive(Clone, Debug, Default)]
pub struct SymTab {
    scopes: Vec<Scope>,
    syms: Vec<Sym>,
}

impl SymTab {
    pub fn new() -> Self {
        Self::default()
    }

    fn sc(&self, s: ScopeId) -> &Scope {
        &self.scopes[s.0 as usize]
    }
    fn sc_mut(&mut self, s: ScopeId) -> &mut Scope {
        &mut self.scopes[s.0 as usize]
    }
    fn add_scope(&mut self, s: Scope) -> ScopeId {
        self.scopes.push(s);
        ScopeId(self.scopes.len() as u32 - 1)
    }

    pub fn sym(&self, s: SymId) -> &Sym {
        &self.syms[s.0 as usize]
    }
    pub fn sym_mut(&mut self, s: SymId) -> &mut Sym {
        &mut self.syms[s.0 as usize]
    }

    pub fn kind(&self, s: ScopeId) -> u32 {
        self.sc(s).kind
    }
    pub fn set_kind(&mut self, s: ScopeId, kind: u32) {
        self.sc_mut(s).kind = kind;
    }
    pub fn depth(&self, s: ScopeId) -> u32 {
        self.sc(s).depth
    }
    /// The lexically enclosing scope.
    pub fn up(&self, s: ScopeId) -> Option<ScopeId> {
        self.sc(s).up
    }

    /// A new scope (`new_D_Scope`): nested in `parent`, or a new top level.
    pub fn new_scope(&mut self, parent: Option<ScopeId>) -> ScopeId {
        match parent {
            Some(p) => {
                let (depth, kind) = (self.sc(p).depth + 1, self.sc(p).kind);
                self.add_scope(Scope {
                    depth,
                    kind,
                    search: Some(p),
                    up: Some(p),
                    up_updates: Some(p),
                    ..Default::default()
                })
            }
            None => self.add_scope(Scope { hash: Some(HashMap::new()), ..Default::default() }),
        }
    }

    /// Re-enter `scope` from `current` on this parse path (`enter_D_Scope`).
    pub fn enter_scope(&mut self, current: ScopeId, scope: ScopeId) -> ScopeId {
        let s = self.sc(scope);
        let (depth, up, kind) = (s.depth, s.up, s.kind);
        self.add_scope(Scope {
            depth,
            up,
            kind,
            search: Some(scope),
            up_updates: Some(current),
            ..Default::default()
        })
    }

    /// Enter the global scope from `current` (`global_D_Scope`).
    pub fn global_scope(&mut self, current: ScopeId) -> ScopeId {
        let mut g = current;
        while self.sc(g).up.is_some() {
            g = self.sc(g).search.expect("scope with 'up' has 'search'");
        }
        self.enter_scope(current, g)
    }

    /// `current` with `scope` searched as well, e.g. class members (`scope_D_Scope`).
    pub fn scope_scope(&mut self, current: ScopeId, scope: ScopeId) -> ScopeId {
        let c = self.sc(current);
        let (depth, up, kind) = (c.depth, c.up, c.kind);
        self.add_scope(Scope {
            depth,
            up,
            kind,
            search: Some(current),
            dynamic: Some(scope),
            up_updates: Some(current),
            ..Default::default()
        })
    }

    /// The oldest scope giving the same view of the symbol table as `current`
    /// (`equiv_D_Scope`).  The parser uses this to share work between parse
    /// paths whose scopes differ only in name.
    pub fn equiv_scope(&self, current: ScopeId) -> ScopeId {
        let cur = self.sc(current);
        let (mut s, mut last) = (current, current);
        while self.sc(s).depth >= cur.depth {
            let ss = self.sc(s);
            if ss.depth == self.sc(last).depth {
                if cur.up == ss.up {
                    last = s;
                } else {
                    break;
                }
            }
            if !ss.ll.is_empty() || ss.hash.is_some() || ss.dynamic.is_some() {
                break;
            }
            if ss.updates.iter().any(|&u| self.sc(self.sym(u).scope).depth <= cur.depth) {
                break;
            }
            match ss.up_updates {
                Some(u) => s = u,
                None => break,
            }
        }
        last
    }

    /// Commit the declarations and updates seen from `st` into its top-level
    /// scope (`commit_D_Scope`).  Only call it when no other parse path still
    /// uses the scopes being committed.  Returns the top-level scope.
    pub fn commit_scope(&mut self, st: ScopeId) -> ScopeId {
        if self.sc(st).up.is_some() {
            return st;
        }
        let mut x = st;
        while let Some(s) = self.sc(x).search {
            x = s;
        }
        self.commit_ll(st, x);
        // commit_update
        let all: Vec<SymId> = self.sc(x).hash.as_ref().unwrap().values().flatten().copied().collect();
        for s in all {
            let root = self.root_sym(s);
            let latest = self.current_sym(st, s);
            if latest == root {
                continue;
            }
            self.sym_mut(latest).update_of = None;
            self.sym_mut(root).update_of = Some(latest);
        }
        x
    }

    fn commit_ll(&mut self, st: ScopeId, top: ScopeId) {
        if let Some(search) = self.sc(st).search {
            self.commit_ll(search, top);
            let ll = std::mem::take(&mut self.sc_mut(st).ll);
            for s in ll {
                let name = self.sym(s).name.clone();
                self.sc_mut(top).hash.as_mut().unwrap().entry(name).or_default().insert(0, s);
            }
        }
    }

    fn root_sym(&self, mut s: SymId) -> SymId {
        while let Some(u) = self.sym(s).update_of {
            s = u;
        }
        s
    }

    /// Declare `name` in scope `st` (`NEW_D_SYM`).  In speculative actions use
    /// [`speculative_new_sym`](Self::speculative_new_sym) instead, since `st`
    /// may be shared with other parse paths.
    pub fn new_sym(&mut self, st: ScopeId, name: &str) -> SymId {
        self.syms.push(Sym { name: name.to_string(), scope: st, update_of: None, user: 0 });
        let id = SymId(self.syms.len() as u32 - 1);
        let scope = self.sc_mut(st);
        match scope.hash.as_mut() {
            Some(h) => h.entry(name.to_string()).or_default().insert(0, id),
            None => scope.ll.insert(0, id),
        }
        id
    }

    /// Declare `name` on this parse path only, in a new instance of `*st`
    /// (`SPECULATIVE_NEW_D_SYM`).
    pub fn speculative_new_sym(&mut self, st: &mut ScopeId, name: &str) -> SymId {
        *st = self.enter_scope(*st, *st);
        self.new_sym(*st, name)
    }

    /// The version of `sym` visible from `st` (`current_D_Sym`).
    pub fn current_sym(&self, st: ScopeId, sym: SymId) -> SymId {
        let sym = self.root_sym(sym);
        let mut sc = Some(st);
        while let Some(s) = sc {
            if let Some(&u) = self.sc(s).updates.iter().find(|&&u| self.sym(u).update_of == Some(sym)) {
                return u;
            }
            sc = self.sc(s).up_updates;
        }
        sym
    }

    fn find_in_scope_internal(&self, mut st: Option<ScopeId>, name: &str) -> Option<SymId> {
        while let Some(s) = st {
            let sc = self.sc(s);
            if let Some(found) = self.lookup_here(sc, name) {
                return Some(found);
            }
            if let Some(d) = sc.dynamic {
                if let Some(found) = self.find_in_scope_internal(Some(d), name) {
                    return Some(found);
                }
            }
            match sc.search {
                Some(next) if self.sc(next).up == sc.up => st = Some(next),
                _ => break,
            }
        }
        None
    }

    fn lookup_here(&self, sc: &Scope, name: &str) -> Option<SymId> {
        match &sc.hash {
            Some(h) => h.get(name).and_then(|v| v.first().copied()),
            None => sc.ll.iter().copied().find(|&s| self.sym(s).name == name),
        }
    }

    fn find_internal(&self, cur: ScopeId, name: &str) -> Option<SymId> {
        let mut cur = cur;
        loop {
            let sc = self.sc(cur);
            if let Some(found) = self.lookup_here(sc, name) {
                return Some(found);
            }
            if let Some(d) = sc.dynamic {
                if let Some(found) = self.find_in_scope_internal(Some(d), name) {
                    return Some(found);
                }
            }
            cur = sc.search?;
        }
    }

    /// Look `name` up from `st` (`find_D_Sym`).
    pub fn find_sym(&self, st: ScopeId, name: &str) -> Option<SymId> {
        self.find_internal(st, name).map(|s| self.current_sym(st, s))
    }

    /// Look `name` up in the global scope, as seen from `st` (`find_global_D_Sym`).
    pub fn find_global_sym(&self, st: ScopeId, name: &str) -> Option<SymId> {
        let mut cur = st;
        while self.sc(cur).up.is_some() {
            cur = self.sc(cur).search?;
        }
        self.find_internal(cur, name).map(|s| self.current_sym(st, s))
    }

    /// Look `name` up in scope `cur` only, as seen from `st` (`find_D_Sym_in_Scope`).
    pub fn find_sym_in_scope(&self, st: ScopeId, cur: ScopeId, name: &str) -> Option<SymId> {
        self.find_in_scope_internal(Some(cur), name).map(|s| self.current_sym(st, s))
    }

    /// All symbols declared in `st` itself (and the instances of it that it
    /// searches), newest first (as `next_D_Sym_in_Scope`).
    pub fn syms_in_scope(&self, st: ScopeId) -> Vec<SymId> {
        let mut out = Vec::new();
        let mut cur = Some(st);
        while let Some(s) = cur {
            let sc = self.sc(s);
            match &sc.hash {
                Some(h) => out.extend(h.values().flatten().copied()),
                None => out.extend(sc.ll.iter().copied()),
            }
            match sc.search {
                Some(next) if self.sc(next).up == sc.up => cur = Some(next),
                _ => break,
            }
        }
        out
    }

    /// A new version of `sym` in scope `st`, for further updates in the same
    /// action (`UPDATE_ADDITIONAL_D_SYM`).
    pub fn update_additional_sym(&mut self, st: ScopeId, sym: SymId) -> SymId {
        let cur = self.current_sym(st, sym);
        let mut s = self.sym(cur).clone();
        s.update_of = Some(self.root_sym(cur));
        self.syms.push(s);
        let id = SymId(self.syms.len() as u32 - 1);
        self.sc_mut(st).updates.insert(0, id);
        id
    }

    /// A new version of `sym` on this parse path, in a new instance of `*st`
    /// (`UPDATE_D_SYM`).
    pub fn update_sym(&mut self, sym: SymId, st: &mut ScopeId) -> SymId {
        *st = self.enter_scope(*st, *st);
        self.update_additional_sym(*st, sym)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn declarations_and_lookup() {
        let mut t = SymTab::new();
        let top = t.new_scope(None);
        let a = t.new_sym(top, "a");
        let inner = t.new_scope(Some(top));
        let b = t.new_sym(inner, "b");
        assert_eq!(t.find_sym(inner, "a"), Some(a));
        assert_eq!(t.find_sym(inner, "b"), Some(b));
        assert_eq!(t.find_sym(top, "b"), None);
        assert_eq!(t.find_sym_in_scope(inner, inner, "a"), None);
    }

    #[test]
    fn speculative_declarations_stay_on_their_path() {
        let mut t = SymTab::new();
        let top = t.new_scope(None);
        let (mut p1, p2) = (top, top);
        t.speculative_new_sym(&mut p1, "T");
        assert!(t.find_sym(p1, "T").is_some());
        assert!(t.find_sym(p2, "T").is_none());
        // committing the surviving path makes it visible at top level
        let g = t.commit_scope(p1);
        assert_eq!(g, top);
        assert!(t.find_sym(top, "T").is_some());
    }

    #[test]
    fn updates_are_per_path_and_commit() {
        let mut t = SymTab::new();
        let top = t.new_scope(None);
        let x = t.new_sym(top, "x");
        t.sym_mut(x).user = 1;
        let mut p1 = top;
        let x1 = t.update_sym(x, &mut p1);
        t.sym_mut(x1).user = 2;
        assert_eq!(t.sym(t.find_sym(p1, "x").unwrap()).user, 2);
        assert_eq!(t.sym(t.find_sym(top, "x").unwrap()).user, 1);
        let mut p2 = p1;
        let x2 = t.update_sym(x, &mut p2);
        t.sym_mut(x2).user = 3;
        t.commit_scope(p2);
        assert_eq!(t.sym(t.find_sym(top, "x").unwrap()).user, 3);
        // later updates still work after a commit
        let mut p3 = top;
        let x3 = t.update_sym(x, &mut p3);
        t.sym_mut(x3).user = 4;
        assert_eq!(t.sym(t.find_sym(p3, "x").unwrap()).user, 4);
    }

    #[test]
    fn equivalent_scopes() {
        let mut t = SymTab::new();
        let top = t.new_scope(None);
        let e = t.enter_scope(top, top);
        assert_eq!(t.equiv_scope(e), t.equiv_scope(top));
        let mut d = top;
        t.speculative_new_sym(&mut d, "x");
        assert_ne!(t.equiv_scope(d), t.equiv_scope(top));
    }
}
