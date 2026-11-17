# Threaded State

Threaded state is a value that flows through the parse from left to right,
like the [symbol table](symbol-table.md), and that speculative actions can
read and replace. Each parse path has its own state. Paths whose states
differ are never merged, so a speculative action can safely decide whether
a parse is valid based on the state.

Use it for small facts about the context that change as parsing proceeds
and that affect which parses are accepted:

- **lexical modes**: inside brackets, a template, string interpolation or
  `#if 0`;
- **context flags**: inside a loop (where `break` is legal) or an `async`
  function, or the active language version;
- **counters and stacks**: nesting depth, or an indentation stack.

Threaded state is available in C, C++, Python and Rust.

## Which kind of state?

| Kind | Example | Where it belongs |
|---|---|---|
| Configuration and shared services, the same on every path | Options, a file name, a string interner, an error list filled by final actions | `$g`, the [globals](actions.md#node-data). Speculative actions only read it. |
| A symbol table | Declared types and variables | `${scope}`, the [symbol table](symbol-table.md). |
| Other context that depends on the parse path | Loop depth, bracket depth, indentation | `${state}`. |
| Data about one node | A value, a type | `$$`, the node's own data. |

The rule of thumb: if a parse path that fails should not have changed it,
it belongs in `${state}` or `${scope}`; otherwise in `$g`.

`$g` is shared by every path. A speculative action can run for a path
that is later abandoned, and nothing undoes what it wrote, which is why
`$g` is read-only in speculative actions (see
[mutable speculative globals](declarations.md#mutable-speculative-globals)).

## In actions

| Specifier | Meaning |
|---|---|
| `${state}` | In a speculative action, the current state, which you can assign to change the state seen by everything to the right on this path. In a final action or pass, the state after this node, read-only. |
| `${state N}` | The state before element *N*, read-only. |

States are **immutable**. To change the state, build a new value and
assign it:

```c
{
#include <stdlib.h>
static int depth(void *s) { return s ? *(int *)s : 0; }
static void *with_depth(int d) { int *s = malloc(sizeof(int)); *s = d; return s; }
}

stmt: 'while' '(' expr ')' enter stmt leave
    | 'break' ';' [ if (depth(${state}) == 0) ${reject}; ]
    | expr ';' ;
enter: [ ${state} = with_depth(depth(${state}) + 1); ] ;
leave: [ ${state} = with_depth(depth(${state}) - 1); ] ;
```

`enter` and `leave` are empty rules whose actions change the state before
and after the loop body. A `break` outside a loop is rejected; if the
input is ambiguous, it is rejected only on the paths where it is outside
a loop.

A speculative action sees the state after the rule's last element. A
terminal's action (`[ ]` on a [regex production](terminals.md), such as
`LP ::= '(' [ ... ];`) runs when the terminal is shifted, so even the
whitespace after the terminal sees its change.

!!! warning "Don't change a state value in place"
    Equal states are recognized by pointer once they are interned, and the
    same value may be shared by many paths. Always assign a new value.

## Setting it up in C

Give the parser functions to hash and compare states, so that equal
states can be recognized:

```c
static unsigned ctx_hash(void *s) { return *(int *)s * 2654435761u; }
static int ctx_equal(void *a, void *b) { return *(int *)a == *(int *)b; }
static void ctx_free(void *s) { free(s); }

static D_StateFns ctx_fns = {ctx_hash, ctx_equal, ctx_free, NULL};

D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
p->state_fns = &ctx_fns;
p->initial_state = NULL;   /* the state at the start; NULL here means depth 0 */
```

```c
typedef struct D_StateFns {
  unsigned (*hash)(void *state);
  int (*equal)(void *a, void *b);  /* nonzero if equal */
  void (*free)(void *state);       /* optional */
  int (*prefer)(void *a, void *b); /* optional: >0 prefer a, <0 prefer b, 0 neither */
} D_StateFns;
```

**Interning and ownership.** The parser *interns* states: whenever an
action assigns `${state}`, it looks the value up and, if an equal one is
already known, uses that one and frees the new one with `free`. So every
value you assign to `${state}` (and `initial_state`) becomes the parser's,
and all of them are freed by `free_D_Parser`. If an action needs to keep a
pointer to a value, call `d_intern_state(parser, value)` first and keep
the pointer it returns.

**Without `state_fns`.** If `state_fns` is `NULL`, states are compared by
pointer and are never interned or freed. This suits grammars whose states
are a few static values, or that intern states themselves, like
[`python.g`](#example-python-indentation) below. Such grammars work with
any driver.

`NULL` is always a valid state, and is the initial state unless you set
`initial_state`.

### Functions

| Function | Description |
|---|---|
| `void *d_intern_state(D_Parser *p, void *state)` | The canonical pointer for `state`, which the parser then owns. |
| `void *d_get_state(D_ParseNode *pn)` | The state after a node. |
| `void *d_get_state_before(D_ParseNode *pn)` | The state before a node. |
| `void *d_get_whitespace_state(D_Parser *p)` | In a whitespace function, the current state. |

## Choosing between final states

Two parses of the whole input can end with different states. Neither
was merged into the other during the parse, because their states
differed, so they reach the end as an ambiguity and go to the
[ambiguity function](disambiguation.md#writing-an-ambiguity-function).

Often the final state is what decides. For example, a grammar that
accepts two dialects can record in the state which one a path has
committed to; `print(x)` parses both ways, and you want to prefer the
newer dialect when both work. Set `state_fns->prefer`: it returns a
positive value to prefer `a`, negative to prefer `b`, and 0 for no
preference. Candidates whose state is less preferred than another's are
dropped before the ambiguity function is called; if only one remains, it
is not called at all.

Within the parse, derivations of the same text whose states differ are
still compared by [priorities, greediness and height](disambiguation.md);
only when those rules tie are both kept.

## Whitespace

Whitespace can **read** the state but not change it. A whitespace
function calls `d_get_whitespace_state(p)`; a `whitespace` production's
actions see it as `${state}` (assigning it there has no effect). The
state seen is the one after the preceding token, including any change made
by that token's own action, but before any reduction that ends at the
token, because whitespace is skipped when the token is shifted.

Text that should change the mode, such as a pragma, belongs in the
grammar as a token or rule whose action sets `${state}`; whitespace then
reads it.

## Example: Python indentation

`python.g` in the source tree keeps the depth of open brackets and the
stack of indentation columns in the state:

```c
LP ::= '(' [ ${state} = (void *)py_with(${state}, 1); ];
RP ::= ')' [ ${state} = (void *)py_with(${state}, -1); ];

INDENT: [ if (!py_indent(${parser}, ${state}, $n.start_loc.s, &${state})) ${reject}; ] ;
DEDENT: [ if (!py_dedent(${parser}, ${state}, $n.start_loc.s, &${state})) ${reject}; ] ;
LINE:   [ if (!py_line(${parser}, ${state}, $n.start_loc.s)) ${reject}; ] ;

stmt: LINE (simple_stmt | compound_stmt);
suite: simple_stmt | NL INDENT stmt+ DEDENT;
```

- The whitespace function treats newlines as whitespace when the bracket
  depth is above zero (implicit line joining).
- `INDENT` pushes the column of the next line if it is deeper; `DEDENT`
  pops a level if the column is shallower and matches an enclosing level;
  `LINE` checks that each statement starts at the current indentation.
- `match` and `case` are soft keywords: both the keyword and the name are
  tried, so `match (a,` *newline* `b)` keeps a statement path and an
  expression path alive across the brackets, each with its own state.

## Cost

Every distinct state keeps parse paths apart, so a state that takes many
values or changes on every token can make parsing much slower. Prefer
states that change rarely and take few values. With `-v`, the parser
reports how many distinct states were interned.

## Other languages

- **C++**: `Parser::set_state<T>()` with any type that `std::hash` and
  `==` support. See [C++](cpp.md#threaded-state).
- **Python**: any hashable object, through a `state` action argument. See
  [Python](python.md#threaded-state).
- **Rust**: `StateId` handles to values of any `Eq + Hash` type. See
  [Rust](rust.md#threaded-state).
