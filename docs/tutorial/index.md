# Tutorial

This tutorial builds working parsers step by step. Each chapter has
complete code that you can copy, compile and run. Every example was run
while writing these pages, with DParser 1.37 or later.

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
6. **[Scopes and State](scopes-and-state.md)**: nested scopes and data in
   symbols, and threaded state for other context that depends on the
   parse path, such as loop depth.
7. **[Python](python.md)**: the same ideas using the Python binding, with
   grammar rules written in docstrings.
8. **[Attributes after Parsing](attributes.md)**: compute values that flow
   up and down the finished tree, such as scopes and types, on demand.
9. **[Rust](rust.md)**: a calculator, the symbol table and threaded state
   with the native Rust runtime.

You should have DParser [installed](../getting-started/installation.md)
and have read [Your First Parser](../getting-started/first-parser.md).

The commands below assume DParser is installed where your compiler finds it
by default. If not, add `-I$PREFIX/include -L$PREFIX/lib` to the `cc`
commands.
