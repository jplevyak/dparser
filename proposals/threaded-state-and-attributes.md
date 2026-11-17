# Proposal: Speculation-Safe Threaded State and Post-Parse Attributes

- **Status:** Part A implemented (C, C++, Python, Rust, `python.g`, documentation); Part B not started
- **Target:** DParser 1.40 (Part A), 1.41 (Part B)
- **Date:** 2026-11-16

## Summary

DParser has no general attribute-grammar machinery. Its semantics are spread
across several mechanisms:

- synthesized `$$` values;
- one inherited, left-to-right channel (`${scope}`, the symbol table);
- a single shared global (`$g`);
- hand-ordered tree walks (`${pass}`).

A full bidirectional attribute-grammar system in the core would be very large.
It would have to be built four times (C, C++, Python, Rust). And during
parsing, information that flows right to left cannot be honored without
keeping every alternative alive.

This proposal instead adds two independent features that cover the useful
parts:

- **Part A, speculation-safe threaded state.** User-defined state that flows
  left to right like `${scope}`. The parser treats it as part of a parse
  path's identity, so speculative actions can depend on it safely. It gives
  grammars that kept path-specific state in `$g` a correct place for it,
  now that 1.39 has made `$g` read-only in speculative actions (see
  [`$g` and threaded state](#g-and-threaded-state)). It also closes the
  roadmap item
  "ensure that states only summarize identical `.scope`, `.globals` and
  `.skip_space`".
- **Part B, a post-parse attribute library.** A small runtime library that
  turns the saved parse tree into a true tree with parent links. Synthesized
  and inherited attributes are then computed on demand, cached, and checked
  for cycles. This replaces hand-ordered passes for users who want declarative
  semantics. The grammar language does not change.

## Background

### What exists today

| Mechanism | When it runs | Direction | Safe while speculating? | Notes |
|---|---|---|---|---|
| `$$` / `$0…$n` | Speculative and final actions | Bottom-up (synthesized) | Yes; each path has its own nodes | One value per node. |
| `${scope}` | Speculative actions | Left to right | Yes, since 1.38: paths whose scopes differ are kept separate | Hard-wired to `D_Scope`. |
| `$g` | Any action | None (shared) | Read-only since 1.39; before that, **no**: one pointer (`_parser->initial_globals`) is shared by every path | Writable only in final actions, unless the grammar has `${declare mutable_speculative_globals}`. See [below](#g-and-threaded-state). |
| `${pass}` | After the parse, on the final tree | Whatever order the user codes | Not applicable | Order is fixed per pass: preorder, postorder or manual. Results go in node data. Dependencies are not checked. |
| `ambiguity_fn` | When ambiguities are resolved | Not applicable | Not applicable | Gets the candidate nodes; it can only use what is already stored on them. |

### Why not a full attribute grammar in the core

Full bidirectional attribute grammars mean:

- new declaration and equation syntax in `grammar.g`;
- dependency analysis in `make_dparser`;
- a scheduler, using either ordered attribute grammar (OAG) visit sequences or
  demand-driven evaluation;
- code generation for C, C++, Python and Rust actions.

Systems in this space, such as JastAdd, Silver and Eli, are large projects in
their own right.

During parsing there is a hard limit. A speculative action runs when a
reduction happens, before the input to its right has been read. An attribute
that depends on that input cannot affect a parsing decision without keeping
every alternative alive until it can be computed. That is the generalization
of what 1.38 did for scopes, and it makes the number of live parse paths grow
quickly. So the only attribute flow that can safely affect parsing is left to
right (L-attributed). Part A provides that. Everything else can wait until the
tree exists, and Part B provides that.

---

## Part A: speculation-safe threaded state

### Problem

Grammars often need state that changes as parsing proceeds and that affects
which parses are accepted. Examples:

- **Lexical modes.** Inside a template or string interpolation, inside a
  `#if 0` block, or whether regular expressions are allowed at this point.
- **Context flags.** Inside a loop (where `break` is legal), in an `async`
  function, in a pattern rather than an expression, or the active language
  version or pragma.
- **Counters.** Nesting depth, or an indentation stack when it is not handled
  by whitespace functions.
- **Small symbol sets** that don't need the full scope machinery.

Today a grammar has two options:

- **Store it in `$g`.** This is wrong whenever two parse paths are live at
  once. A speculative action on one path changes the state that other paths
  see, and there is no way to undo it on paths that fail. Final-only actions
  avoid this, but then the state cannot influence parsing.
- **Encode it in the `D_Scope` symbol table** as fake symbols. This works, but
  it is awkward and costly, and the meaning is hidden.

### Design overview

Each parse node and stack node carries an opaque **state value** beside its
scope. State values are **immutable**. An action that wants to change the
state builds a new value and assigns it, exactly as `${scope}` is used today.

The runtime **interns** state values: equal values become the same pointer.
After that, path identity and merging compare state by pointer, just like
`initial_scope`.

```text
          input →
SNode(state=S0) ──shift──▶ ... ──reduce A (action sets ${state} = S1)──▶ SNode(state=S1)
                                └─ another path, same text, ${state} = S2 ─▶ SNode(state=S2)
                                   (kept separate because S1 != S2)
```

### Grammar and action syntax

| Specifier | Meaning |
|---|---|
| `${state}` | In a speculative action: the current threaded state. It can be assigned to change the state seen by everything to the right. In a final action: the state *after* this node, read-only. |
| `${state N}` | The state at the *start* of child `N`, read-only. |

Whitespace can read the state but not change it (see
[Whitespace](#whitespace)).

`${state}` names the inherited, threaded value. It is distinct from `$g`,
which stays a single global.

Example:

```c
{
typedef struct { int in_loop; int depth; } Ctx;
static Ctx *ctx_with(D_Parser *p, Ctx *c, int in_loop, int depth);  /* interns */
}

loop_stmt : 'while' '(' expr ')'
              [ ${state} = ctx_with(${parser}, ${state}, 1, ((Ctx*)${state})->depth + 1); ]
            stmt
              [ ${state} = ctx_with(${parser}, ${state}, 0, ((Ctx*)${state})->depth - 1); ] ;

break_stmt : 'break' ';'
  [ if (!((Ctx*)${state})->in_loop) ${reject}; ] ;
```

Because the state is part of the path's identity, a `break` that is only legal
on one of two ambiguous paths is rejected only on that path.

### C API

```c
typedef struct D_StateFns {
  unsigned (*hash)(void *state);
  int      (*equal)(void *a, void *b);   /* nonzero if equal */
  void     (*free)(void *state);         /* optional; called by free_D_Parser */
  int      (*prefer)(void *a, void *b);  /* optional; >0 prefer a, <0 prefer b, 0 neither */
} D_StateFns;

/* New D_Parser user configurables (appended; see "Compatibility"). */
D_StateFns *state_fns;      /* NULL: states are compared by pointer, not interned or freed */
void       *initial_state;

/* Helpers for actions. */
void *d_intern_state(D_Parser *p, void *state);   /* returns the canonical pointer */
void *d_get_state(D_ParseNode *pn);               /* state after pn */
void *d_get_state_before(D_ParseNode *pn);        /* state before pn */
void *d_get_whitespace_state(D_Parser *p);        /* in a whitespace function */
```

Interning keeps every comparison a pointer comparison. The runtime interns
whatever an action assigns to `${state}` when the action returns, so users
only have to intern in their constructors as an optimization.

With `state_fns == NULL` the feature still works, but state values are
compared by pointer and never interned or freed. This suits states that are
a small set of static values, or that the user interns.

**Memory.** Values are owned by the parser's intern table. Assigning a
value to `${state}` hands it to the parser: if an equal value is already
interned, the new one is freed with `state_fns->free` and the canonical
pointer is used. An action that needs to keep a value should call
`d_intern_state` first. They live until
`free_D_Parser`, which calls `state_fns->free` for each one. This matches how
scope versions live today. A later improvement could trim the table when
actions are committed (`commit_actions_interval`).

### Runtime changes (`parse.c`)

The work follows the 1.38 scope fix almost exactly:

1. **`SNode` and `PNode`** each get an `initial_state` field, set wherever
   `initial_scope` is set today. `PNode` also gets the result state.
2. **Hash-consing keys.** Add `initial_state` to the following, with pointer
   comparison:
   - `SNODE_HASH` / `find_SNode` (currently keyed on state and
     `initial_scope`);
   - `PNODE_HASH` / `find_PNode`.
3. **Ambiguity merging.** In `add_PNode` / `find_PNode`, derivations with the
   same span and symbol but different result states stay separate. This uses
   the same rule as `same_D_Scope` and the `result_scope` argument: priority,
   greediness and height still decide between such derivations, and only a
   tie with different result states keeps both.
4. **Top-level ambiguities.** `handle_top_level_ambiguities` merges accepting
   nodes at the end of input. When several accepting paths have different
   final states and `state_fns->prefer` is set, candidates whose state is
   less preferred than another candidate's are dropped first (see
   [Choosing between final states](#choosing-between-final-states)). What
   remains goes to `ambiguity_fn` like any other ambiguity.
5. **Error recovery.** Nodes created during recovery inherit the state of the
   stack node they are built on.
6. **Whitespace.** Whitespace reads the state but cannot change it; see
   [Whitespace](#whitespace).

When `state_fns == NULL`, all states are `NULL`. Hashing and comparison then
behave exactly as they do today, so grammars that don't use the feature see no
change in behavior and a negligible cost.

### Choosing between final states

Paths that survive to the end of input only because their states differ
are usually not ambiguities the user cares about, but the final state
often matters. For example, a grammar accepting two dialects can record in
the state which dialect a path has committed to. The input `print(x)` then
parses both ways, ending with `{v1}` on one path and `{v2}` on the other;
the user wants "prefer v2 when both work", not an ambiguity report.

`state_fns->prefer(a, b)` supplies that ordering. It returns a positive
value to prefer `a`, a negative value to prefer `b`, and 0 for no
preference, so it can be a partial order. At the top level, a candidate is
dropped when some other candidate's state is preferred to it. Candidates
that remain, including several with the same state or with unordered
states, go to `ambiguity_fn` as before. `prefer` is not used for merges
inside the parse, because there a state can still decide what parses later.

### Whitespace

Whitespace can **read** the threaded state but cannot **change** it.

- A whitespace function calls `d_get_whitespace_state(p)`. Whitespace
  productions see it as `${state}` in their actions; assignments there
  have no effect on the main parse.
- The state seen is the one after the preceding token, including any
  change made by that token's own action (for example a `::=` terminal
  such as `LP ::= '(' [ ... ]`). It is the state *before* any reduction
  that ends at that token, because whitespace is scanned when the token is
  shifted.
- `shift_all` caches the result of skipping whitespace per position. The
  cache key becomes (position, state), so a position reached with k
  distinct states is scanned up to k times.

Letting whitespace change the state was rejected:

- The change would belong to no parse node, so `d_get_state`,
  `${state N}` and Part B would see state change with no node responsible.
- Whitespace after a token runs before the reductions that end at that
  token, so a change from whitespace would reach those reductions'
  actions, which come earlier in the text.
- The whitespace subparser can have several accepting parses; with
  writable state it would have to return several (location, state)
  results and fork the main parse.
- Whitespace is the most frequent thing in the input, so state changes
  there would multiply parse paths.

Text that should change the mode, such as a pragma or `#if 0`, can be a
token or production in the grammar whose action sets `${state}`, with
whitespace then only reading it.

### Code generation (`write_tables.c`)

The state lives in the internal `PNode`, not in `D_ParseNode`, so generated
code reaches it through functions:

- In speculative actions, `${state}` becomes `(*d_state_slot(D_PN(_ps, _offset)))`,
  which can be assigned.
- In final actions and passes, `${state}` becomes `(d_get_state(...))`, which
  is not an lvalue, so assigning it is a compile error.
- `${state N}` becomes `(d_get_state_before(D_PN(_children[N], _offset)))`.
  The state before a node is recorded on its leftmost leaf (a token, an
  epsilon reduction or an error recovery node).

### Bindings

| Binding | Representation |
|---|---|
| C++ | `Parser::set_state<T, Prefer>(initial)` installs `D_StateFns` that use `std::hash<T>` and `==`; `Prefer` is an optional stateless comparison. Actions use `dparser::make_state(${parser}, value)` and `dparser::state<T>(${state})`; `ParseNode::state<T>()` / `state_before<T>()` read the tree. |
| Python | Any **hashable** Python object (a tuple, a frozen dataclass, `frozenset`); `None` is no state. The binding's `hash`/`equal`/`free` call `__hash__`/`__eq__`/`Py_DECREF`. `parse(initial_state=..., prefer_state=...)`. Actions take a `state` argument, a one-element list like `g`: speculative actions may replace `state[0]`, and in final actions it is the state after the node, read-only. A whitespace function taking two arguments also gets the state. `DParseNode.state` / `state_before` read the tree. |
| Rust | A `StateId` handle (0 is no state), like `ScopeId`, so no signature gains a type parameter. `Parser::states` interns values of any `Eq + Hash` type: `${parser}.make_state(v)` and `${parser}.state::<T>(id)`. `build_actions` translates `${state}` to `_ps.state` (a read-only block outside speculative actions) and `${state N}` to `_ps.children[N].state_before`. `Parser::initial_state`, `prefer_state` and `white_space_state_fn` complete it. |

### Relationship to `${scope}`

The two stay independent. A path's identity becomes (LR state, scope, threaded
state). Later, `D_Scope` could be reimplemented as one kind of threaded state,
but that is not part of this proposal: scopes have their own versioning and
commit rules (`equiv_D_Scope`, `commit_D_Scope`) that work well.

### Risks

- **More parse paths.** Each distinct state value keeps paths separate, and a
  grammar that updates state on every token could greatly increase the work.
  The documentation should recommend states that change rarely and take few
  distinct values. Debug output (`-v`) should report how many distinct states
  are live.
- **Users mutating values in place.** This breaks interning and is hard to
  debug. The documentation must say so clearly. A debug build could re-hash
  interned values at commit time and report any whose hash has changed.

### Testing

- C grammar tests (`tests/g54.test.g`, …):
  - an ambiguous grammar where a state-dependent rejection keeps exactly one
    path alive;
  - `break`-in-loop;
  - the case of the same text with different states at the top level,
    with and without `prefer`;
  - a whitespace function whose behavior depends on the state;
  - the case where state is unused (output must match today's byte for byte).
- `test_dsymtab`-style unit test for the intern table.
- Python tests with tuple and dataclass states, plus a Rust integration test.
- Run the whole existing suite to show grammars without state are unaffected.

### Effort

About 1–2 weeks: runtime and generator 3–4 days, bindings 3–4 days, tests and
documentation 2–3 days.

---

## `$g` and threaded state

Part A is not a general replacement for `$g`. The two serve different kinds
of state.

### Kinds of `$g` use in speculative actions

| How `$g` is used | Example | Safe while speculating? | Right home |
|---|---|---|---|
| Read-only context | Options, language version, file name, a lookup table loaded before the parse | Yes | `$g` |
| Shared state that is the same on every path, or harmless to repeat | String interner, memo cache, allocator, ID counter where gaps are fine | Yes, if the operations really are the same for every path | `$g` |
| State that depends on which path got here | Nesting counters, lexical modes, an indentation stack | **No** | `${state}` (Part A) or `${scope}` |

Threaded state would be a poor home for the first two rows:

- **Cost grows with the value's size.** Each update creates a new immutable
  value that is hashed and compared. That's cheap for a few integers or
  flags, but costly for a symbol table or map, unless the user writes
  persistent data structures. That is why `D_Scope` has its own versioning.
- **More values mean more parse paths.** Every distinct value keeps paths
  apart, so an interner or cache kept in threaded state would split paths for
  no reason.
- **No global accumulation.** Threaded state flows along one path. Totals
  over the whole parse, error lists and output sinks belong in `$g`, updated
  from final actions.

### The rule

- **`$g`** holds context for the whole parse that doesn't depend on the
  path: configuration, shared services (interner, allocator, error sink) and
  results accumulated by **final** actions. Speculative actions read it;
  final actions own it.
- **`${state}`** holds small, immutable, path-specific values that can
  decide whether a parse is valid. Speculative actions create new values;
  final actions read them.
- **`${scope}`** stays the specialized threaded state for symbol tables.
- **They work together.** State values can live in storage owned by `$g`,
  such as an arena or interning table, while each value's identity stays per
  path, and the state hash and equality functions can come from `$g`.

Rule of thumb: *if a failed parse path should not have changed it, it belongs
in `${state}` or `${scope}`; otherwise it belongs in `$g`.*

### Enforcement (done in 1.39)

Since 1.39, `$g` is read-only in speculative actions. This is a breaking
change, recorded in `CHANGES`:

- **C and C++:** in a speculative action, `$g` expands to
  `((const D_ParseNode_Globals *)(_parser->initial_globals))`, so a write is
  a compile error that points at the grammar line. If `D_ParseNode_Globals`
  is left as `void`, user casts such as `(G *)$g` still remove the `const`;
  only grammars that define the globals type are checked fully.
- **Rust:** the 1.39 runtime runs speculative actions during the parse,
  as C does. In them `$g` is a `&G`, so a write is a compile error.
  (Previously the Rust runtime didn't run speculative actions at all:
  `make_dparser -a` wrote them under the same header as final actions, so
  they silently ran as final actions.)
- **Compatibility:** `${declare mutable_speculative_globals}` restores the
  old behavior: C and C++ get a writable `$g`, and Rust a `&mut G`.
  `make_dparser -a` passes the declaration to `build_actions` as a
  `declare mutable_speculative_globals` line.
- **Python:** unchanged. Speculative actions still receive `g`; documentation
  is the only guard.

A per-use escape hatch (for example `${g_mut}` for writes that really are
the same on every path, such as interning) was considered and left out until
there is demand; the declaration covers existing grammars.

### What still uses the declaration

`python.g` and `tests/python.test.g` update `$g` from speculative actions:

```c
INDENT: [ if (!python_indent(&$g)) return -1; ] ;
LP ::= '(' [ $g->implicit_line_joining++; ];
RP ::= ')' [ $g->implicit_line_joining--; ];
```

If a path that reduced `LP` later dies, nothing undoes the increment. It works
only because Python's grammar rarely keeps competing paths alive across a
parenthesis. Both files now use `${declare mutable_speculative_globals}`.

This grammar is the best first test for Part A. `implicit_line_joining` and
the indent stack are read by the **whitespace function**, so Part A must let
whitespace read the threaded state (see [Whitespace](#whitespace)). Porting this grammar to
`${state}`, and adding an input where paths split across a parenthesis,
should be Part A's acceptance test.

---

## Part B: post-parse attribute library

### Problem

After the parse, semantics are written as `${pass}` functions, which have
these limits:

- **Ordering is manual.** Each pass is preorder, postorder or manual, and
  passes run in whatever order the driver calls `d_pass`. Nothing checks that
  a value has been computed before it is read.
- **No parent pointers.** Inherited information, such as "what type is
  expected here?", has to be pushed down by hand during a walk.
- **The tree is not always a tree.** Parse nodes can be **shared**: for
  example, one empty node can be reused in several places. A shared node has
  more than one parent, so "the inherited value at this node" is ambiguous.
- **Results live in `D_ParseNode_User`.** Every analysis has to fit into one
  fixed-size user struct.

### Design overview

A separate library, `libdparse_attr` (`dattr.h` / `dattr.c`), is built on the
public tree API. It needs no changes to the parser core beyond one small
accessor. Its parts:

1. **An attribute tree.** `d_attr_tree()` copies the saved parse tree into
   `D_AttrNode`s. Each one has a parent, an index within its parent, children,
   and a cache slot per attribute. A parse node reached from several parents
   gets a separate `D_AttrNode` for each occurrence, so inherited attributes
   are always well defined.
2. **Attribute descriptors.** Each attribute is synthesized or inherited and
   comes with an equation function.
3. **Demand-driven evaluation.** `d_attr_get(node, attr)` evaluates on first
   use and caches the result. It tracks three states per slot: unevaluated, in
   progress, and done. Reaching a slot that is in progress is a cycle, which
   is reported with the chain of attribute and node names.

```text
              d_attr_get(n, type)                 inherited: d_attr_get(n, env)
                    │                                    │
          type equation for n's symbol         parent's equation, given n's index
          reads children's `type`              (falls back to the grandparent if
          and n's inherited `env`               the parent defines none)
```

### C API

```c
typedef struct D_AttrNode D_AttrNode;
typedef struct D_AttrTree D_AttrTree;

typedef enum { D_ATTR_SYN, D_ATTR_INH } D_AttrKind;

typedef struct D_Attr {
  const char *name;
  D_AttrKind  kind;
  /* SYN: compute the value for node.
     INH: compute the value that parent gives to its child number child_index.
     Return nonzero if this node defines an equation; return zero to use the
     default (for INH, ask the next ancestor). */
  int  (*eval)(D_AttrTree *t, D_AttrNode *node, int child_index, void *out);
  int  size;                         /* bytes of value storage */
  void (*free)(void *value);         /* optional */
} D_Attr;

D_AttrTree *d_attr_tree(D_Parser *p, D_ParseNode *root,
                        D_Attr **attrs, int n_attrs, void *ctx);
void        d_attr_tree_free(D_AttrTree *t);

void       *d_attr_get(D_AttrTree *t, D_AttrNode *n, D_Attr *a);  /* NULL on cycle */
void       *d_attr_ctx(D_AttrTree *t);

D_AttrNode  *d_attr_root(D_AttrTree *t);
D_AttrNode  *d_attr_parent(D_AttrNode *n);
int          d_attr_index(D_AttrNode *n);         /* index within parent */
int          d_attr_n_children(D_AttrNode *n);
D_AttrNode  *d_attr_child(D_AttrNode *n, int i);
D_ParseNode *d_attr_parse_node(D_AttrNode *n);    /* symbol, text, user data */
int          d_attr_production(D_AttrNode *n);    /* see below */
```

Equations usually switch on the node's symbol or production, as `_` default
pass actions do today.

Inherited attributes default to **copy-down**: if a parent defines no equation
for a child, the request goes to the grandparent, and so on up. This is
JastAdd's rule, and it removes most of the boilerplate: an environment is
defined once at a block and is visible everywhere below it.

### Core change needed

Equations need to know *which production* built a node, not only its symbol.
`D_ParseNode` does not expose this. Add one accessor to the core:

```c
int d_get_production(D_ParseNode *pn);  /* reduction index, or -1 for a terminal */
```

Also have `make_dparser` emit named constants for productions, as it already
does for symbols (for example with `-X` header output). This also helps
`ambiguity_fn` implementations and passes, so it is worth doing even without
Part B.

### Interaction with parser features

| Feature | Behavior |
|---|---|
| `save_parse_tree = 0` | Not supported: a saved tree is required. `d_attr_tree` returns NULL. |
| Ambiguities | Built after disambiguation, so it sees exactly the final tree. A future `d_attr_tree_choose` could evaluate attributes on each candidate within `ambiguity_fn` (see the open questions). |
| `*` / `+` / internal productions | Follows the same flattening the user sees from `d_get_child`, so `D_AttrNode`s match the C API's view. |
| Error recovery nodes | Present as nodes with no reduction (`d_attr_production` returns -1). Equations should handle them, and the default for synthesized attributes is "undefined", which reads as NULL. |
| `${pass}` | Stays as it is. The two can be mixed: passes can read attributes, and attribute equations can read data that passes stored. |
| `commit_actions_interval` / streaming | Not applicable: attributes need the whole tree. |

### Bindings

| Binding | Shape |
|---|---|
| C++ | A header-only `dparser::AttrTree`, with `syn<T>("type", lambda)` / `inh<T>("env", lambda)` and `node.get<T>(attr)`. |
| Python | A pure-Python module, `dparser.attrs`, built on the existing parse-tree objects. Decorators register equations, and results are stored on node objects. About 300 lines; no C needed. |
| Rust | `dparser::attrs` over `ParseNode`, with trait-based attributes and `RefCell` caches keyed by node ID. |

### Possible later step: grammar syntax

If the library proves useful, `make_dparser` could accept declarative
equations, for example:

```c
${attr syn type: Type*}
${attr inh env: Env*}

expr: expr '+' expr  ${syn type = unify($0.type, $2.type)} ;
block: '{' stmt* '}' ${inh env(1) = extend(${inh env}, $1)} ;
```

These would generate `D_Attr` tables and equation functions. Static
circularity checking could be added at that point. This is **not** part of the
proposal; it should wait for experience with the library.

### Testing

- C tests:
  - a typed expression language using synthesized `type` and inherited `env`;
  - a shared node with two parents receiving different inherited values;
  - a deliberate cycle that must be reported;
  - copy-down inherited attributes.
- Python and Rust equivalents of the typed-expression test.
- A documentation tutorial chapter, "Attributes after parsing", using the same
  example.

### Effort

- C library and core accessor: 3–5 days.
- C++, Python and Rust wrappers: 3–5 days.
- Documentation and tests: 2–3 days.

About 1.5–2.5 weeks in total.

---

## Comparison

| Need | Today | Part A | Part B | Full attribute grammar in core |
|---|---|---|---|---|
| Bottom-up values | `$$` | — | Synthesized attributes | Yes |
| Left-to-right context that affects parsing | `${scope}` only | **User-defined, safe while speculating** | — | Only the L-attributed part |
| Top-down context after the parse | Pushed by hand in passes | — | **Inherited attributes with copy-down** | Yes |
| Evaluation order | Manual (`d_pass`) | Parse order | **Automatic, on demand** | Automatic |
| Cycle detection | None | Not applicable | At run time | Static or at run time |
| Shared nodes | Ambiguous for top-down data | Not applicable | Each occurrence is separate | Must be handled anyway |
| Grammar language changes | — | `${state}` | None (optional later) | Large |
| Effort | — | 1–2 weeks | 1.5–2.5 weeks | Months, and ongoing for four bindings |

## Recommendation and order

1. **Part A first.** 1.39 closed the correctness gap by making `$g`
   read-only in speculative actions; Part A gives the grammars that need
   path-specific state, such as `python.g`, a correct place to keep it. It
   also completes an existing roadmap item and reuses the design and tests
   from the 1.38 scope fix.
2. **The `d_get_production` accessor next**, on its own. It is small and
   useful to passes and `ambiguity_fn` today.
3. **Part B after that**, starting with the C library and the Python module,
   which is the cheapest place to try the API. Add the C++ and Rust wrappers
   once the API settles.
4. **Revisit grammar syntax for attributes** only if users of Part B ask for
   it.

## Resolved questions

1. **Part A and `ambiguity_fn`.** When complete parses differ in their
   final state, the user can choose with an optional ordering of states,
   `state_fns->prefer`, applied before `ambiguity_fn`. See
   [Choosing between final states](#choosing-between-final-states).
2. **Part A and whitespace.** Whitespace can read the state but not change
   it. See [Whitespace](#whitespace).

## Open questions

3. **Part B: attributes during disambiguation.** Is it worth building attribute
   trees for each candidate inside `ambiguity_fn`, for example to pick the
   well-typed reading of `a * b;`? This is powerful but costly, and it mixes
   the two phases.
4. **Part B: circular attributes.** Should circular attributes that iterate to
   a fixed point (JastAdd's `circular`, useful for data flow) be supported, or
   should cycles always be errors?
5. **Version.** Part A appends fields to `D_Parser` and adds fields to internal
   node structs. Does that need a major version bump, or is a minor release
   with a recompile note enough? (`D_ParseNode` itself does not change.)
