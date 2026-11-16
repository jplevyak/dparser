# Disambiguation

DParser disambiguates at three points: before a node is built, when two
nodes for the same span meet, and when the tree is committed. Most of the
work is done at the first point, which stops invalid operator trees from
being built at all.

## Priority information on nodes

Each PNode carries two pairs of fields, set by `reduce_actions()`:

- **`op_assoc`, `op_priority`**: the node is an *operator*. They come from
  `$binary_op_left` and similar on the reduction, or from an external
  scanner.
- **`assoc`, `priority`**: the node is an *expression built with* an
  operator or a prioritized rule. They come from `$left`/`$right` on the
  rule, or are inherited from an operator child.

## Checking before building

### Rule priorities

When a node with a rule priority is built, `make_PNode()` checks its first
and last children. If a child also has a rule priority, `check_child()`
decides whether that child may appear in that position. For example, in
`E: E '+' E $left 10`, a right child built by the same rule (another `+`)
is rejected because the rule is left associative, and a child built by a
lower-priority rule is rejected because it should have been the parent.
The node is never created.

### Operator priorities

For operator priorities, the check happens even earlier, on stack paths.
Before `reduce_one()` builds a node from a path, `check_path_priorities()`
looks at the operators on the path, and on the stack just beyond it, and
rejects paths where an expression would become the operand of an operator
it is not allowed under.

Both checks use `check_child()`, which looks up a constant table indexed
by:

- the parent's kind: binary with the child on the left, binary with the
  child on the right, left unary, or right unary;
- the child's kind: binary, left unary or right unary;
- the comparison: child priority higher, lower, or equal with each
  combination of left and right associativity.

So each check takes constant time.

## Pruning stacks: `cmp_stacks`

Grammars with an *empty* binary operator, such as juxtaposition for
function application or string concatenation, can create many parallel
stacks that differ only in which operator was assumed. Before each shift,
`cmp_stacks()` compares pending stacks that have a binary operator on top
of identical substacks, where one state reduces to the other, and drops
the one whose operator has lower priority. `dont_compare_stacks` turns
this off.

## Comparing nodes for the same span

When a new PNode has the same start, end, symbol and initial scope as an
existing one, `cmp_pnodes()` compares them:

1. **Deep priorities** (`cmp_priorities`), if both nodes have priorities.
   The nodes that are not shared between the two trees are collected
   (`get_unshared_pnodes`, which walks both trees from the top using
   heaps ordered by height, stopping at shared subtrees). Each side's
   nodes are sorted: nodes with priorities first, then by least height,
   highest priority, earliest start and longest extent. The two lists
   are compared element by element, and the first difference in priority
   decides.
2. **Greediness** (`cmp_greediness`). The unshared nodes are sorted by
   start, then symbol, then end, and walked in step. At the first
   position where both sides have a node for the same symbol, the one
   that extends further wins; with equal extent, the one with fewer
   children wins.
3. **Height.** The lower tree wins.

The loser is freed. If a winner was found but it is the new node, the old
node's `latest` field is set to the new one, and later references follow
`latest`.

If no rule decides, the new node is linked into the existing node's
`ambiguities` list.

## Resolving at commit

When the tree is committed (see [Actions and Commit](actions.md)),
`resolve_ambiguities()` collects a node and its ambiguities. If they are
all empty (epsilon) trees without final actions, they are merged, unless
`dont_merge_epsilon_trees` is set. Otherwise the parser's `ambiguity_fn`
is called with them, and the returned node replaces the others.

## Ambiguity and the symbol table

Hash-consing PNodes uses the *initial* scope (the scope before the node),
reduced with `equiv_D_Scope()` so that scope instances that give the same
view compare equal. When two alternatives tie, but their speculative
actions produced scopes that differ, they are **not** merged as
ambiguities. Both are kept as separate nodes, so each parse path continues
with its own symbol table. Merging them would silently continue with only
one of the two scopes. If more than one such path reaches the end of the
input, `handle_top_level_ambiguities()` combines the accepting nodes as
alternatives, so the choice goes to the ambiguity function as usual.
