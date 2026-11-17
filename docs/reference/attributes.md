# Attributes

Attributes are values computed on the finished parse tree from equations,
evaluated on demand and cached. The [tutorial](../tutorial/attributes.md)
walks through an example.

- A **synthesized** attribute of a node is computed from the node and its
  children.
- An **inherited** attribute of a node is given to it by its parent. If
  the parent has no equation for it, the node gets its parent's value, and
  so on up the tree: **copy-down**. So an equation at a block reaches every
  node inside it.
- An attribute is computed the first time it is asked for, and then
  cached. A value that depends on itself is a **cycle**, which is reported.
- A parse node reached from several parents (empty nodes can be shared)
  appears once per occurrence, so each occurrence has its own inherited
  values.
- Attributes work on the final tree, after disambiguation, so the parse
  tree must be saved.

Attributes and [passes](actions.md#pass-actions) can be mixed: equations
can read data that passes stored in nodes, and passes can ask for
attributes.

## Which rule built a node

```c
int d_get_production(D_ParseNode *pn);
```

returns the rule that built a node, or -1 for terminals, the internal
nodes of `*`, `+` and groups, error recovery nodes, and rules numbered with
`${action}`. `make_dparser -H 1` writes constants for the rules into the
generated header: `D_RULE_<production>_<n>` is the *n*-th rule (from 0) of
the production. Rules of a production with the same length and no code,
priorities or passes are built as one reduction, so they share the number
of the first of them; the children's symbols tell them apart.

```c
expr: expr '+' expr $left 10    /* D_RULE_expr_0 */
    | name                      /* D_RULE_expr_1 */
    | number ;                  /* D_RULE_expr_2, equal to D_RULE_expr_1 */
```

## C: `dattr.h`

```c
#include "dattr.h"

typedef enum { D_ATTR_SYN, D_ATTR_INH } D_AttrKind;

typedef struct D_Attr D_Attr;
struct D_Attr {
  const char *name;
  D_AttrKind kind;
  int (*eval)(D_AttrTree *t, D_Attr *a, D_AttrNode *node, int child_index, void *out);
  int size;                              /* bytes of value storage */
  void (*free)(D_Attr *a, void *value);  /* optional */
  void *data;                            /* yours */
};
```

**Equations.** `eval` writes the value to `out` (`size` bytes, zeroed) and
returns nonzero, or returns 0 if it has no equation for this case:

- synthesized: `eval(t, a, node, -1, out)` computes the value at `node`;
  with no equation, the value is undefined;
- inherited: `eval(t, a, parent, i, out)` computes the value `parent`
  gives its child `i`; with no equation, the child gets `parent`'s value.
  At the root, `eval(t, a, root, -1, out)` computes the root's own value.

Values are stored by the library and live until the tree is freed, when
`free`, if set, is called with each value's storage. Values must not need
more than 16-byte alignment.

| Function | Description |
|---|---|
| `D_AttrTree *d_attr_tree(D_Parser *p, D_ParseNode *root, D_Attr **attrs, int n, void *ctx)` | An attribute tree over the saved tree under `root`, for the attributes `attrs`. NULL if there is no saved tree. |
| `void d_attr_tree_free(D_AttrTree *t)` | Free the tree and its values. |
| `void *d_attr_get(D_AttrTree *t, D_AttrNode *n, D_Attr *a)` | The value of `a` at `n`, or NULL if it is undefined or part of a cycle. |
| `void *d_attr_ctx(D_AttrTree *t)` | The `ctx` given to `d_attr_tree`. |
| `D_Parser *d_attr_parser(D_AttrTree *t)` | The parser. |
| `int d_attr_cycles(D_AttrTree *t)` | The number of cycles found. |
| `void d_attr_set_cycle_fn(D_AttrTree *t, D_AttrCycleFn fn)` | Replace the cycle report (stderr by default). |
| `D_AttrNode *d_attr_root(D_AttrTree *t)` | The root. |
| `D_AttrNode *d_attr_parent(D_AttrNode *n)` | The parent, or NULL. |
| `int d_attr_index(D_AttrNode *n)` | The index of `n` in its parent; -1 for the root. |
| `int d_attr_n_children(D_AttrNode *n)`, `D_AttrNode *d_attr_child(D_AttrNode *n, int i)` | The children, as `d_get_child` sees them. |
| `D_ParseNode *d_attr_parse_node(D_AttrNode *n)` | The parse node: text, location and user data. |
| `int d_attr_symbol(D_AttrNode *n)`, `const char *d_attr_symbol_name(D_AttrTree *t, D_AttrNode *n)` | The symbol and its name. |
| `int d_attr_production(D_AttrNode *n)` | `d_get_production` of the parse node. |

```c
typedef void (*D_AttrCycleFn)(D_AttrTree *t, int n, D_AttrNode **nodes, D_Attr **attrs);
```

A cycle function receives the chain of requests on the cycle, from the
first request for the attribute that depends on itself to the request
that closed the cycle. The request that closed it returns NULL, and the
requests waiting on it continue with that NULL.

## C++: `dattr.hpp`

```cpp
#include "dattr.hpp"

dparser::Attr<Env> env = dparser::inh<Env>("env",
    [&](dparser::AttrNode n, int child) -> std::optional<Env> {
        if (child < 0) return Env{};                        // the root
        if (n.symbol_name() != "block") return std::nullopt;  // copy down
        Env e = *env(n);
        /* add the block's declarations */
        return e;
    });

dparser::Attr<std::string> type = dparser::syn<std::string>("type",
    [&](dparser::AttrNode n, int) -> std::optional<std::string> {
        if (n.symbol_name() == "number") return "int";
        if (n.production() == D_RULE_expr_0) return /* ... */;
        return std::nullopt;                                  // undefined
    });

dparser::AttrTree attrs(parser, tree, env, type);
const std::string *t = type(attrs.root().child(0));
```

An equation returns `std::nullopt` for "no equation". `attr(node)` (or
`attr.get(node)`) returns a `const T *`, or `nullptr`. Values are
constructed in place and destroyed with the tree. Declare an attribute
with its type, not `auto`, when its equation refers to itself.

`dparser::AttrNode` has `parent()`, `index()`, `num_children()`,
`child(i)`, `node()` (a `dparser::ParseNode`), `text()`, `symbol()`,
`symbol_name()` and `production()`. `AttrTree` has `root()`, `cycles()`
and `set_cycle_fn()`; the attributes and the parse tree must outlive it.

## Python: `dparser_attrs`

Keep the tree with `parse(..., keep_tree=True)`; `getTree()` then returns
its root, a `dparser.Node` (see [Python](python.md#node)).

```python
from dparser_attrs import AttrTree, NO_EQUATION, inh, syn

@inh
def env(node, child):
    if child < 0:
        return {}                    # the root
    if node.name != 'block':
        return NO_EQUATION           # copy down
    return {**env(node), **declarations(node)}

@syn
def type_(node):
    if node.name == 'number':
        return 'int'
    if node.name == 'name':
        return env(node).get(node.text, 'undeclared')
    ...
    return NO_EQUATION               # undefined: None

tree = AttrTree(parser.parse(text, keep_tree=True).getTree())
print(type_(tree.root.children[0]))
```

- `@syn` and `@inh` make an `Attribute` named after the function.
  Calling an attribute on an `AttrNode` gives its value.
- An `AttrNode` has `parent`, `index`, `children` and `node` (the
  underlying node), and passes other attributes through to `node`
  (`name`, `text`, `action`, ...).
- `AttrTree(root, children=None)` works on any tree: by default children
  are `node.children`; pass `children=f` for other shapes.
  `tree.nodes()` yields every `AttrNode`, parents first.
- A cycle raises `AttributeCycle`, whose `chain` lists the (attribute
  name, node) requests on it.

## Rust: `dparser::attrs`

```rust
use dparser::attrs::{Attr, AttrTree, NodeId};

type Tree<'t, 'a> = AttrTree<'t, 'a, NodeStruct>;

fn env_eq(t: &Tree, n: NodeId, child: i32) -> Option<Env> {
    if child < 0 { return Some(Env::default()); }
    if t.name(n) != "block" { return None; }          // copy down
    let mut e = (*t.get(n, &ENV)?).clone();
    /* add the block's declarations */
    Some(Rc::new(e))
}
const ENV: Attr<Env, NodeStruct> = Attr::inh("env", env_eq);

fn type_eq(t: &Tree, n: NodeId, _: i32) -> Option<String> {
    match t.name(n) {
        "number" => Some("int".into()),
        "expr" if t.production(n) == D_RULE_expr_0 => { /* ... */ }
        _ => None,                                     // undefined
    }
}
const TYPE: Attr<String, NodeStruct> = Attr::syn("type", type_eq);

let root = parser.parse(input, Some(&mut globals)).unwrap();
let tree = AttrTree::new(&parser, &root);
let t: Option<String> = tree.get(tree.child(tree.root(), 0), &TYPE);
```

- Attributes are `const` values with `fn` equations, identified by name.
- `get` returns a clone of the value; use `Rc` for large values.
- `AttrTree` has `root`, `parent`, `index`, `children`, `child`, `node`
  (the `ParseNode`), `text`, `name`, `production` and `nodes`, all on
  `NodeId`s. `AttrTree::without_names(&root)` needs no parser, but then
  `name` is empty.
- A cycle makes the request that closed it return `None`, and is recorded
  in `cycles()`.
- `build_actions` generates the `D_RULE_<production>_<n>` constants, and
  `ParseNode::production()` gives a node's rule.

## Not supported

Attributes are evaluated only on the final tree, not on the alternatives
an `ambiguity_fn` chooses between, and attributes that depend on
themselves are always errors, never iterated to a fixed point. Both are
possible future work.
