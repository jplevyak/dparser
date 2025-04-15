
# Rust support for DParser

This is a Rust binding for the [DParser library](https://github.com/jplevyak/dparser) that allows you to use DParser grammars in Rust projects. It is a currnetly an Alpha release and is not yet ready for production use.

It consists of two parts: a library that wraps the DParser library and a binary that can be used to generate Rust code from a DParser grammar file.

## Example

[DParser Rust Example](https://githbub.com/jplevyak/dparser/rust/example) is a simple example of how to use the DParser Rust library. It consists of:

- A simple [grammar file](https://github.com/jplevyak/dparser/rust/example/src/my_grammar.g) that defines a grammar with actions in Rust.
- A [build.rs](https://github.com/jplevyak/dparser/rust/example/build.rs) file that generates the parsing tables and Rust action file  grammar file.
- A [main.rs](https://github.com/jplevyak/dparser/rust/example/src/main.rs) driver that loads the parsing tables and parses a simple input file.
