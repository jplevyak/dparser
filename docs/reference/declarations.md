# Declarations

Declarations appear at the top level of a grammar, between productions.
They are written `${keyword ...}`.

## `${declare ...}`

```c
${declare kind}
${declare kind nonterminal nonterminal ...}
```

| Declaration | With no arguments | With nonterminals |
|---|---|---|
| `longest_match` | Use longest-match scanning for the whole grammar (same as `make_dparser -l`). | Use longest match in the states reached from these nonterminals. |
| `all_matches` | Keep all matches (the default). Turns off a global `longest_match`. | Keep all matches in the states reached from these nonterminals. |
| `tokenize` | Use a tokenizer for the whole grammar (same as `make_dparser -T`). | Use a tokenizer for the states reached from these nonterminals. |
| `whitespace` | | `${declare whitespace fn}`: use the C function `fn` as the default whitespace handler. See [below](#whitespace). |
| `subparser` | | Build start states for these nonterminals, so parsing can start from them. See [Start states](grammar.md#start-states). |
| `all_subparsers` | Build start states for every nonterminal (same as `make_dparser -A`). | |
| `save_parse_tree` | Make `save_parse_tree` default to on for parsers using these tables. | |
| `mutable_speculative_globals` | Let speculative actions write to `$g`, as they could before 1.39. See [below](#mutable-speculative-globals). | |
| `set_op_priority_from_rule` | Give the last terminal of each rule with a rule priority the same priority and associativity, as an operator priority (same as `make_dparser -p`). | |

Tokenizers and longest match are explained in
[Terminals and Scanning](terminals.md#tokenizers). When they are declared
for particular nonterminals, the sets of states involved must not overlap,
because parse states are not split between declarations.

## Mutable speculative globals

Since 1.39, `$g` is read-only in speculative actions (`[ ]`). In C and
C++ it is a `const D_ParseNode_Globals *` there, and in Rust a `&G`, so a
write is a compile error.

A speculative action can run on a parse path that is later abandoned, and
nothing undoes what it wrote to `$g`. State that depends on the parse
path belongs in the node's own data (`$$`) or in the symbol table
(`${scope}`).

`${declare mutable_speculative_globals}` restores the old behavior for
grammars that relied on it:

- In C and C++, speculative actions get a writable `$g` again.
- In Rust, speculative actions get `&mut G`.

```c
${declare mutable_speculative_globals}
LP ::= '(' [ $g->implicit_line_joining++; ];
```

Only use it when writes to `$g` are correct whichever paths survive, or
when the grammar never keeps competing paths alive across them.

## `${pass ...}`

```c
${pass name option option ...}
```

Declares a tree-walking pass for [pass actions](actions.md#pass-actions).
The options are `preorder`, `postorder` or `manual`, and `for_all` or
`for_undefined`.

## `${scanner ...}` and `${token ...}`

```c
${scanner my_scanner}
${token NUMBER IDENT STRING}
```

`${scanner fn}` installs a global scanner function, and `${token ...}`
declares the terminals it can return. `make_dparser` writes their symbol
numbers to the generated header. See
[Global scanners](terminals.md#global-scanners-scanner).

## Whitespace

There are three ways to define whitespace, from simplest to most flexible:

1. **Do nothing.** The built-in handler skips blanks, newlines, C and C++
   comments (`/* */` may nest) and `#line` directives.
2. **Define a `whitespace` production.** If the grammar has a production
   named `whitespace`, it is used as a subgrammar to skip whitespace,
   replacing the built-in handler:

    ```c
    whitespace: ( "[ \t\n]+" | comment )* ;
    comment: '#' "[^\n]*" ;
    ```

    The whitespace parser is a separate parser built from the same tables.
    It inherits the main parser's settings, and its actions run like any
    others.

3. **Write a C function** with this signature:

    ```c
    void my_ws(D_Parser *p, d_loc_t *loc, void **p_globals);
    ```

    It must advance `loc->s` past the whitespace and keep `loc->line` and
    `loc->col` up to date. Name it in the grammar with
    `${declare whitespace my_ws}`, or set `parser->initial_white_space_fn`
    in your driver.

You can find the whitespace around a node with `d_ws_before()` and
`d_ws_after()`; see [C API](c-api.md#tree-functions).

## `include`

`include "file.g"` reads another grammar file at that point. See
[Grammar Syntax](grammar.md#include).
