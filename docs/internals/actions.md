# Actions and Commit

## Speculative actions

A speculative action runs inside `make_PNode()`, right after a new parse
node has been built from a reduction path and its children's priority
information has been gathered. It runs:

- once per **distinct** node. If the same derivation is reached by
  another path, the existing node is reused and the action does not run
  again;
- possibly for nodes that are later discarded by disambiguation or by
  parse paths that die.

If the action returns nonzero (`${reject}`), the node is freed and the
reduction is abandoned on that path.

The new node's `parse_node.scope` starts as the scope of the rightmost
child, so the action sees the symbol table as of the end of the rule, and
can replace it. Speculative actions for terminals (from `[ ]` on a regex
production) run when the terminal is shifted.

## Final actions and commit

Final actions run when part of the parse is **committed**: when the parser
knows that this part will appear in the final tree, whatever happens
later. Committing a subtree (`commit_tree()`) does, bottom up:

1. resolve any ambiguities at the node with the ambiguity function;
2. commit each child;
3. flatten internal EBNF nodes into the node, unless
   `dont_fixup_internal_productions` is set;
4. run the node's final action;
5. mark the node evaluated, so it is never committed twice;
6. free the subtree below the node if `save_parse_tree` is off.

### When commits happen

Commits happen at two times:

- **At the end of the parse**, the accepted tree is committed from the
  root.
- **During the parse**, when the parse has become deterministic. The main
  loop counts shifts. Once more than `commit_actions_interval` (default
  100) have happened, and there is a single pending stack with no pending
  reductions, `commit_stack()` walks down that stack for as long as it is
  unambiguous (one ZNode per SNode, one predecessor per ZNode) and commits
  the subtrees it finds.

So final actions run in input order, in batches, a while behind the
parser. With `commit_actions_interval = 0` they run as early as possible;
with a very large value, they all run at the end. Committing early keeps
memory use bounded for long inputs when `save_parse_tree` is off, since
committed subtrees can be freed.

Empty (epsilon) nodes with final actions are not committed until they
have been reduced into a larger node, because the same empty node can be
shared by several positions in the tree.

## Pass actions

`d_pass()` walks a committed subtree, calling the pass's action for each
node in preorder or postorder (or only at the root, for `manual` passes).
For `for_undefined` passes, the traversal into children only happens for
nodes without an action for the pass. Default pass actions from the `_`
production apply to rules without their own.

## Error recovery nodes

A node synthesized by error recovery is marked as already evaluated, so
its final action never runs. Its children that were parsed normally are
committed as usual.
