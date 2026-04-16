# DParser
###### (you know... 'da parser)


## Introduction

`DParser` is a simple but powerful tool for parsing.  You
can specify the form of the text to be parsed using a combination of
regular expressions and grammar productions.  Because of the
parsing technique (technically a scannerless GLR parser based on the
Tomita algorithm) there are no restrictions.  The grammar can be
ambiguous, right or left recursive, have any number of null
productions,
and because there is no separate tokenizer, can include whitespace in
terminals and have terminals which are prefixes of other terminals.
`DParser` handles not just well formed computer languages and data
files, but just about any wacky situation that occurs in the real world.
The result is natural grammars and powerful parsing.


## Features

* Powerful GLR parsing
* Simple EBNF-style grammars and regular expression terminals
* State-specific symbol table
* Priorities and associativities for token and rules
* Built-in error recovery
* Can be compiled to work with or without the Boehm garbage collector
* Speculative actions (for semantic disambiguation)
* Auto-building of parse tree (optionally)
* Final actions as you go, or on the complete parse tree
* Tree walkers and default actions (multi-pass compilation support)
* Symbol table built for ambiguous parsing
* Partial parses, recursive parsing, parsing starting with any non-terminal
* Whitespace can be specified as a subgrammar
* External (C call interface) tokenizers and terminal scanners
* Good asymptotic efficiency
* Comes with ANSI-C, Python and Verilog grammars
* Comes with full source
* Portable C for easy compilation and linking
* BSD licence, so you can include it in your application without worrying about licensing


## Example Grammars

* [ANSI-C](ansic/ansic.g)
* [Python](tests/python.test.g)
* [Verilog](verilog/verilog.g)


## Documentation
* [Man page for parser generator](make_dparser.cat)
* [Manual](docs/manual.md)
* [FAQ](docs/faq.md)

## Implementation Details
For in-depth analysis of the parser architecture and specific features, see:
* [Ambiguity Analysis](ANALYSIS_AMBIGUITY.md)
* [Path Priorities Analysis](ANALYSIS_CHECK_PATH_PRIORTIES.md)
* [Error Recovery and Epsilon Hints](RECOVERY_AND_EPSILON_HINTS.md)
* [Speculative Parsing](SPECULATIVE_PARSING.md)
* [Safe Rust Implementation](SAFE_RUST.md)
* [DParser Agents](DPARSER_AGENTS.md) - documentation for using DParser with AI coding agents.

## Public Headers

* [dparse.h](dparse.h) - main parser data structures and functions
* [dparse_tables.h](dparse_tables.h) - parse tables data structures
* [dsymtab.h](dsymtab.h) - optional symbol table


## Building

* To build all components (C, Python, Rust): `gmake`
* To test all components: `gmake test`
* To build C core only: `gmake make_dparser`
* To build Python bridge: `gmake python`
* To build Rust implementation: `gmake rust`
* To install: `gmake install` -- binary or source code packages

## Language Support

### Python

`DParser` includes a powerful Cython-based bridge that allows you to define grammars and actions directly in Python.

* **Usage**: Define functions starting with `d_`. The function's docstring contains the grammar rule(s) associated with it.
* **Installation**:
  ```bash
  cd python
  gmake
  gmake install
  ```
* **Examples**: See `python/tests/` for various examples, including arithmetic evaluation and complex grammar structures.

### Rust

`DParser` for Rust is a **100% pure, native Rust** implementation. It provides a scannerless GLR parser generator and runtime entirely decoupled from C dependencies, ensuring complete memory safety.

* **Features**:
  - Pure Rust Runtime (no FFI needed for core logic).
  - Zero-copy scanning over `&str` and `&[u8]`.
  - Arena-backed parse trees for high performance and safety.
  - Type-safe action dispatching via macros.
* **Building**:
  ```bash
  cd rust
  cargo build --workspace
  ```
* **Testing**:
  ```bash
  cd rust
  cargo test --workspace
  ```
* **Examples**: Check the `rust/example` and `rust/integration_tests` directories for usage patterns.

## Makefile Options

* `D_USE_GC`: set to 1 to use the Boehm garbage collector
* `D_DEBUG`: set to 1 to compile with debugging support (`-g`)
* `D_OPTIMIZE`: set to 1 to compile with optimizations (`-O3`)
* `D_PROFILE`: set to 1 to compile with profiling support (`-pg`)
* `D_LEAK_DETECT`: set to 1 to compile with memory leak detection (`-lleak`)
* `D_USE_FREELISTS`: set to 1 to use free lists instead of straign free/malloc (defaults to 1)


## Contact
Contact the author: `jplevyak` `at` `gmail`
