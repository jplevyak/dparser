# Actions

Actions are C code attached to grammar rules. `make_dparser` compiles each
action into a function in the generated file, after translating the `$`
specifiers described below.

## Kinds of action

```c
rule: elements
  [ speculative action ]
  { final action }
  passname: { pass action }
  ;
```

### Final actions `{ }`

Final actions run once the parser has committed to a rule as part of the
single final parse. They run in order, once per occurrence in that parse,
bottom up: a node's children have run their final actions before the node
does.

By default final actions run in batches as the parse proceeds, whenever
the parse has been unambiguous for a while. The `commit_actions_interval`
parser option controls this; see [Actions and Commit](../internals/actions.md).

### Speculative actions `[ ]`

Speculative actions run when the parser reduces a rule, while it is still
exploring alternatives. They may run for parses that are later abandoned,
and a different number of times than the rule appears in the final parse.

A speculative action can:

- set values in `$$`, which stay with the node and are visible to later
  actions, speculative and final;
- read and update the symbol table through `${scope}`;
- read, but not write, the globals through `$g`;
- reject the current parse path with `${reject}`.

Avoid other side effects. See
[Speculative Actions](../tutorial/speculative-actions.md).

### Embedded actions

Actions can also appear in the middle of a rule:

```c
S: A { printf("X"); } B ;
```

An embedded action behaves as if it were replaced by a new nonterminal
with one empty rule carrying the action. Given `A` and `B` that print `a`
and `b`, the input `ab` prints `aXb`. Embedded actions can be speculative
(`[ ]`) or final (`{ }`).

An action at the end of a group belongs to the group, not to a new empty
rule:

```c
S: A ( A B { printf("X"); } ) B ;   // runs in the context of the "A B" group
```

### Pass actions

Pass actions run when you walk the finished tree with `d_pass()`. Declare
the passes at the top of the grammar, and label actions with the pass
name:

```c
${pass sym for_all postorder}
${pass gen for_all postorder}

translation_unit: statement* ;

statement: expression ';' {
    d_pass(${parser}, &$n, ${pass sym});
    d_pass(${parser}, &$n, ${pass gen});
  } ;

expression
  : integer
      gen: { printf("gen integer\n"); }
      sym: { printf("sym integer\n"); }
  | expression '+' expression $left 2
      sym: { printf("sym +\n"); }
  ;
```

The options in `${pass name ...}` are:

| Option | Meaning |
|---|---|
| `preorder` | Visit a node before its children. |
| `postorder` | Visit a node after its children. |
| `manual` | Don't traverse automatically; call `d_pass` on children yourself. |
| `for_all` | Traverse all nodes. |
| `for_undefined` | Only apply automatic traversal to rules without an action for this pass. |

A pass can be started from the final action of any rule, as above, or
from your driver on a saved tree.

### Default actions

The special production `_` holds default actions. Its single rule's
speculative, final and pass actions are used for any rule that doesn't
define its own action of that kind:

```c
_: [ /* default speculative */ ]
   { /* default final */ }
   gen: { /* default for pass gen */ }
   sym: { /* default for pass sym */ }
  ;
```

## Specifiers

These are replaced in action code. Element numbers count from 0 and
include every element of the rule: terminals, nonterminals, groups and
embedded actions.

### Node data

| Specifier | Type | Meaning |
|---|---|---|
| `$$` | `D_ParseNode_User` | Your data for the node being built. |
| `$0`, `$1`, ... | `D_ParseNode_User` | Your data for element *N*. |
| `$n` | `D_ParseNode` | The system data for the node being built. |
| `$n0`, `$n1`, ... | `D_ParseNode` | The system data for element *N*. |
| `$#` | `int` | The number of elements of the rule. |
| `$#0`, `$#1`, ... | `int` | The number of children of element *N*; for `x*`, the number of repetitions. |
| `${child 0, 2, 1}` | `D_ParseNode *` | A path into the tree: child 1 of child 2 of element 0. |
| `$g` | `D_ParseNode_Globals *` | The parser's global state, `initial_globals`. In speculative actions it is `const D_ParseNode_Globals *` unless the grammar has [`${declare mutable_speculative_globals}`](declarations.md#mutable-speculative-globals). |
| `$c0`, `$c` | `dparser::ParseNode` | C++ wrappers around element *N* or the node being built. See [C++](cpp.md). |

Your node type is `D_ParseNode_User`, defined with `#define` before
`dparse.h` is included. The system data, `D_ParseNode`, includes the
symbol, start location, end of the text, and scope; see
[C API](c-api.md#d_parsenode).

The global state type is `D_ParseNode_Globals`, also set with `#define`,
and the pointer is whatever you assign to `parser->initial_globals` before
parsing. It is shared by all parse paths, so don't change it in
speculative actions.

### Control and context

| Specifier | Meaning |
|---|---|
| `${scope}` | The current symbol table scope (`D_Scope *`) for this node. Assign to it to change the scope seen by later parts of the parse. See [Symbol Table](symbol-table.md). |
| `${reject}` | In a speculative action, reject this parse path. (It expands to `return -1`.) |
| `${parser}` | The `D_Parser *` running the parse. |
| `${free_below}` | Free the parse tree below this node, to save memory when you no longer need it. |

### Symbol numbers

| Specifier | Meaning |
|---|---|
| `${nterm name}` | The symbol number of nonterminal `name`. |
| `${string text}` | The symbol number of the string terminal `'text'`, or of the terminal named `text` with `$name`. |
| `${pass name}` | The number of pass `name`, for `d_pass()`. |

Compare symbol numbers with `$nN.symbol`:

```c
if ($n0.symbol == ${nterm declaration}) ...
```

These three may also be used in [global code](grammar.md#global-code).

## The generated function

Each action becomes a function. Speculative actions return 0 to accept
the reduction or nonzero (which is what `${reject}` does) to reject it.
The return value of final actions is ignored. A `return` statement in
your code returns from the action.

`$` signs inside C string and character literals are not translated, so
`printf("$5")` is safe. Avoid `$` in comments inside actions.
