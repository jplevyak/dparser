# make_dparser

`make_dparser` reads a grammar and writes the parse tables, with your
actions compiled in, as C source.

```text
make_dparser [options] grammar.g
```

By default the output is `grammar.g.d_parser.c` in the same directory as
the grammar. The tables are a `D_ParserTables` named `parser_tables_gram`.

## Options

Options marked *toggle* take no value and flip the default.

| Option | Long form | Default | Description |
|---|---|---|---|
| `-o file` | `--output` | `grammar.g.d_parser.c` | Output file name. |
| `-X ext` | `--ext` | `c` | Extension for the default output name, for example `cpp` to compile the actions as C++. |
| `-i name` | `--grammar_ident` | `gram` | Suffix for generated names: the tables become `parser_tables_name`. Use it to link several grammars into one program. |
| `-I` | `--filename_ident` | off (toggle) | Use the grammar's file name (up to the first `.`) as the identifier. |
| `-H n` | `--write_header` | `-1` | Write the header `grammar.g.d_parser.h`: `1` always, `0` never, `-1` only if it would not be empty (the grammar has tokens or start states). The header also has `D_RULE_<production>_<n>` constants for [`d_get_production`](attributes.md#which-rule-built-a-node). |
| `-t n` | `--token_type` | `0` | Token symbols in the header as `#define`s (`0`) or an `enum` (`1`). |
| `-l` | `--longest_match` | off (toggle) | Use longest-match scanning. See [Longest match](terminals.md#longest-match). |
| `-T` | `--tokenizer` | off (toggle) | Use a tokenizer for the start symbol. See [Tokenizers](terminals.md#tokenizers). |
| `-A` | `--all_states` | off (toggle) | Build start states for every nonterminal. See [Start states](grammar.md#start-states). |
| `-C` | `--whitespace_states` | on (toggle) | Build states for the `whitespace` production. |
| `-p` | `--op_pri_from_rule` | off (toggle) | Copy each rule's priority onto its last terminal as an operator priority. |
| `-r` | `--right_recurse_BNF` | off (toggle) | Implement `*` and `+` with right recursion instead of left recursion. |
| `-L` | `--write_lines` | on (toggle) | Write `#line` directives so compiler errors in actions point at the grammar. `-L` turns them off. |
| `-b n` | `--scanner_blocks` | `4` | Number of blocks the scanner tables are split into; a space/time trade-off for large grammars. |
| `-B` | `--binary_tables` | off (toggle) | Write binary tables instead of C. Use `-o` to name the file. See [Binary tables](c-api.md#binary-tables). |
| `-a file` | `--actions_output` | none | With `-B`, write the actions (and the external scanners and whitespace function the tables need) to a separate file in a simple text format, for runtimes that compile them themselves (used by the Rust crate). See [Binary Tables](../internals/binary-tables.md#actions). |
| `-R` | `--rdebug_grammar` | 0 | Print a version of the grammar whose actions print each reduction, instead of writing tables. Useful for debugging. |
| `-v` | `--verbose` | 0 | Print statistics and progress. Repeat for more. |
| `-d` | `--debug` | 0 | Print debugging information. Repeat for more. |
| `-h` | `--help` | | Print the options. |

## Environment variables

Every option can also be set with an environment variable:

| Variable | Option |
|---|---|
| `D_MAKE_PARSER_OUTPUT` | `-o` |
| `D_MAKE_PARSER_WRITE_EXT` | `-X` |
| `D_MAKE_PARSER_GRAMMAR_IDENT` | `-i` |
| `D_MAKE_PARSER_IDENT_FROM_FILENAME` | `-I` |
| `D_MAKE_PARSER_HEADER` | `-H` |
| `D_MAKE_PARSER_TOKEN` | `-t` |
| `D_MAKE_LONGEST_MATCH` | `-l` |
| `D_MAKE_PARSER_TOKENIZER` | `-T` |
| `D_MAKE_PARSER_ALL_NTERMS` | `-A` |
| `D_MAKE_PARSER_WHITESPACE` | `-C` |
| `D_MAKE_PARSER_SET_PRIORITY` | `-p` |
| `D_MAKE_PARSER_RIGHT_RECURSIVE_BNF` | `-r` |
| `D_MAKE_PARSER_WRITE_LINE_DIRECTIVES` | `-L` |
| `D_MAKE_PARSER_SCANNER_BLOCKS` | `-b` |
| `D_MAKE_BINARY_TABLES` | `-B` |
| `D_MAKE_PARSER_ACTIONS_OUTPUT` | `-a` |
| `D_MAKE_RDEBUG_GRAMMAR` | `-R` |
| `D_MAKE_PARSER_VERBOSE` | `-v` |
| `D_MAKE_PARSER_DEBUG` | `-d` |

## Examples

```bash
# Two grammars in one program
make_dparser -i expr expr.g      # parser_tables_expr
make_dparser -i stmt stmt.g      # parser_tables_stmt

# Actions written in C++
make_dparser -X cpp my.g         # my.g.d_parser.cpp

# Binary tables
make_dparser -B -o my.g.d_parser.dat my.g
```
