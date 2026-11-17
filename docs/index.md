---
hide:
  - navigation
---

# DParser

**DParser is a scannerless GLR parser generator.** You describe the text you
want to parse with a grammar that mixes regular expressions and EBNF-style
productions. DParser turns it into parse tables and a small C runtime parses
input with them, running your actions as it goes.

Because it is a [GLR](https://en.wikipedia.org/wiki/GLR_parser) parser (based
on Tomita's algorithm) there are no restrictions on the grammar. It can be
ambiguous, left or right recursive, and have any number of empty productions.
Because there is no separate tokenizer, terminals can contain whitespace and
can be prefixes of each other. The result is grammars that read like the
language they describe.

```c
expr
  : expr '+' expr  $left 10  { $$.value = $0.value + $2.value; }
  | expr '*' expr  $left 20  { $$.value = $0.value * $2.value; }
  | '(' expr ')'             { $$.value = $1.value; }
  | number                   { $$.value = $0.value; }
  ;

number: "[0-9]+" { $$.value = atof($n0.start_loc.s); };
```

<div class="grid cards" markdown>

-   **[Get started](getting-started/installation.md)**

    Build and install DParser, then write and run your first parser in a
    few minutes.

-   **[Tutorial](tutorial/index.md)**

    Build a calculator step by step, then learn parse trees, error recovery,
    ambiguity, speculative actions, scopes and state, and attributes, in C,
    Python and Rust.

-   **[Reference](reference/index.md)**

    The full grammar syntax, action specifiers, declarations, command-line
    options and the C, C++, Python and Rust APIs.

-   **[Internals](internals/index.md)**

    How the tables are built and how the GLR runtime, scanner,
    disambiguation and error recovery work.

</div>

## Features

- **GLR parsing** of any context-free grammar, including ambiguous ones.
- **Scannerless**: terminals are strings and regular expressions matched in
  the context of the current parse state, so there are no tokenizer
  conflicts. An optional [tokenizer mode](reference/terminals.md#tokenizers)
  and [external scanners](reference/terminals.md#external-scanners) are
  available when you want them.
- **EBNF grammars** with `*`, `+`, `?`, grouping and bounded repetition.
- **Priorities and associativity** on terminals, operators and rules,
  applied at parse time.
- **Speculative actions** that run while alternatives are still being
  explored, and can reject a parse path, and **final actions** that run once
  on the chosen parse.
- **A symbol table designed for ambiguous parsing**, so each speculative path
  sees its own declarations.
- **[Threaded state](reference/threaded-state.md)**: your own context, such
  as nesting depth or an indentation stack, carried along each parse path
  and safe for speculative actions to read and change.
- **Automatic parse trees**, tree walkers and multi-pass actions.
- **[Attributes](reference/attributes.md)**: synthesized and inherited
  values on the finished tree, such as scopes and types, computed on demand
  in dependency order.
- **Built-in error recovery** suited to C-like languages.
- **Whitespace as a subgrammar**, or as your own C function.
- **Partial parses** and parsing from any nonterminal.
- **Bindings** for [C++](reference/cpp.md), [Python](reference/python.md)
  and a native [Rust](reference/rust.md) runtime.
- **Example grammars** for
  [ANSI C](https://github.com/jplevyak/dparser/blob/main/ansic/ansic.g) and
  [Python](https://github.com/jplevyak/dparser/blob/main/python.g).
- Portable C under the BSD license.

## How it fits together

``` mermaid
flowchart LR
  G["grammar.g"] -->|make_dparser| T["grammar.g.d_parser.c<br/>(tables + actions)"]
  T --> CC["C compiler"]
  D["your driver.c"] --> CC
  L["libdparse"] --> CC
  CC --> P["your parser"]
  I["input text"] --> P
  P --> R["actions run,<br/>parse tree"]
```

1. `make_dparser` reads your grammar and writes a C file containing the parse
   tables and your actions compiled into functions.
2. You compile that file together with a small driver and link against
   `libdparse`.
3. The driver calls `dparse()` on the input text.

## License

DParser is distributed under the BSD license, so you can include it in your
application without worrying about licensing. See
[LICENSE.txt](https://github.com/jplevyak/dparser/blob/main/LICENSE.txt).
