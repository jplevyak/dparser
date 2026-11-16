# 1. A Calculator

In this chapter we build a calculator that evaluates expressions such as
`(1 + 2) * 3`. Along the way we cover actions, per-node values and
operator priorities.

## Per-node data

Every node in a DParser parse tree carries some system fields (its symbol,
where it starts and ends in the input) plus an optional block of *your*
data. You choose that type by defining the macro `D_ParseNode_User` before
`dparse.h` is included. Both the grammar's generated code and your driver
must agree on it, so put it in a small header, `calc.h`:

```c
typedef struct CalcNode {
  double value;
} CalcNode;
#define D_ParseNode_User CalcNode
```

## The grammar

Create `calc.g`:

```c
{
#include <stdlib.h>
#include "calc.h"
}

statement: expr { $$.value = $0.value; };

expr
  : expr '+' expr  $left 10  { $$.value = $0.value + $2.value; }
  | expr '-' expr  $left 10  { $$.value = $0.value - $2.value; }
  | expr '*' expr  $left 20  { $$.value = $0.value * $2.value; }
  | expr '/' expr  $left 20  { $$.value = $0.value / $2.value; }
  | '-' expr       $right 30 { $$.value = -$1.value; }
  | '(' expr ')'             { $$.value = $1.value; }
  | number                   { $$.value = $0.value; }
  ;

number: "[0-9]+(\.[0-9]+)?" { $$.value = strtod($n0.start_loc.s, NULL); };
```

Line by line:

- **The block in braces at the top** is global C code. It is copied into
  the generated file, so this is where includes and helper functions go.
- **`{ ... }` after a rule** is a *final action*. It runs once the parser
  has committed to this rule in the final parse.
- **`$$`** is the user data of the node being built (the left-hand side).
  **`$0`, `$1`, `$2`, ...** are the user data of the right-hand side
  elements, counting from zero. Terminals count too, which is why the
  second operand of `expr '+' expr` is `$2`.
- **`$n0`** is the *system* data of element 0, a `D_ParseNode`. Its
  `start_loc.s` points at the matched text in the input buffer, and `end`
  points just past it.
- **`$left 10`** gives the rule a priority of 10 and left associativity.
  Higher numbers bind tighter, so `*` (20) binds tighter than `+` (10), and
  unary minus (30) tighter still. [Chapter 4](ambiguity.md) explains what
  happens without them.
- **`"[0-9]+(\.[0-9]+)?"`** is a regular expression terminal. A `.` must
  be escaped; DParser regexes have no wildcard character.

!!! note "Why `statement` needs an action"
    The value of the whole parse is the value of the root node. `statement`
    is the root here, so it must copy its child's value up with
    `$$.value = $0.value`. Without that action the root's value is never
    set, and the calculator prints 0 for everything.

## The driver

Create `main.c`:

```c
#include <stdio.h>
#include <string.h>
#include "calc.h"
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

int main(int argc, char *argv[]) {
  char *input = argc > 1 ? argv[1] : "1 + 2 * 3";
  D_Parser *p = new_D_Parser(&parser_tables_gram, sizeof(CalcNode));
  p->save_parse_tree = 1;  /* keep the root node so we can read its value */
  D_ParseNode *pn = dparse(p, input, strlen(input));
  if (pn && !p->syntax_errors)
    printf("%s = %g\n", input, pn->user.value);
  else
    printf("syntax error\n");
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return 0;
}
```

Two details matter here:

- **`sizeof(CalcNode)`** is passed to `new_D_Parser` so the runtime
  allocates room for your data in every node.
- **`p->save_parse_tree = 1`** asks DParser to keep the tree after the
  final actions have run. Without it, `dparse` frees the tree as it goes
  and returns a placeholder (`NO_DPN`) instead of the root node, so there
  would be no value to read. Free the saved tree with `free_D_ParseNode`.

`calc.h` is included before `dparse.h` so that `D_ParseNode_User` is
defined when `dparse.h` declares `D_ParseNode`.

## Build and run

```bash
make_dparser calc.g
cc -o calc main.c calc.g.d_parser.c -ldparse
```

```console
$ ./calc "1 + 2 * 3"
1 + 2 * 3 = 7
$ ./calc "(1 + 2) * 3"
(1 + 2) * 3 = 9
$ ./calc "10 - 4 - 3"
10 - 4 - 3 = 3
$ ./calc "8 / 2 / 2"
8 / 2 / 2 = 2
$ ./calc "2 * -3"
2 * -3 = -6
$ ./calc "1.5 * 4"
1.5 * 4 = 6
$ ./calc "2 +"
:1: syntax error after '+'
syntax error
```

`10 - 4 - 3` is 3 because `$left` groups it as `(10 - 4) - 3`.

## What you learned

- Global code goes in braces at the top level of the grammar.
- Final actions are written in `{ }` after a rule, and use `$$`, `$0`,
  `$1`, ... for your data and `$n0`, `$n1`, ... for the system node data.
- Element numbers count every element, terminals included.
- `$left` and `$right` with a number set priority and associativity.
- Set `save_parse_tree` if you need the root node after `dparse` returns.

Next: [Parse Trees](parse-trees.md).
