# Binary Tables

Normally `make_dparser` writes the tables as C source. With `-B` it writes
them as a binary image instead, which a program can load at run time.
This is how the Python binding builds grammars on the fly, and how the
Rust crate embeds them.

## Format

The binary file is a relocatable memory image of the same structures the
C tables would define (`D_ParserTables`, states, reductions, shifts,
scanner tables and so on):

1. A header (`BinaryTablesHead`): the number of relocations and strings,
   the offset of the `D_ParserTables` root, and the sizes of the tables
   and string sections.
2. The tables section: the structures laid out as they will be in memory,
   with pointers stored as offsets.
3. The strings section: symbol names and terminal strings.
4. The relocation list: the offsets of every pointer in the tables, so
   the loader can add the base address.
5. The string relocation list.

`read_binary_tables()` reads the image, adds the base address of each
section to every recorded pointer, and returns a `BinaryTables` whose
`parser_tables_gram` is ready to pass to `new_D_Parser`.

Because the image is a direct copy of C structures, it depends on the
platform's pointer size, byte order and structure layout. Generate it on
the same kind of platform that will read it.

## Actions

C code can't be stored in a binary file. Instead, each reduction that has
an action records two special pointer values, one for speculative code
and one for final code, and its `action_index`. When loading,
`read_binary_tables()` replaces them with the `spec_code` and
`final_code` callbacks you pass in. Every action therefore goes through
the same two functions, which can find the rule from the reduction's
`action_index`. The rule's index is set by `${action}` or `${action N}` in
the grammar, or assigned automatically.

The Python binding uses this: it writes each Python action's rules with
`${action}`, so action *N* is the *N*th Python function, and its
callbacks call that function.

The Rust crate takes another route: `make_dparser -a` writes the action
code to a separate file, which `dparser::build_actions` turns into a Rust
`dispatch_action` function indexed the same way. Each action is headed by
a line naming its kind and action index (`int
d_speculative_code_action_N`, `d_final_code_action_N` or
`d_passK_code_action_N`) with its source line, file and length. Rules that
use the `_` production's default code get a copy under their own index.

External scanners (`${scan}`, `${scanner}`) and whitespace functions
(`${declare whitespace}`) can't be stored in binary tables either. Their
states and the tables are marked with another special pointer value (-4),
which `read_binary_tables()` rejects, and the actions file records what the
Rust runtime must call: `scan <state> <symbol> <term_priority> <call>`,
`scanner <function>`, `whitespace <function>` and `token <name> <symbol>`
lines.
