# 3. Whitespace and Errors

## Default whitespace

Between terminals, DParser skips whitespace. The default handler skips:

- spaces, tabs, carriage returns, form feeds and newlines;
- C comments `/* ... */`, which may be nested, and C++ comments `// ...`;
- `#line` directives (`# 12 "file.c"` or `#line 12 "file.c"`) at the start
  of a line, which also update the line number and file name used in
  error messages.

That suits C-like languages. For anything else, replace it in one of two
ways.

## A whitespace subgrammar

If your grammar defines a production named `whitespace`, DParser uses it to
skip whitespace instead of the default. This grammar treats `#` as a
comment that runs to the end of the line:

```c
{
#include <stdio.h>
}
program: word* { printf("%d words\n", $#0); } ;
word: "[a-z]+" ;
whitespace: "([ \t\n]|#[^\n]*)*" ;
```

```console
$ cat ws.in
one two # a comment
three
# another
four
$ ./ws ws.in
4 words
```

`whitespace` is a full production, so it can have several rules and
actions of its own. Note that it replaces the default completely: with the
grammar above, `//` is no longer a comment.

## A whitespace function

For full control, set `initial_white_space_fn` on the parser to a C
function. It receives the current location and must advance `loc->s` past
any whitespace, updating `loc->line` and `loc->col` as it goes:

```c
/* Skip spaces, tabs, newlines and ';' comments that run to end of line. */
static void skip(D_Parser *p, d_loc_t *loc, void **globals) {
  char *s = loc->s;
  for (;;) {
    if (*s == '\n') { loc->line++; loc->col = 0; s++; }
    else if (*s == ' ' || *s == '\t') { loc->col++; s++; }
    else if (*s == ';') { while (*s && *s != '\n') { s++; loc->col++; } }
    else break;
  }
  loc->s = s;
}

...
D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
p->initial_white_space_fn = skip;
```

You can also name the function in the grammar with
`${declare whitespace skip}`; see
[Declarations](../reference/declarations.md#whitespace).

!!! tip
    Whitespace is skipped *after* a terminal is matched, when the parser
    moves to its next state. A node's `end` therefore excludes trailing
    whitespace, while `end_skip` includes it. `d_ws_before()` and
    `d_ws_after()` give you the whitespace around any node.

## Syntax errors

When the parser cannot continue, it calls `syntax_error_fn` and increments
`parser->syntax_errors`. The default function prints a message such as:

```text
input.txt:3: syntax error after '+'
```

The location of the error is in `parser->loc` when the function is called.
To report errors your own way, install your own function:

```c
static void report(D_Parser *p) {
  fprintf(stderr, "error at line %d, column %d\n", p->loc.line, p->loc.col);
}
...
p->syntax_error_fn = report;
```

Set `p->loc.pathname` before calling `dparse` to have the default message
include a file name.

## Error recovery

By default DParser does not stop at the first error. It looks for a way to
resynchronize and keeps going, so one parse can report several errors.

The method suits C-like languages. Rules that **end in a literal string**
(such as `statement: expr ';'` or `block: '{' statement* '}'`) act as
recovery points. On an error, the parser looks back for such a rule that it
was in the middle of, skips ahead to the next occurrence of its closing
string (here `;` or `}`), and treats the rule as complete. Parsing then
continues from there. The node that covers the skipped text does not run
its final action.

Here is a statement language with an error on line 2:

```c
{
#include <stdio.h>
#include <stdlib.h>
#include "calc.h"
}

program: statement* ;

statement: expr ';' { printf("line %d: %g\n", $n0.start_loc.line, $0.value); } ;

expr
  : expr '+' expr  $left 10  { $$.value = $0.value + $2.value; }
  | expr '*' expr  $left 20  { $$.value = $0.value * $2.value; }
  | number                   { $$.value = $0.value; }
  ;

number: "[0-9]+" { $$.value = strtod($n0.start_loc.s, NULL); };
```

```c
#include <stdio.h>
#include <string.h>
#include "calc.h"
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

static void report(D_Parser *p) {
  fprintf(stderr, "error at line %d, column %d\n", p->loc.line, p->loc.col);
}

int main(void) {
  char *input =
    "1 + 2;\n"
    "3 + ;\n"
    "4 * 5;\n";
  D_Parser *p = new_D_Parser(&parser_tables_gram, sizeof(CalcNode));
  p->syntax_error_fn = report;
  D_ParseNode *pn = dparse(p, input, strlen(input));
  int errors = p->syntax_errors;
  printf("syntax errors: %d\n", errors);
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return errors != 0;
}
```

```console
$ ./stmts
error at line 2, column 4
line 1: 3
line 3: 20
syntax errors: 1
```

The bad statement on line 2 was skipped, and the statements on either side
were evaluated normally.

Notice that the error is printed before either statement's output. Final
actions run when the parser commits to a part of the parse, not
immediately as text is read; see
[Actions and Commit](../internals/actions.md).

!!! warning "Always check `syntax_errors`"
    With error recovery on, `dparse` can return a tree even though the
    input had errors. Test `parser->syntax_errors` to decide whether the
    parse succeeded. To stop at the first error instead, set
    `parser->error_recovery = 0`.

Next: [Ambiguity](ambiguity.md).
