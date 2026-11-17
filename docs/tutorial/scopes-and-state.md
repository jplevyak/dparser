# 6. Scopes and State

In the [last chapter](speculative-actions.md), the symbol table remembered
which names were types, and a speculative action used it to reject a
parse. Each parse path saw its own symbol table, so a `typedef` on one
path didn't leak into the others.

This chapter goes further with the same idea. First the symbol table
again, with nested scopes and data stored in each symbol. Then
**threaded state**, which carries any other context along a parse path
the same way, such as how many loops you are inside.

## Variables and blocks

A small language with declarations (`x: 1;`), assignments (`x = 2;`),
expression statements, which print their value, and blocks, which open a
new scope.

Each symbol stores the variable's value, and each parse node stores the
value of an expression. Both types go in a header that the grammar and
the driver include, `scopes.h`:

```c
/* Your data in each symbol, and in each parse node.  Included before
   dparse.h, by the grammar and by the driver. */
typedef struct { int value; } Var;
#define D_UserSym Var
typedef struct { int value; } Value;
#define D_ParseNode_User Value
```

`scopes.g`:

```c
{
#include <stdio.h>
#include <stdlib.h>
#include "scopes.h"
}

program: statement* ;

statement
  : identifier ':' expression ';'
      [ D_Sym *s = SPECULATIVE_NEW_D_SYM(&${scope}, $n0.start_loc.s, $n0.end);
        s->user.value = $2.value; ]
  | identifier '=' expression ';'
      [ D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
        if (!s) ${reject};
        s = UPDATE_D_SYM(s, &${scope});
        s->user.value = $2.value; ]
  | expression ';'
      { printf("%d\n", $0.value); }
  | '{' new_scope statement* '}'
      [ ${scope} = enter_D_Scope(${scope}, $n0.scope); ]
  ;

new_scope: [ ${scope} = new_D_Scope(${scope}); ] ;

expression
  : expression '+' expression $left 10
      [ $$.value = $0.value + $2.value; ]
  | integer
      [ $$.value = atoi($n0.start_loc.s); ]
  | identifier
      [ D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
        if (!s) ${reject};
        $$.value = s->user.value; ]
  ;

integer: "[0-9]+" ;
identifier: "[a-z]+" $term -1 ;
```

`main.c`:

```c
#include <stdio.h>
#include <string.h>
#include "scopes.h"
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

int main(int argc, char *argv[]) {
  D_Parser *p = new_D_Parser(&parser_tables_gram, sizeof(Value));
  p->loc.pathname = "input";
  D_ParseNode *pn = dparse(p, argv[1], strlen(argv[1]));
  int errors = p->syntax_errors;
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return errors != 0;
}
```

```bash
make_dparser scopes.g
cc -o scopes main.c scopes.g.d_parser.c -ldparse
```

```console
$ ./scopes 'x: 1;
y: 2;
{
  x: 10;      // a new x, only in this block
  x + y;
  y = x + y;  // changes the outer y
}
x;
y;'
12
1
12
$ ./scopes 'x: 1; { z: 2; } z;'
input:1: syntax error after 'z'
```

How it works:

- **Data in symbols.** `D_UserSym` is the type of `sym->user`, here a
  `Var` holding the value. `D_ParseNode_User` is the type of `$$` and
  `$0`, `$1`, ..., here a `Value`, which is why the driver passes
  `sizeof(Value)` to `new_D_Parser`.
- **Declarations** add a symbol with `SPECULATIVE_NEW_D_SYM(&${scope}, ...)`,
  in a new version of the scope that only this parse path sees, and store
  the value in it.
- **Assignments** find the symbol and change it with
  `UPDATE_D_SYM(s, &${scope})`, which makes a new version of the symbol
  for this path. Don't write to a symbol you found without it: other paths
  may share it.
- **Undeclared names** are rejected: `find_D_Sym` returns NULL, and
  `${reject}` drops the parse. With no other way to read `z`, that's a
  syntax error.
- **Blocks.** `new_scope` is an empty rule whose action opens a scope
  inside the current one. At the `}`, the block rule returns to the scope
  it started in, `$n0.scope`, the scope after the `{`. It does so with
  `enter_D_Scope`, not by assigning `$n0.scope` back: `enter_D_Scope`
  keeps the updates made inside the block to outer symbols, which is why
  `y` is 12 afterwards while the inner `x` is gone.

## Context that isn't a name

Not all context is a set of names. In many languages `break` is legal only
inside a loop. Counting loops in a global variable (`$g`) would be wrong:
a speculative action that counted a loop on a path the parser later
abandons would leave the count off for every other path. That is why `$g`
is read-only in speculative actions.

**Threaded state**, `${state}`, is a value of your own that flows from
left to right along each parse path, as the scope does. A speculative
action can read it and assign a new value, which everything to its right
on the same path then sees. Paths with different states are kept apart.

`loops.g`:

```c
{
#include <stdio.h>

/* The state is the loop depth: NULL for 0, else a pointer to one of these,
   so that equal depths are equal pointers. */
static int depths[100];
static int depth(void *state) { return state ? *(int *)state : 0; }
static void *with_depth(int d) {
  if (d <= 0) return NULL;
  depths[d] = d;
  return &depths[d];
}
}

program: stmt* ;

stmt
  : 'while' '(' name ')' enter stmt leave
  | '{' stmt* '}'
  | 'break' ';'
      [ if (depth(${state}) == 0) ${reject}; ]
      { printf("break out of %d loop%s\n", depth(${state}), depth(${state}) > 1 ? "s" : ""); }
  | name ';'
  ;

enter: [ ${state} = with_depth(depth(${state}) + 1); ] ;
leave: [ ${state} = with_depth(depth(${state}) - 1); ] ;

name: "[a-z]+" $term -1 ;
```

The driver is `main.c` without `#include "scopes.h"`, and with 0 for the
node size, since this grammar has no node data.

```bash
make_dparser loops.g
cc -o loops main.c loops.g.d_parser.c -ldparse
```

```console
$ ./loops 'while (a) { x; break; }
while (a) while (b) break;
while (a) { while (b) x; break; }
x;'
break out of 1 loop
break out of 2 loops
break out of 1 loop
$ ./loops 'x; break;'
input:1: syntax error after ';'
```

How it works:

- **The state is a `void *`.** Here it stands for a loop depth: `NULL` is
  depth 0, and other depths are pointers into a table, so that two paths
  at the same depth have the same pointer. The parser compares states by
  pointer.
- **`enter` and `leave`** are empty rules around the loop body, whose
  actions assign the next and previous depth to `${state}`.
- **`break`** is rejected at depth 0. Its final action reads `${state}`,
  which in a final action is the state after the node, to report the
  depth.
- **States are never changed in place.** Assign a new value instead.

For states you allocate, such as a struct with several fields, give the
parser functions to hash, compare and free them in `parser->state_fns`.
It then recognizes equal states, and frees them when the parser is freed.
See [Threaded State](../reference/threaded-state.md), which also covers
choosing between parses that end in different states, and whitespace that
depends on the state.

## Which to use

| To keep | Use |
|---|---|
| Names and what they mean: variables, types, functions | The symbol table, `${scope}` |
| Other context that depends on the parse path: loop depth, a lexical mode, an indentation stack | Threaded state, `${state}` |
| A value for one node, computed from its children | The node's data, `$$` |
| Configuration, and results that are the same on every path, such as an error count updated by final actions | The globals, `$g` |

## What you learned

- Symbols can carry your data (`D_UserSym`). Use `SPECULATIVE_NEW_D_SYM`
  to declare and `UPDATE_D_SYM` to change them in speculative actions.
- `new_D_Scope` opens a nested scope, and `enter_D_Scope` returns to the
  enclosing one, keeping updates to outer symbols.
- `${state}` carries any other path-specific context from left to right,
  safely, where a global would be wrong.

Next: [Python](python.md).
