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


## Public Headers

* [dparse.h](dparse.h) - main parser data structures and functions
* [dparse_tables.h](dparse_tables.h) - parse tables data structures
* [dsymtab.h](dsymtab.h) - optional symbol table


## Building

* To build: `gmake` -- only available with source code package
* To test: `gmake test` -- only available with source code package
* To install: `gmake install` -- binary or source code packages

For python support: `cd python; gmake install`


## Makefile Options

* `D_USE_GC`: set to 1 to use the Boehm garbage collector
* `D_DEBUG`: set to 1 to compile with debugging support (`-g`)
* `D_OPTIMIZE`: set to 1 to compile with optimizations (`-O3`)
* `D_PROFILE`: set to 1 to compile with profiling support (`-pg`)
* `D_LEAK_DETECT`: set to 1 to compile with memory leak detection (`-lleak`)
* `D_USE_FREELISTS`: set to 1 to use free lists instead of straign free/malloc (defaults to 1)


## Contact
Contact the author: `jplevyak` `at` `gmail`
