# Tutorial

This tutorial builds working parsers step by step. Each chapter has
complete code that you can copy, compile and run. Every example was run
while writing these pages: chapters 1 to 6 with DParser 1.37, and chapter 7
with 1.40.

1. **[A Calculator](calculator.md)**: attach C actions to grammar rules,
   carry values up the parse tree, and use priorities to get operator
   precedence right.
2. **[Parse Trees](parse-trees.md)**: keep the parse tree and walk it,
   and understand the nodes DParser creates for `*`, `+` and groups.
3. **[Whitespace and Errors](whitespace-and-errors.md)**: customize what
   counts as whitespace, report syntax errors, and let the parser recover.
4. **[Ambiguity](ambiguity.md)**: what DParser does when there is more
   than one way to parse the input, and how to control it.
5. **[Speculative Actions](speculative-actions.md)**: run code while
   alternatives are still being explored, reject parse paths, and use the
   symbol table to solve the classic C `typedef` problem.
6. **[Python](python.md)**: the same ideas using the Python binding, with
   grammar rules written in docstrings.
7. **[Attributes after Parsing](attributes.md)**: compute values that flow
   up and down the finished tree, such as scopes and types, on demand.

You should have DParser [installed](../getting-started/installation.md)
and have read [Your First Parser](../getting-started/first-parser.md).

The commands below assume DParser is installed where your compiler finds it
by default. If not, add `-I$PREFIX/include -L$PREFIX/lib` to the `cc`
commands.
