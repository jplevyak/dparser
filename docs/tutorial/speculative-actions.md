# 5. Speculative Actions

So far all actions have been *final* actions, written in `{ }`, which run
once on the parse that was finally chosen. DParser has a second kind:
*speculative* actions, written in `[ ]`, which run as soon as a rule is
reduced, while the parser is still exploring alternatives.

Speculative actions are how you feed information *back* into the parse.
They can look things up and reject a parse path that makes no sense.

## When each kind runs

```c
{
#include <stdio.h>
}
S: this | that;
this: hi 'mom';
that: ho 'dad';
ho: 'hello' [ printf("ho\n"); ];
hi: 'hello' [ printf("hi\n"); ];
```

On the input `hello dad` this prints:

```text
hi
ho
```

When `hello` is reduced the parser has not seen `dad` yet, so both `hi`
and `ho` are possible and both speculative actions run. Only `ho` ends up
in the final parse.

Final actions run in order, once per node in the single final parse:

```c
S: A S 'b' | 'x';
A: [ printf("speculative e-reduce A\n"); ]
   { printf("final e-reduce A\n"); };
```

On `xbbb`:

```text
speculative e-reduce A
final e-reduce A
final e-reduce A
final e-reduce A
```

`A` is empty, so its node can be shared, and its speculative action ran
once. The final parse uses `A` three times, so the final action ran three
times.

A rule can have both kinds: `rule: elements [ speculative ] { final };`

!!! warning "Keep speculative actions free of side effects"
    A speculative action may run for a parse that is later abandoned, and
    may run a different number of times than the rule appears in the final
    parse. Only write to `$$` (the node's own data), to `${scope}` (the
    symbol table, below), or to nothing at all. Printing, allocating global
    resources or writing to `$g` from a speculative action will see the
    effects of parses that never happen.

Values a speculative action stores in `$$` stay with the node. Later
speculative actions higher in the tree can read them, and so can final
actions.

## Rejecting a parse

A speculative action can abandon the current parse path with `${reject}`.
The parser then drops that alternative and continues with the others. If
none is left, that's a syntax error.

This lets the grammar consult information that a context-free grammar
can't express. The classic example comes from C.

## The `typedef` problem

In C, `a * b;` means two different things depending on what `a` is:

- If `a` is a type, it declares `b` as a pointer to `a`.
- Otherwise it multiplies `a` by `b`.

A context-free grammar can't tell these apart. DParser can: let both
interpretations be parsed, and use a speculative action to reject the one
that doesn't fit what we know about `a`. What we know lives in the
**symbol table**, which is built for exactly this situation.

```c
{
#include <stdio.h>
#include "dparse.h"
#define TEXT(n) (int)((n).end - (n).start_loc.s), (n).start_loc.s
}

program: item* ;

item
  : 'typedef' identifier ';'
      [ SPECULATIVE_NEW_D_SYM(&${scope}, $n1.start_loc.s, $n1.end); ]
      { printf("new type %.*s\n", TEXT($n1)); }
  | type_name '*' identifier ';'
      { printf("declare %.*s as pointer to %.*s\n", TEXT($n2), TEXT($n0)); }
  | value '*' value ';'
      { printf("multiply %.*s by %.*s\n", TEXT($n0), TEXT($n2)); }
  ;

type_name: identifier
  [ if (!find_D_Sym(${scope}, $n0.start_loc.s, $n0.end)) ${reject}; ] ;

value: identifier
  [ if (find_D_Sym(${scope}, $n0.start_loc.s, $n0.end)) ${reject}; ] ;

identifier: "[a-zA-Z_][a-zA-Z0-9_]*" $term -1 ;
```

How it works:

- **`${scope}`** is the current symbol table scope. DParser creates a
  top-level scope for each parse, and passes the scope along the parse
  from node to node.
- **`typedef T;`** adds `T` to the symbol table. Using
  `SPECULATIVE_NEW_D_SYM(&${scope}, ...)` creates the symbol in a new
  version of the scope that only *this* parse path sees, and updates
  `${scope}` to point to it. Every later part of the input sees the new
  symbol, but alternative parses that didn't go through this `typedef`
  don't.
- **`type_name`** accepts an identifier only if it is in the symbol table.
  **`value`** accepts one only if it isn't. `find_D_Sym` searches the
  scope and its parents.

The driver needs nothing special:

```c
#include <stdio.h>
#include <string.h>
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

int main(int argc, char *argv[]) {
  char *input = argc > 1 ? argv[1] : "a * b;  typedef a;  a * b;";
  D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
  D_ParseNode *pn = dparse(p, input, strlen(input));
  int errors = p->syntax_errors;
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return errors != 0;
}
```

```console
$ ./types
multiply a by b
new type a
declare b as pointer to a
$ ./types "typedef T; T * x; x * y;"
new type T
declare x as pointer to T
multiply x by y
```

The same text, `a * b;`, is parsed as a multiplication before the
`typedef` and as a declaration after it.

!!! note "`NEW_D_SYM` vs `SPECULATIVE_NEW_D_SYM`"
    `NEW_D_SYM(scope, ...)` adds a symbol directly to the scope you give it.
    Several parse paths can share one scope, so in a speculative action that
    would make the symbol visible on paths that never declared it. In
    speculative actions, always use `SPECULATIVE_NEW_D_SYM(&${scope}, ...)`,
    and `UPDATE_D_SYM(sym, &${scope})` to change a symbol's value. Plain
    `NEW_D_SYM` is fine in final actions, or when you build a symbol table
    before parsing.

## Nested scopes

Block-structured languages need nested scopes. Open one with
`new_D_Scope(${scope})` when a block starts, and at the end of the block
return to the enclosing scope with `enter_D_Scope(${scope}, outer)`. Don't
simply assign the outer scope back to `${scope}`: `enter_D_Scope` keeps
any updates to outer symbols made inside the block. The
[Symbol Table reference](../reference/symbol-table.md) has a complete
example.

## Attaching data to symbols

Define `D_UserSym` before including `dparse.h` to give each symbol a field
of your own type, `sym->user`:

```c
typedef struct { int is_type; int value; } MySym;
#define D_UserSym MySym
```

## What you learned

- `[ ]` actions run speculatively, possibly several times, on parses that
  may be abandoned. `{ }` actions run once on the final parse.
- `${reject}` in a speculative action abandons the current parse path.
- The symbol table gives each parse path its own view. Use
  `SPECULATIVE_NEW_D_SYM` and `UPDATE_D_SYM` in speculative actions.

Next: [Python](python.md).
