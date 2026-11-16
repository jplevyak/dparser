# Grammar Syntax

A DParser grammar file (conventionally `name.g`) contains productions, C
code and declarations, in any order.

## Productions

A production defines a nonterminal. It is the nonterminal's name, a colon,
one or more *rules* separated by `|`, and a semicolon:

```c
statement
  : expression ';'
  | 'if' '(' expression ')' statement
  | '{' statement* '}'
  ;
```

- **The first production in the file is the start symbol**, the thing
  `dparse()` parses. To start from another nonterminal, see
  [Start states](#start-states).
- A nonterminal can be defined by several productions; their rules are
  combined.
- A rule may be empty, which matches the empty string:
  `opt_semicolon: ';' | ;`.
- Nonterminal names are C-like identifiers: `[a-zA-Z_][a-zA-Z_0-9]*`.
- The name `_` is reserved for [default actions](actions.md#default-actions),
  and `whitespace` for the [whitespace subgrammar](declarations.md#whitespace).

## Elements

Each rule is a sequence of elements:

| Element | Example | Meaning |
|---|---|---|
| String | `'while'` | Matches exactly this text. See [Strings](terminals.md#strings). |
| Regular expression | `"[0-9]+"` | Matches the regex. See [Regular expressions](terminals.md#regular-expressions). |
| Unicode character | `U+03C9` | Matches one Unicode code point (written in UTF-8 in the input). |
| Nonterminal | `expression` | Matches that production. |
| Group | `( ',' expression )` | A sub-rule. Groups may contain alternatives: `( 'a' \| 'b' )`. |
| External scanner | `${scan my_fn}` | Calls a C function to match a terminal. See [External scanners](terminals.md#external-scanners). |
| Embedded action | `{ ... }` or `[ ... ]` | Code that runs at that point in the rule. See [Embedded actions](actions.md#embedded-actions). |

Strings and regexes are *terminals*. They may be written directly in
rules; there is no need to declare them.

## EBNF operators

Any element (including a group) can be followed by:

| Operator | Meaning |
|---|---|
| `?` | Optional: zero or one. |
| `*` | Zero or more. |
| `+` | One or more. |
| `@n` | Exactly `n` times. |
| `@n:m` | Between `n` and `m` times. |

```c
program: statement* ;
argument_list: expression ( ',' expression )* ;
date: "[0-9]"@4 '-' "[0-9]"@2 '-' "[0-9]"@2 ;
```

DParser uses `?` for optional elements rather than square brackets,
because square brackets are reserved for speculative actions.

Each EBNF operator and group creates an *internal production* whose node
appears in the parse tree. A repeated element such as `statement*` is a
single child whose own children are the repetitions; see
[Parse Trees](../tutorial/parse-trees.md#internal-nodes-for-ebnf).

By default, `*` and `+` are implemented with left recursion. The
`make_dparser -r` option uses right recursion instead.

## Rule modifiers

After a rule's elements, and before its actions, a rule can have:

- **A priority and associativity**, such as `$left 10`, `$right 30` or
  `$binary_op_left 20`. See
  [Priorities and Disambiguation](disambiguation.md).
- **An external action index**, `${action}` or `${action N}`. This tags
  the rule with a number instead of C code, for runtimes that supply
  their own actions. The Python binding uses it.

## Actions

A rule ends with optional actions, in this order:

```c
rule: elements
  [ speculative action ]
  { final action }
  passname: { pass action }
  ;
```

All are optional. See [Actions](actions.md).

## Global code

C code in braces at the top level of the grammar is copied into the
generated file, in order. Use it for includes, type definitions and helper
functions:

```c
{
#include <stdio.h>
#include "my_types.h"
static int depth = 0;
}
```

The code can also be written between `%<` and `%>`:

```c
%<
#define MAX_DEPTH 100
%>
```

In both forms the code must have balanced parentheses, brackets and
braces (outside strings and comments), because the grammar reader matches
them to find the end of the block.

Code is copied as-is, except for `$` specifiers. Global code may use
`${nterm name}`, `${string text}` and `${pass name}`, which are replaced by
numbers. **Any other `$` in global code is an error**, so avoid `$` in
global code, even inside comments and strings.

## Comments

Grammar files can contain C and C++ comments:

```c
// My first grammar
E: E '+' E | "[abc]";
/* is this right? */
```

## Include

`include "file.g"` reads another grammar file at that point:

```c
include "expressions.g"
```

## Regex productions

A production defined with `::=` instead of `:` is a *regex production*. Its
rules are combined into a single regular expression, so the whole
production becomes one terminal:

```c
number   ::= digit+ ( '.' digit+ )? ;
digit    ::= "[0-9]" ;
```

This is useful for building up complex tokens from named parts. The
restrictions are:

- A regex production can use strings, regexes and other regex productions,
  but not ordinary nonterminals, external scanners or tokens.
- Only a single-rule regex production may have code, and only a
  speculative action.

## Start states

The first production is the start symbol. To be able to start parsing from
other nonterminals as well, ask `make_dparser` to build start states for
them, either for all nonterminals (`make_dparser -A`, or
`${declare all_subparsers}` in the grammar) or for selected ones
(`${declare subparser expression statement}`).

`make_dparser` then writes a header, `name.g.d_parser.h`, that defines
`D_START_STATE_<nonterminal>` for each one. Set the parser's `start_state`
before calling `dparse`:

```c
#include "my.g.d_parser.h"
...
parser->start_state = D_START_STATE_expression;
```

## The grammar of grammars

DParser is self-hosting: the grammar language is itself defined by a
DParser grammar,
[`grammar.g`](https://github.com/jplevyak/dparser/blob/main/grammar.g).
It is the definitive reference for the syntax.
