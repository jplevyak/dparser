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
* Threaded state: per-parse-path context that speculative actions can safely change
* Attributes: synthesized and inherited values on the parse tree, evaluated on demand
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
* [Python](python.g)
* [Verilog](verilog/verilog.g)


## Documentation

Full documentation is at **<https://jplevyak.github.io/dparser/>**:

* [Getting started](https://jplevyak.github.io/dparser/getting-started/installation/)
* [Tutorial](https://jplevyak.github.io/dparser/tutorial/)
* [Reference](https://jplevyak.github.io/dparser/reference/): grammar syntax, actions, `make_dparser`, and the C, C++, Python and Rust APIs
* [Internals](https://jplevyak.github.io/dparser/internals/): how the parser works
* [FAQ](https://jplevyak.github.io/dparser/faq/)

The site's source is in [`docs/`](docs/). The man page for the parser
generator is [make_dparser.cat](make_dparser.cat).

## Public Headers

* [dparse.h](dparse.h) - main parser data structures and functions
* [dparse_tables.h](dparse_tables.h) - parse tables data structures
* [dsymtab.h](dsymtab.h) - optional symbol table
* [dattr.h](dattr.h) - optional attributes after parsing (C++: [dattr.hpp](dattr.hpp))


## Building

* To build the C library and `make_dparser`: `gmake`
* To test: `gmake test`
* To install: `gmake install` (set `PREFIX` to change the location, default `/usr/local`)
* To build and install the Python binding: `pip install .`
* To build the Rust crate: `cd rust && cargo build --workspace`

## Language Support

### Python

The Python binding lets you write a whole parser in Python: each `d_`
function's docstring holds grammar rules, and the function is their action.

* **Install**: `pip install .` from the top of the source tree.
* **Features**: speculative actions and `Reject`, the symbol table (a
  `scope` action argument), threaded state (`state`), parse trees kept
  after the parse (`keep_tree=True`), and attributes (`dparser_attrs`).
* **Docs**: the [Python tutorial](https://jplevyak.github.io/dparser/tutorial/python/)
  and [API reference](https://jplevyak.github.io/dparser/reference/python/).
  `python/tests/` has many small examples.

### Rust

The `dparser` crate in `rust/` is a native Rust runtime, a port of the C
engine that parses exactly as C does. Grammars use Rust code in their
actions; `make_dparser` (built by the crate) compiles them to tables that
your program embeds, and `dparser::build_actions` turns the actions into a
Rust dispatcher.

* **Features**: speculative and final actions, `${reject}`, the symbol
  table (`${parser}.symtab`), threaded state (`${state}`), passes, error
  recovery, external scanners, whitespace functions, and attributes
  (`dparser::attrs`).
* **Build and test**:
  ```bash
  cd rust
  cargo build --workspace
  cargo test --workspace
  ```
* **Docs**: the [Rust tutorial](https://jplevyak.github.io/dparser/tutorial/rust/)
  and [reference](https://jplevyak.github.io/dparser/reference/rust/).

## Makefile Options

* `D_USE_GC`: set to 1 to use the Boehm garbage collector
* `D_DEBUG`: set to 1 to compile with debugging support (`-g`)
* `D_OPTIMIZE`: set to 1 to compile with optimizations (`-O3`)
* `D_PROFILE`: set to 1 to compile with profiling support (`-pg`)
* `D_LEAK_DETECT`: set to 1 to compile with memory leak detection (`-lleak`)
* `D_USE_FREELISTS`: set to 1 to use free lists instead of straign free/malloc (defaults to 1)


## Contact
Contact the author: `jplevyak` `at` `gmail`
