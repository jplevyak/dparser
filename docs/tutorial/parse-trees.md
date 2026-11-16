# 2. Parse Trees

Actions are one way to get results out of a parser. The other is to keep
the parse tree and walk it afterwards. This chapter shows how, and explains
the extra nodes DParser creates for EBNF operators like `*`.

## A small language

Create `list.g`, a language of assignments and print statements:

```c
program: statement* ;
statement
  : identifier '=' expr ';'
  | 'print' expr ';'
  ;
expr: term ('+' term)* ;
term: identifier | number ;
identifier: "[a-zA-Z_][a-zA-Z0-9_]*" $term -1 ;
number: "[0-9]+" ;
```

The `$term -1` on `identifier` gives that terminal a lower priority than
the default 0. Where `print` could be read either as the keyword or as an
identifier, the keyword wins. See
[terminal priorities](../reference/terminals.md#terminal-priorities).

## Walking the tree

This driver keeps the tree and prints it with indentation:

```c
#include <stdio.h>
#include <string.h>
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

static void dump(D_ParseNode *pn, int depth) {
  const char *name = parser_tables_gram.symbols[pn->symbol].name;
  int n = d_get_number_of_children(pn);
  printf("%*s%s", depth * 2, "", name);
  if (n == 0)
    printf("  \"%.*s\"", (int)(pn->end - pn->start_loc.s), pn->start_loc.s);
  printf("\n");
  for (int i = 0; i < n; i++)
    dump(d_get_child(pn, i), depth + 1);
}

int main(int argc, char *argv[]) {
  char *input = argc > 1 ? argv[1] : "x = 1 + 2; print x + 3;";
  D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
  p->save_parse_tree = 1;
  D_ParseNode *pn = dparse(p, input, strlen(input));
  if (pn && !p->syntax_errors)
    dump(pn, 0);
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return 0;
}
```

The tree API is small:

| Function | Purpose |
|---|---|
| `d_get_number_of_children(pn)` | Number of children of a node. |
| `d_get_child(pn, i)` | The `i`th child (from 0). |
| `d_find_in_tree(pn, symbol)` | First node with the given symbol, searching depth first. |
| `pn->symbol` | Index into `parser_tables_gram.symbols[]`, whose `name` field is the symbol's name. |
| `pn->start_loc.s`, `pn->end` | The matched text: from `start_loc.s` up to (not including) `end`. |
| `pn->end_skip` | Like `end`, but after any trailing whitespace. |
| `pn->start_loc.line`, `pn->start_loc.col` | Where the node starts. |

Build and run:

```bash
make_dparser list.g
cc -o walk walk.c list.g.d_parser.c -ldparse
./walk
```

```text
program
  program__2
    statement
      identifier
        [a-zA-Z_][a-zA-Z0-9_]*  "x"
      =  "="
      expr
        term
          number
            [0-9]+  "1"
        expr__6
          expr__5
            +  "+"
            term
              number
                [0-9]+  "2"
      ;  ";"
    statement
      print  "print"
      ...
```

## Internal nodes for EBNF

Notice `program__2`, `expr__5` and `expr__6`. DParser implements EBNF
operators by adding *internal productions* to the grammar, and their nodes
appear in the tree:

- `statement*` in `program` becomes an internal production, here
  `program__2`. It is a **single child** of `program` whose children are
  the statements.
- The group `('+' term)` becomes `expr__5`, and the `*` applied to it
  becomes `expr__6`, whose children are the repetitions of the group.

The numbers in the names depend on the grammar, so don't rely on them.
Navigate by position instead. The general rule: **a starred or plussed
element is one child, whose children are the repetitions.** In an action
on `program: statement*`, the statements are the children of `$n0`:

```c
program: statement* {
  printf("%d statements\n", d_get_number_of_children(&$n0));
};
```

`$#0` is a shorthand for that count. `${child 0, 2}` is a shorthand for
`d_get_child(&$n0, 2)`.

Internally, `statement*` is built by recursion, which would normally give a
deep tree. DParser flattens it into a single node with one child per
repetition. You can turn this off with the `dont_fixup_internal_productions`
parser option.

## A ready-made printer

`dparse_tree.h` provides `print_parsetree()`, which prints a tree with
indentation (or with a callback you supply):

```c
#include "dparse_tree.h"
...
print_parsetree(parser_tables_gram, pn, NULL, NULL);
```

```text
program  x = 1 + 2;.
    program__2  x = 1 + 2;.
        statement  x = 1 + 2;.
            identifier  x.
            ...
```

## Freeing trees

`free_D_ParseNode(parser, root)` frees a saved tree. It is safe to call on
the `NO_DPN` placeholder that `dparse` returns when `save_parse_tree` is
off. Free the tree before `free_D_Parser`.

## What you learned

- Set `save_parse_tree` to keep the tree, and walk it with
  `d_get_number_of_children` and `d_get_child`.
- Symbol names are in `parser_tables_gram.symbols[pn->symbol].name`.
- `*`, `+`, `?` and groups create internal nodes. A repeated element is a
  single child whose children are the repetitions.

Next: [Whitespace and Errors](whitespace-and-errors.md).
