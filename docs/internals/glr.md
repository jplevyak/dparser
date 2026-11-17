# The GLR Runtime

DParser's runtime (`parse.c`) is a GLR parser in the style of Tomita.
Instead of a single parse stack it keeps a *graph-structured stack* that
represents every live parse at once, sharing their common parts.

## Data structures

Three kinds of node make up the stack graph and the parse forest:

``` mermaid
flowchart RL
  S2["SNode<br/>state 7 @ pos 5"] --> Z2["ZNode"]
  Z2 -->|pn| P2["PNode<br/>expr '1+2'"]
  Z2 -->|sns| S1["SNode<br/>state 3 @ pos 0"]
  S3["SNode<br/>state 9 @ pos 5"] --> Z3["ZNode"]
  Z3 -->|pn| P2
  Z3 -->|sns| S1
```

**`SNode` (state node).** A parse state at a position in the input: the
LR state, the location, the symbol table scope and the
[threaded state](../reference/threaded-state.md). SNodes are hash-consed
on *(state, scope, threaded state)* at each position, so all parses that
reach the same state at the same place with the same view of the symbol
table and the same threaded state share one SNode.

**`ZNode` (symbol node).** An edge of the stack graph. An SNode has a set
of ZNodes, each holding the parse node (`pn`) that was shifted or reduced
to reach this state, and the set of predecessor SNodes (`sns`) it came
from. Several ZNodes per SNode, and several predecessors per ZNode, are
what make the stack a graph.

**`PNode` (parse node).** A node of the parse forest: a symbol spanning
some input, with its children, priority information, and the public
`D_ParseNode` (with your user data) embedded at its end. PNodes are
hash-consed on *(start, end, symbol, initial scope, initial threaded
state)*, so the same
derivation reached by different stack paths is built once. Alternative
derivations of the same span are linked through the `ambiguities` list.
When disambiguation replaces a node by a better one, the old node's
`latest` field points to the replacement.

All three are reference counted (unless built with the garbage collector)
and recycled through free lists.

## The main loop

`exhaustive_parse()` processes the input from left to right. It keeps two
queues: `shifts_todo` (SNodes waiting to scan their next terminal) and
`reductions_todo` (reductions waiting to be performed), both ordered by
position.

```text
create the initial SNode for the start state
loop:
    perform every pending reduction at the current position
    if no shifts are pending:
        if an accept state has been reached at the end of the input
        (or anywhere, with partial_parses): done
        otherwise: try error recovery, or fail
    prune stacks with cmp_stacks (unless dont_compare_stacks)
    periodically commit final actions
    shift: scan from every SNode at the current position
```

### Shifting

`shift_all()` runs each pending SNode's scanner (and external scanner, if
any) at the current position, collecting every terminal match. After the
matches are filtered (see [Scanning](scanning.md)), each surviving match
creates a PNode for the terminal and moves to the goto state. Whitespace
is skipped after the terminal, so the new SNode's position is the start of
the next token.

### Reducing

When an SNode is created (by `goto_PNode()`), a reduction is queued for
each rule its state can reduce. Rules of length 0 (epsilon reductions)
are performed directly from that SNode. Otherwise `reduce_one()`
enumerates every path of length *n* back through the stack graph from the
newly added ZNode (`build_paths`). For each path:

1. The operator priorities along the path are checked
   (`check_path_priorities`). A path that would build an illegal operator
   tree is skipped. See [Disambiguation](disambiguation.md).
2. `add_PNode()` finds or creates the PNode for the reduction. This is
   where speculative actions run, where rule priorities are checked
   against the children, and where ambiguity with an existing PNode for
   the same span is detected and resolved.
3. `goto_PNode()` moves from each SNode at the start of the path to the
   goto state for the new symbol, creating or reusing that SNode and
   adding a ZNode. New ZNodes on existing SNodes queue further reductions,
   including ones on other paths through the new edge.

Right epsilon hints (see [Table Construction](tables.md#hints-for-the-runtime))
let a rule whose remaining symbols are all nullable be reduced without
first reducing each empty symbol.

### Node lifetimes

Once the parse has moved past a position, nodes at earlier positions are
no longer in the hash tables (`free_old_nodes`), but remain alive as long
as they are referenced from the stack graph or the parse forest.

## Ambiguity

When `add_PNode()` creates a node with the same start, end, symbol,
initial scope and initial threaded state as an existing one, the two are compared with `cmp_pnodes()`
(priorities, then greediness, then height). The loser is discarded. If
neither wins, the new node is added to the existing node's `ambiguities`
list, to be resolved by the ambiguity function when the tree is
committed.

Derivations whose speculative actions left the symbol table or the
threaded state different are not merged. They stay as separate PNodes, so
each parse path continues with its own scope and state. If several survive
to the end of the input, they are combined as alternatives at the top of
the tree, after dropping any whose final threaded state is less preferred
(`state_fns->prefer`) than another's.

Threaded states are interned (`d_intern_state`), so comparing them, and
hashing them into the keys above, is a pointer operation. Whitespace is
skipped once per token end position and threaded state, since a
whitespace function may read the state.

See [Disambiguation](disambiguation.md) for the comparison rules.

## Complexity

For unambiguous input, parsing is close to linear: at each position only
a few SNodes are live, and the scanner, shift and reduce work per position
is bounded. Local ambiguity costs work proportional to the number of live
alternatives, and sharing through hash-consing avoids repeating work that
alternatives have in common. Grammars where alternatives can't be resolved
until much later (for example, a large expression grammar with no
priorities) keep many stack paths alive, and benefit most from priorities
and `cmp_stacks`.

The sample driver in the source tree, `sample_parser -v`, prints counts
of states, scans, shifts, reductions and comparisons for a parse, which
help to spot unexpectedly expensive grammars.
