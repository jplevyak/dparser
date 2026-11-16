# Symbol Table

The symbol table (`dsymtab.c`) has to support many speculative parse paths
at once. Each path can declare and update symbols, and each must see only
its own changes, without copying the table for every path.

## The idea

A normal symbol table is a stack of scopes. DParser's is a tree of
*immutable versions*:

- A scope is never changed once a parse path might share it. A change
  creates a new **scope instance** that points back to the version it was
  derived from.
- A parse path holds a pointer to its current scope instance (`${scope}`
  in actions). Following the instance's back-pointers gives that path's
  complete history of changes.
- Two paths that diverge just hold different instances. Everything before
  the divergence is shared.

## `D_Scope`

| Field | Meaning |
|---|---|
| `ll` | Symbols declared in this instance (a linked list). |
| `hash` | For a top-level scope: a hash table of its symbols. |
| `updates` | New versions of existing symbols, made in this instance. |
| `search` | The scope to search next for declarations: the previous instance of the same scope, or the enclosing scope. |
| `dynamic` | An extra scope to search, set by `scope_D_Scope()`. |
| `up` | The lexically enclosing scope. |
| `up_updates` | The previous instance on this parse path, to search for updates. |
| `depth` | Nesting depth. |
| `down`, `down_next` | Child scopes, for freeing. |

## Operations

**Declaring.** `SPECULATIVE_NEW_D_SYM(&st, ...)` first calls
`enter_D_Scope(st, st)`, which creates an instance with `search` and
`up_updates` pointing at `st`. It then adds the symbol to the new
instance's `ll`. Paths still holding `st` don't see it.

**Updating.** `UPDATE_D_SYM(sym, &st)` likewise creates a new instance,
then adds a copy of the symbol's current version to its `updates` list.
Each update points (`update_of`) to the symbol's canonical version.

**Looking up.** `find_D_Sym(st, name)` has two steps:

1. Find the declaration: search `st`'s `ll` (or `hash`), then any
   `dynamic` scope, then follow `search` to the next instance or enclosing
   scope.
2. Find the current version (`current_D_Sym`): walk the `up_updates` chain
   from `st`, looking for an update of that symbol. The first one found is
   the newest on this path. If there is none, the declaration itself is
   current.

**Nested scopes.** `new_D_Scope(st)` creates a scope one level deeper
whose `search`, `up` and `up_updates` all point at `st`. To leave it,
`enter_D_Scope(current, outer)` creates a new instance of `outer` with
`search = outer` (so the inner declarations are no longer visible) but
`up_updates = current` (so updates made inside the block to outer symbols
are still found).

## Interaction with the parser

The scope is part of the parser's identity for states and nodes:

- SNodes are shared only between paths with the same scope.
- PNodes are shared only between derivations with the same initial scope,
  compared after `equiv_D_Scope()` maps a scope instance to the earliest
  equivalent instance (skipping instances that added nothing relevant).
- Tied derivations that end with different scopes are kept apart; see
  [Disambiguation](disambiguation.md#ambiguity-and-the-symbol-table).

This is why speculative actions must never modify a scope in place: two
paths that share a scope instance are assumed to see the same symbols.

## Commit

`commit_D_Scope(st)` collapses the history of a top-level scope: symbols
declared in the instances along `st`'s chain are moved into the top-level
hash table, and for each symbol with updates, the newest version becomes
the canonical one (its `update_of` cleared; the older versions point to
it). Later lookups through the hash table find it directly. Because it
rewrites shared structures, it is only safe when no other parse path is
using the committed scopes.

## Memory

Every scope created during a parse is registered in a pool belonging to
the top-level scope. `free_D_Scope(top, ...)` frees them all at once,
along with their symbols. This makes it impossible to leak the
intermediate instances created by updates, even for abandoned parse paths.

## Cost

Each update adds a link to the chains that lookups walk, and nothing
shortens them during a parse. A lookup therefore costs time proportional
to the number of scope instances created along the current path, and a
long input with many updates gives quadratic behavior. Grammars that
update symbols very frequently should keep that in mind.
