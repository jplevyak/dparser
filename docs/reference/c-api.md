# C API

The runtime API is declared in `dparse.h`, which also includes
`dparse_tables.h` and `dsymtab.h`. Link with `-ldparse`.

## Customizing node and global types

Define these macros **before** including `dparse.h`, both in the grammar's
global code and in your driver:

| Macro | Default | Purpose |
|---|---|---|
| `D_ParseNode_User` | `void *` | Your data in every parse node (`$$`, `$0`, ...). |
| `D_ParseNode_Globals` | `void` | The type `initial_globals` points to (`$g`). |
| `D_UserSym` | `unsigned int` | Your data in every symbol table entry. |

Pass `sizeof(D_ParseNode_User)` to `new_D_Parser`.

## Parsing

```c
D_Parser *new_D_Parser(D_ParserTables *tables, int sizeof_ParseNode_User);
D_ParseNode *dparse(D_Parser *p, char *buf, int buf_len);
void free_D_ParseNode(D_Parser *p, D_ParseNode *pn);
void free_D_Parser(D_Parser *p);
```

`make_dparser` names the tables `parser_tables_gram`; the suffix can be
changed with `make_dparser -i name` or `-I`. Declare them in your driver:

```c
extern D_ParserTables parser_tables_gram;
```

`dparse` parses `buf_len` bytes of `buf`:

- On failure it returns `NULL`.
- On success with `save_parse_tree` set, it returns the root node, which
  you free with `free_D_ParseNode`.
- On success without `save_parse_tree`, it returns the placeholder
  `NO_DPN`. `free_D_ParseNode` accepts it and does nothing.

With error recovery on (the default), a parse with syntax errors can still
succeed. **Check `p->syntax_errors`** to see whether the input was valid.

The buffer does not need to be NUL-terminated: DParser never reads past
`buf_len`. Your own [external scanners](terminals.md#external-scanners)
and whitespace functions are only given the current position, so if you
write any, either NUL-terminate the buffer or make sure they don't read
past its end. A NUL byte inside the input is treated as an ordinary
character that no terminal matches.

The buffer must stay valid as long as you use the parse tree or symbol
table, because nodes and symbols point into it. A parser can be reused for
several `dparse` calls; each call frees the previous tree's working data.

A typical driver:

```c
D_Parser *p = new_D_Parser(&parser_tables_gram, sizeof(MyNode));
p->save_parse_tree = 1;
p->loc.pathname = "input.txt";
D_ParseNode *root = dparse(p, buf, len);
if (root && !p->syntax_errors) {
  /* use root */
}
if (root) free_D_ParseNode(p, root);
free_D_Parser(p);
```

## `D_Parser`

The parser object. Set the fields you need after `new_D_Parser` and before
`dparse`.

### Callbacks and initial state

| Field | Default | Description |
|---|---|---|
| `D_ParseNode_Globals *initial_globals` | `NULL` | Global state passed to actions as `$g`. |
| `D_WhiteSpaceFn initial_white_space_fn` | built-in | Skips whitespace. See [Whitespace](declarations.md#whitespace). |
| `D_Scope *initial_scope` | `NULL` | A symbol table to start with. If `NULL`, a fresh top-level scope is created for each parse. |
| `D_SyntaxErrorFn syntax_error_fn` | prints a message | Called on each syntax error, with the location in `loc`. |
| `D_AmbiguityFn ambiguity_fn` | aborts | Chooses between unresolved ambiguous parses. See [Disambiguation](disambiguation.md#writing-an-ambiguity-function). |
| `D_FreeNodeFn free_node_fn` | `NULL` | Called with each parse node as it is freed, so you can free resources in your node data. |
| `d_loc_t loc` | line 1 | The starting location. Set `loc.pathname` to name the input in error messages. After an error, the error location. |
| `int start_state` | `0` | The state to start parsing in. `0` is the start symbol; see [Start states](grammar.md#start-states). |
| `D_StateFns *state_fns` | `NULL` | How to hash, compare, free and prefer [threaded states](threaded-state.md#setting-it-up-in-c). With `NULL`, states are compared by pointer. |
| `void *initial_state` | `NULL` | The threaded state at the start of the parse. With `state_fns`, the parser takes ownership of it. |

### Options

| Field | Default | Description |
|---|---|---|
| `int save_parse_tree` | `0`[^spt] | Keep the parse tree and return it from `dparse`. |
| `int error_recovery` | `1` | Recover from syntax errors and continue. See [Error Recovery](../internals/error-recovery.md). |
| `int partial_parses` | `0` | Accept a parse of a prefix of the input. The parse stops at the longest prefix that parses; the root's `end` shows where. |
| `int commit_actions_interval` | `100` | How eagerly to run final actions during the parse. `0` commits as soon as possible; a very large value delays all final actions to the end. |
| `int dont_fixup_internal_productions` | `0` | Don't flatten the internal nodes created for `*` and `+` into one node per list. |
| `int fixup_EBNF_productions` | `0` | Also splice the nodes created for EBNF operators into their parents. |
| `int dont_merge_epsilon_trees` | `0` | Don't silently merge ambiguous empty subtrees that have no actions. |
| `int dont_use_height_for_disambiguation` | `0` | See [Disambiguation](disambiguation.md#options). |
| `int dont_use_greediness_for_disambiguation` | `0` | See [Disambiguation](disambiguation.md#options). |
| `int dont_use_deep_priorities_for_disambiguation` | `0` | See [Disambiguation](disambiguation.md#options). |
| `int dont_compare_stacks` | `0` | See [Disambiguation](disambiguation.md#options). |
| `int sizeof_user_parse_node` | from `new_D_Parser` | The size of `D_ParseNode_User`. |

[^spt]: Defaults to `1` if the grammar has `${declare save_parse_tree}`.

### Results

| Field | Description |
|---|---|
| `int syntax_errors` | The number of syntax errors found. With error recovery, errors on the same line are counted once. |

## `D_ParseNode`

The system part of every parse node, `$n` and `$nN` in actions:

```c
typedef struct D_ParseNode {
  int symbol;               /* index into tables->symbols */
  d_loc_t start_loc;        /* where the node's text starts */
  char *end;                /* just after the node's text */
  char *end_skip;           /* just after any whitespace following the text */
  struct D_Scope *scope;    /* the symbol table scope after this node */
  D_ParseNode_User user;    /* your data */
} D_ParseNode;
```

The text of a node is `start_loc.s` up to (not including) `end`.

## `d_loc_t`

```c
typedef struct d_loc_t {
  char *s;          /* position in the buffer */
  char *pathname;   /* file name for messages */
  char *ws;         /* start of whitespace before s */
  int col, line;    /* column (from 0) and line (from 1) */
} d_loc_t;
```

## Tree functions

| Function | Description |
|---|---|
| `int d_get_number_of_children(D_ParseNode *pn)` | The number of children. |
| `D_ParseNode *d_get_child(D_ParseNode *pn, int i)` | Child `i`, from 0. |
| `D_ParseNode *d_find_in_tree(D_ParseNode *pn, int symbol)` | The first node with the given symbol, searching depth first. |
| `char *d_ws_before(D_Parser *p, D_ParseNode *pn)` | The start of the whitespace before the node. |
| `char *d_ws_after(D_Parser *p, D_ParseNode *pn)` | The end of the whitespace after the node. |
| `void d_pass(D_Parser *p, D_ParseNode *pn, int pass)` | Run a [pass](actions.md#pass-actions) over a subtree. |
| `void free_D_ParseTreeBelow(D_Parser *p, D_ParseNode *pn)` | Free the subtree below a node. |
| `int d_get_production(D_ParseNode *pn)` | The rule that built a node, one of the `D_RULE_` constants written by `make_dparser -H 1`, or -1. See [Attributes](attributes.md#which-rule-built-a-node). |
| `void *d_get_state(D_ParseNode *pn)` | The [threaded state](threaded-state.md) after a node. |
| `void *d_get_state_before(D_ParseNode *pn)` | The threaded state before a node. |
| `void *d_get_whitespace_state(D_Parser *p)` | In a whitespace function, the current threaded state. |
| `void *d_intern_state(D_Parser *p, void *state)` | The canonical pointer for a threaded state, which the parser then owns. |

Symbol names and kinds are in the tables:

```c
const char *name = parser_tables_gram.symbols[pn->symbol].name;
```

`dparse_tree.h` adds `print_parsetree()` for printing a tree; see
[Parse Trees](../tutorial/parse-trees.md#a-ready-made-printer).

## Callback types

```c
typedef void (*D_SyntaxErrorFn)(struct D_Parser *p);
typedef struct D_ParseNode *(*D_AmbiguityFn)(struct D_Parser *p, int n,
                                             struct D_ParseNode **v);
typedef void (*D_FreeNodeFn)(struct D_ParseNode *pn);
typedef void (*D_WhiteSpaceFn)(struct D_Parser *p, d_loc_t *loc,
                               void **p_globals);

typedef struct D_StateFns {
  unsigned (*hash)(void *state);
  int (*equal)(void *a, void *b);   /* nonzero if equal */
  void (*free)(void *state);        /* optional */
  int (*prefer)(void *a, void *b);  /* optional: >0 prefer a, <0 prefer b */
} D_StateFns;
```

## Debugging output

The library has two global variables you can declare and set:

```c
extern int d_verbose_level;  /* > 0: print ambiguous alternatives before aborting */
extern int d_debug_level;    /* > 1: trace the parser (needs a D_DEBUG=1 build) */
```

## Binary tables

Instead of C, `make_dparser -B` writes the tables to a binary file that
can be loaded at run time, so a program can load grammars it wasn't
compiled with. Actions can't be stored in a binary file, so a binary
grammar's actions are dispatched to two callbacks you supply (or `NULL` for
none). `read_binary.h` declares:

```c
BinaryTables *read_binary_tables(char *file_name,
                                 D_ReductionCode spec_code,
                                 D_ReductionCode final_code);
BinaryTables *read_binary_tables_from_file(FILE *fp, ...);
BinaryTables *read_binary_tables_from_string(unsigned char *buf, size_t len, ...);
void free_BinaryTables(BinaryTables *tables);
```

```c
BinaryTables *bt = read_binary_tables("my.g.d_parser.dat", NULL, NULL);
D_Parser *p = new_D_Parser(bt->parser_tables_gram, 0);
...
free_D_Parser(p);
free_BinaryTables(bt);
```

The Python and Rust bindings use binary tables. See
[Binary Tables](../internals/binary-tables.md).
