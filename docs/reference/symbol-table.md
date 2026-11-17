# Symbol Table

`dsymtab.h` provides a symbol table designed for speculative parsing.
Different parse paths can declare and update symbols independently, while
sharing everything they have in common.

It is optional: you only need it if your speculative actions depend on
declarations, as in the C `typedef` problem. For a walkthrough see
[Speculative Actions](../tutorial/speculative-actions.md) and
[Scopes and State](../tutorial/scopes-and-state.md); for how it works
see [Symbol Table internals](../internals/symbol-table.md).

## Concepts

- A **scope** (`D_Scope`) holds symbols. Scopes nest: lookups search the
  current scope, then the enclosing ones.
- Each parse node has a scope, `${scope}` in actions. Each node starts
  with the scope of the node before it in the input, so a change to
  `${scope}` is seen by everything parsed afterwards on the same path.
- Scopes are **versioned**. Rather than changing a scope that other parse
  paths might share, you create a new version of it (a scope *instance*)
  that only your path sees. `SPECULATIVE_NEW_D_SYM` and `UPDATE_D_SYM` do
  this for you, updating your `${scope}` pointer.
- A **symbol** (`D_Sym`) has a name and your own data in `sym->user`.
  Updating a symbol creates a new version of it on the current path.
  `find_D_Sym` always returns the version visible from the scope you
  give it.

## Types

```c
typedef struct D_Sym {
  char *name;          /* points into the input; not copied */
  int len;
  unsigned int hash;
  struct D_Scope *scope;
  struct D_Sym *update_of;
  struct D_Sym *next;
  D_UserSym user;      /* your data */
} D_Sym;
```

Define `D_UserSym` before including `dparse.h` (or `dsymtab.h`) to choose
the type of `user`. It defaults to `unsigned int`.

```c
typedef struct { int is_type; int value; } MySym;
#define D_UserSym MySym
#include "dparse.h"
```

Symbol names are not copied. They must stay valid as long as the symbol
table is used; normally they point into the input buffer.

## Functions

### Scopes

| Function | Description |
|---|---|
| `D_Scope *new_D_Scope(D_Scope *parent)` | Create a scope nested in `parent`. With `NULL`, create a new top-level scope. |
| `D_Scope *enter_D_Scope(D_Scope *current, D_Scope *scope)` | Return to (a new instance of) `scope` while keeping the symbol updates made along the path to `current`. Use it to leave a nested scope. |
| `D_Scope *global_D_Scope(D_Scope *current)` | Enter the top-level scope from `current`. |
| `D_Scope *scope_D_Scope(D_Scope *current, D_Scope *scope)` | Return a scope that searches `current` and also `scope`, for example a class's members inside a method body. |
| `D_Scope *commit_D_Scope(D_Scope *scope)` | Flatten the update history of a top-level scope into its hash table. See [below](#commit). |
| `D_Scope *equiv_D_Scope(D_Scope *scope)` | Used by the parser: the earliest scope instance that gives the same view as `scope`. |
| `void free_D_Scope(D_Scope *scope, int force)` | Free a top-level scope and every scope created under it. |

### Symbols

| Function | Description |
|---|---|
| `D_Sym *NEW_D_SYM(D_Scope *st, char *name, char *end)` | Create a symbol in `st`. `end` points after the name, or is `NULL` to use `strlen`. Use it outside speculative actions. |
| `D_Sym *SPECULATIVE_NEW_D_SYM(D_Scope **st, char *name, char *end)` | Create a symbol in a new instance of `*st`, and update `*st`. Use it in speculative actions. |
| `D_Sym *find_D_Sym(D_Scope *st, char *name, char *end)` | Find the current version of a symbol, searching `st` and its enclosing scopes. Returns `NULL` if not found. |
| `D_Sym *find_global_D_Sym(D_Scope *st, char *name, char *end)` | Like `find_D_Sym`, but search only the top-level scope. |
| `D_Sym *find_D_Sym_in_Scope(D_Scope *st, D_Scope *cur, char *name, char *end)` | Search only `cur`, not enclosing scopes, returning the version visible from `st`. Use it to detect duplicate declarations. |
| `D_Sym *UPDATE_D_SYM(D_Sym *sym, D_Scope **st)` | Create a new version of `sym` on the current path, copying its data, and update `*st`. Set the new version's `user` fields. Returns `NULL` if `sym` is `NULL`. |
| `D_Sym *UPDATE_ADDITIONAL_D_SYM(D_Scope *st, D_Sym *sym)` | Create another new version in the same scope instance, for a second update in the same action. |
| `D_Sym *current_D_Sym(D_Scope *st, D_Sym *sym)` | The current version of `sym` as seen from `st`. Use it on symbol pointers you saved earlier. |
| `D_Sym *next_D_Sym_in_Scope(D_Scope **st, D_Sym **sym)` | Iterate over the symbols of a scope; start with `*sym = NULL`. Returns `NULL` when done. |

The lower-case functions `new_D_Sym`, `speculative_new_D_Sym`,
`update_D_Sym` and `update_additional_D_Sym` take an extra
`sizeof_D_Sym` argument for symbols with extra trailing fields. The
upper-case macros pass `sizeof(D_Sym)`.

## Rules for speculative actions

1. **Never modify a scope in place.** Use `SPECULATIVE_NEW_D_SYM` to
   declare and `UPDATE_D_SYM` to change, both of which take
   `&${scope}`. `NEW_D_SYM` on `${scope}` would make the symbol visible to
   every parse path sharing that scope.
2. **Don't set a symbol's fields after finding it.** Make a new version
   with `UPDATE_D_SYM` first.
3. **Leave a nested scope with `enter_D_Scope`.** Assigning the outer
   scope back to `${scope}` would lose updates made to outer symbols
   inside the block.

## Example: nested scopes

This example (from `tests/g29.test.g`) supports declarations
(`x: 1`), assignments (`x = 2`) and blocks, and prints each expression
statement's value:

```c
{
#include <stdio.h>

typedef struct My_Sym {
  int value;
} My_Sym;
#define D_UserSym My_Sym

typedef struct My_ParseNode {
  int value;
  struct D_Scope *scope;
} My_ParseNode;
#define D_ParseNode_User My_ParseNode
}

translation_unit: statement*;

statement
  : expression ';'
    { printf("%d\n", $0.value); }
  | '{' new_scope statement* '}'
    [ ${scope} = enter_D_Scope(${scope}, $n0.scope); ]
  ;

new_scope: [ ${scope} = new_D_Scope(${scope}); ];

expression
  : identifier ':' expression
    [
      D_Sym *s;
      if (find_D_Sym_in_Scope(${scope}, ${scope}, $n0.start_loc.s, $n0.end))
        printf("duplicate identifier line %d\n", $n0.start_loc.line);
      s = SPECULATIVE_NEW_D_SYM(&${scope}, $n0.start_loc.s, $n0.end);
      s->user.value = $2.value;
      $$.value = s->user.value;
    ]
  | identifier '=' expression
    [ D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
      s = UPDATE_D_SYM(s, &${scope});
      s->user.value = $2.value;
      $$.value = s->user.value;
    ]
  | integer
    [ $$.value = atoi($n0.start_loc.s); ]
  | identifier
    [ D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
      if (s)
        $$.value = s->user.value;
    ]
  | expression '+' expression
    [ $$.value = $0.value + $2.value; ]
  ;

integer: "-?([0-9]|0(x|X))[0-9]*(u|U|b|B|w|W|L|l)*" $term -1;
identifier: "[a-zA-Z_][a-zA-Z_0-9]*";
```

The block rule saves the scope from before the block (`$n0.scope` is the
scope at the `{`) and returns to it with `enter_D_Scope` at the `}`.
Declarations made inside the block disappear, but assignments to outer
variables are kept.

## Initial scope and memory

DParser creates a top-level scope for each parse and frees it in
`free_D_Parser` or at the start of the next `dparse`. To parse with a
symbol table you built in advance (for example, predefined names), create
it with `new_D_Scope(NULL)` and `NEW_D_SYM`, and set
`parser->initial_scope` to it. DParser then never frees it; call
`free_D_Scope(scope, 1)` yourself when done.

All scopes created during a parse are tracked from their top-level scope
and freed together. Your `D_UserSym` data is not freed by DParser.

## Commit

`commit_D_Scope(scope)` moves the symbols visible from `scope` into the
top-level hash table and makes their latest versions the canonical ones.
It only acts on top-level scopes. Call it only when no other parse path
can still be using the scopes being committed, for example from a final
action.
