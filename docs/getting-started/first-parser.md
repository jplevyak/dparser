# Your First Parser

This page builds the smallest useful parser: one that accepts sums of the
letters `a`, `b` and `c`, such as `a+b+c`.

## 1. Write a grammar

Create `my.g`:

```c
E: E '+' E | "[abc]";
```

This says an `E` is either two `E`s joined by `+`, or one of the characters
`a`, `b` or `c`. Strings in single quotes are literal terminals; strings in
double quotes are regular expressions. The first production in the file
(`E` here) is the start symbol.

## 2. Generate the parse tables

```bash
make_dparser my.g
```

This writes `my.g.d_parser.c`, which contains the parse tables in a
variable named `parser_tables_gram`.

## 3. Write a driver

Create `my.c`:

```c
#include <stdio.h>
#include <string.h>
#include <dparse.h>

extern D_ParserTables parser_tables_gram;  /* defined in my.g.d_parser.c */

int main(void) {
  char line[256];
  D_Parser *parser = new_D_Parser(&parser_tables_gram, 0);
  if (fgets(line, sizeof(line), stdin) &&
      dparse(parser, line, strlen(line)) && !parser->syntax_errors)
    printf("success\n");
  else
    printf("failure\n");
  free_D_Parser(parser);
  return 0;
}
```

The pattern is always the same:

1. `new_D_Parser()` creates a parser from the generated tables. The second
   argument is the size of your per-node data; this example has none.
2. `dparse()` parses a buffer. It returns `NULL` if the parse failed.
3. Check `parser->syntax_errors`. DParser recovers from syntax errors by
   default, so a parse can "succeed" while reporting errors.
4. `free_D_Parser()` releases the parser.

## 4. Compile and run

```bash
cc -o my my.c my.g.d_parser.c -ldparse
```

If you installed under a non-standard prefix, add `-I$PREFIX/include` and
`-L$PREFIX/lib`.

```console
$ echo 'a+b' | ./my
success
$ echo 'a + b + c' | ./my
success
$ echo 'a+' | ./my
:2: syntax error after '+'
failure
```

A few things to notice:

- **Whitespace is skipped automatically.** The default whitespace handler
  skips spaces, tabs, newlines, C and C++ comments, and `#line` directives.
  See [Whitespace](../tutorial/whitespace-and-errors.md).
- **The error is reported on line 2** because the newline read by `fgets`
  was consumed as whitespace before the parser discovered that nothing
  followed the `+`. The empty name before `:2:` is the file name; set
  `parser->loc.pathname` before parsing to fill it in.
- **`a + b + c` is ambiguous**: it could be `(a + b) + c` or
  `a + (b + c)`. DParser resolved it with its built-in rules. When the
  parser computes something, you choose the grouping with
  [priorities](../tutorial/ambiguity.md).

## Next steps

The [tutorial](../tutorial/index.md) builds on this to make a calculator
that actually computes values.
