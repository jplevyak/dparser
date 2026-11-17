# Reference

Complete descriptions of the grammar language, the tools and the APIs.

## The grammar language

- **[Grammar Syntax](grammar.md)**: productions, rules, EBNF operators,
  global code, comments and includes.
- **[Terminals and Scanning](terminals.md)**: strings, regular
  expressions, Unicode, terminal modifiers and priorities, external
  scanners, tokenizers and longest match.
- **[Actions](actions.md)**: speculative, final, embedded, pass and
  default actions, and every `$` specifier you can use in action code.
- **[Declarations](declarations.md)**: `${declare ...}`, `${pass ...}`,
  `${scanner ...}`, `${token ...}`, and the `whitespace` production.
- **[Priorities and Disambiguation](disambiguation.md)**: terminal,
  operator and rule priorities, associativity, and the order in which
  ambiguities are resolved.
- **[Symbol Table](symbol-table.md)**: the speculative symbol table API.
- **[Threaded State](threaded-state.md)**: `${state}`, path-specific
  context such as nesting depth or an indentation stack.
- **[Attributes](attributes.md)**: synthesized and inherited attributes
  on the finished tree, and `d_get_production`.

## Tools and APIs

- **[make_dparser](make_dparser.md)**: the parser generator's options.
- **[C API](c-api.md)**: `dparse.h`, the parser object and its options,
  parse nodes and the tree functions.
- **[C++ Wrapper](cpp.md)**: `dparse.hpp`.
- **[Python API](python.md)**: the `dparser` module.
- **[Rust](rust.md)**: the native Rust runtime.
- **[Building and Integrating](building.md)**: Make, CMake and build-system
  integration.

## Quick reference

```c
{ /* global C code */ }

${declare longest_match}                 // declarations
${pass sym for_all postorder}

start: rule1 | rule2 ;                   // first production is the start symbol

rule1
  : 'literal' "[a-z]+" other*            // strings, regexes, nonterminals, EBNF
      [ /* speculative action */ ]
      { /* final action: $$ $0 $n0 ${scope} ${state} ... */ }
  | other '+' other $left 10             // rule priority and associativity
  | ( other ',' )+ other?                // grouping, +, ?
  | 'x'@2:4                              // bounded repetition
  ;

op: '*' $binary_op_left 20 ;             // operator priority
ident: "[a-z]+" $term -1 ;               // terminal priority
kw: 'begin'/i ;                          // case-insensitive terminal
digits ::= "[0-9]" + ;                   // regex production (one terminal)

whitespace: "[ \t\n]*" ;                 // optional whitespace subgrammar
_: { /* default final action */ } ;      // default actions
```
