# Adding support for another language

## Design

Two mechanisms are provided for adding support for another language to DParser.

- The first is to use the C data object version of the parser tables and then link in native actions written in the target language.
- The second is to use a proprietary binary version of the parser tables and then dynamically patch in native actions written in the target language.

The first mechanism is suitable for C, C++, Rust and other statically compiled languages.  The second mechanism is used by the Python implementation and can be used by dyamic languages, languages with strong macro systems that can build and link the the tables and actions at compile time or for run-time grammar changes and/or code generation.

## Adding support for a new language using the C data object version of the parser tables

The `make_dparser` binary has native support for C and C++ as it can output a C/C++ compatible file containing both the parser tables and the actions.  The parser tables are then compiled into a C/C++ compatible data object file.  The actions are already in C/C++ and linked into the parser tables.

For non-C/C++ languages, the actions can be output to a different file along with the metadate necessary to link them to the parser tables at load time.  The actions can then be converted to a target language file using a target language program, compiled to a target language binary, loaded by a target language library and linked to the parser tables at load time.

### Building the parser tables and actions file for non-C/C++ languages

The `make\_dparser` binary generates the parser tables and actions file.

```bash
make_dparser <grammar_file> -o <output_file> -a <actions_file>
```

It is a C program that takes a grammar file as input and produces as output a C data version of the parser tables and (optionally) a file containing all native code (i.e. all the actions and any global code).

### Converting the actions file to the target language

The actions file has the following format:

```c
1 grammar.g 5
// Global code in the target language
// This code started at line 1 in the grammar file grammar.g and is 5 lines long

foo: Foo = "Some stuff in the target language"
bar: Bar = "Some more stuff in the target language"
dparser_action_15_31_4 115 grammar.g 6
// Actions in the target language
// This code started at line 15 in the grammar file grammar.g and is 31 lines long
// This code must be compiled into a C compatible function with name dparser_action_15_31_4
// The function has the following signature:
// int (void *new_ps, void **children, int n_children, int pn_offset, struct D_Parser *parser)
$$ = $1
```

All of the global code appearing anywhere in the grammar file will be grouped into the single initial global code block.  The actions will appear in the order they were found in the grammar file.  The actions and global code will be exactly as they appear in the grammar file. It is up to the target language program to translate any special operotors or keywords into the target language and to provide any necessary library support for their implementation.  Note that the special operators and keywords need not be the same as those used for C/C++ as each target language can pick its own special operators and keywords.  The only requirement is that the target language program must be able to parse the actions file and convert it to a target language file.

For instance, the Rust translator converts `$$` to:

```rust
d_user::<NodeStruct>(d_pn_ptr(_ps, _offset)).unwrap()
```

where the d\_user and d\_pn\_ptr functions are provided by the Rust library.  The d\_user function is returns a reference to the user data structure of the node.  The d\_pn\_ptr function returns a reference to the parse node which is at the given offset within an internal DParser data structure.  This is only an example and every target language is free to decide how they would like handle the implementation.


### C format data structures

All the C format data structures that are required for target language support are defined in the `dparse.h` file.  This includes the C format data structures for the parser tables as well as the runtime data structures for the parser, parse nodes, etc.  This file can often be translated using a foreign function interface (FFI) to the target language.  For Rust, the translation is done with the `bindgen` tool.  For Python, the translation is done with `swig` although it could be done with the `ctypes` library.  For other languages, the translation can be done with a similar FFI library or by hand.

### Library support

A native language library is required to link the parser tables and actions together.  This library should provide a function to create the Parser from the compile parser tables and actions.  It should also provide mechanisms to set the runtime options for the Parser and to parse a string.  The library should also provide support for setting the global state and freeing the parse tree.  See the Rust support library for an example.

### Build system support and an example

An example should be provided which demonstrates how to build and link a parser from a grammar file in the native language.
