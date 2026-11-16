# Terminals and Scanning

DParser is *scannerless*: there is no separate tokenizer. In each parse
state, DParser looks for the terminals that can appear in that state, and
only those. A keyword in one place can be an identifier in another, and
terminals can be prefixes of each other or contain spaces.

## Strings

String terminals are written in single quotes and match their text
exactly:

```c
block: '{' statement* '}' ;
loop:  'while' '(' expression ')' block ;
arrow: '->' ;
```

Strings may contain the usual C escapes: `\n`, `\t`, `\r`, `\b`, `\f`,
`\v`, `\a`, `\\`, `\'`, `\"`, octal escapes like `\012`, plus `\xHH`
(hexadecimal) and `\dNNN` (decimal) for arbitrary byte values.

## Regular expressions

Regular expressions are written in double quotes:

```c
identifier: "[a-zA-Z_][a-zA-Z0-9_]*" ;
hexint:     "(0x|0X)[0-9a-fA-F]+[uUlL]?" ;
```

DParser regexes are deliberately simple. The supported operators are:

| Syntax | Meaning |
|---|---|
| `abc` | The literal characters. |
| `( )` | Grouping. |
| `a\|b` | Alternation. |
| `[abc]`, `[a-z]` | A character class, with ranges. |
| `[^abc]` | A negated character class. |
| `x?`, `x*`, `x+` | Optional, zero or more, one or more. |
| `\c` | The character `c` literally, for example `\.`, `\(`, `\[`, `\\`. C escapes such as `\n` and `\t` also work. |
| `x/y` | Trailing context: match `x` only when followed by `y`, without consuming `y`. |

There is **no `.` wildcard**: `.` matches a literal period. Write a class
such as `[^\n]` instead. There are also no anchors (`^`, `$`), no counted
repetition (`{n,m}`) and no character class shorthands (`\d`, `\w`, `\s`).
Use the grammar's `@n:m` operator, or a [regex production](grammar.md#regex-productions),
to build more complex terminals.

The regex compiler is in `lex.c`.

## Unicode

DParser works on bytes, and Unicode text is matched as UTF-8. You can
write UTF-8 characters directly in strings, or name a code point with
`U+` (or `u+`) followed by hexadecimal digits:

```c
phi:   'φ'    ;
omega: U+03C9 ;
```

## Terminal modifiers

A terminal can be followed by modifiers:

| Modifier | Example | Meaning |
|---|---|---|
| `$term N` | `"[a-z]+" $term -1` | Terminal priority `N`. See [below](#terminal-priorities). |
| `$name 'text'` | `',' $name 'arg_comma'` | Give the terminal its own name, so that identical strings used in different roles become different terminals. |
| `/i` | `'select'/i` | Case-insensitive match: `'select'/i` matches `SELECT` and `Select`. Works on strings and regexes. |

`$name` is useful together with `${string name}` in actions, which gives
the symbol number of the named terminal:

```c
call: function '(' arg (',' $name 'arg_comma' arg)* ')' ;
...
if ($n0.symbol == ${string arg_comma}) ...
```

## Terminal priorities

In each state the scanner finds *all* terminals that match at the current
position. If two terminals match exactly the same text, the one with the
higher terminal priority wins and the other is discarded. The default
priority is 0.

The common use is keywords versus identifiers:

```c
statement: 'if' '(' expression ')' statement | identifier '=' expression ';' ;
identifier: "[a-z]+" $term -1 ;
```

Where `if` could be a keyword or an identifier, the keyword (priority 0)
beats the identifier (priority -1). Terminals that match *different*
lengths are all kept, and the parse decides between them. So `iffy`
remains an identifier.

## External scanners

When a terminal is easier to recognize in C, write a scanner function.
There are two kinds.

### Per-terminal scanners: `${scan}`

`${scan fn}` is an element that calls `fn` to match one terminal at that
point in the grammar. It can be mixed freely with ordinary terminals:

```c
{
#include "dparse.h"
#define ASSOC_BINARY_LEFT 0x11  /* see the table below */
int ops_scan(d_loc_t *loc, unsigned char *op_assoc, int *op_priority) {
  if (loc->s[0] == '+') {
    loc->s++;
    *op_assoc = ASSOC_BINARY_LEFT;
    *op_priority = 9500;
    return 1;
  }
  return 0;
}
}

X: '1' (${scan ops_scan} '2')* ;
```

The function receives the current location. If it recognizes a terminal it
advances `loc->s` past it and returns nonzero. It can also set an operator
associativity and priority for the match, so a scanner can return
operators with their precedence. If written as `${scan fn(arg)}`, the
function is called as `fn(arg, loc, op_assoc, op_priority)`.

The associativity values are defined in DParser's internal header
`gram.h`, which is not installed, so define the ones you need yourself:

| Associativity | Value | Grammar equivalent |
|---|---|---|
| none | `0x00` | |
| unary left | `0x09` | `$unary_op_left` |
| unary right | `0x0A` | `$unary_op_right` |
| binary left | `0x11` | `$binary_op_left` |
| binary right | `0x12` | `$binary_op_right` |

### Global scanners: `${scanner}`

`${scanner fn}` replaces the built-in scanner for the whole grammar. The
function is called at every position and reports which terminal it found.
Declare the terminals it returns with `${token ...}`:

```c
{
#include "dparse.h"
#include "my.g.d_parser.h"

int my_scanner(d_loc_t *loc, unsigned short *symbol, int *term_priority,
               unsigned char *op_assoc, int *op_priority) {
  switch (loc->s[0]) {
    case 'a': loc->s++; *symbol = A;  return 1;
    case 'b': loc->s++; *symbol = BB; return 1;
  }
  return 0;
}
}

${scanner my_scanner}
${token A BB}

S: A BB+ ;
```

`make_dparser` writes the token numbers to the header `my.g.d_parser.h`
(as `#define`s, or as an `enum` with `make_dparser -t 1`). The grammar
includes that header in its global code.

## Tokenizers

Normally only the terminals that are valid in the current state are
considered, which avoids most conflicts between keywords and names.
Sometimes the opposite is wanted. In C, for example, reserved words should
never be identifiers, even where an identifier would make sense. A
*tokenizer* considers all terminals at every position, as a traditional
lexer does.

Consider:

```c
S : 'if' '(' S ')' S ';' | 'do' S 'while' '(' S ')' ';' | ident ;
ident: "[a-z]+" $term -1 ;
```

Without a tokenizer, `if ( while ) a ;` is legal: `while` can't start an
`S`, so in that position it is read as an `ident`. With a tokenizer,
`while` is always the keyword, and the sentence is a syntax error.

Turn on a tokenizer for the whole grammar with `make_dparser -T`, or for
part of it with `${declare tokenize nonterminal...}`, which applies to the
states reached from the named nonterminals. This lets a tokenized language
such as C be a subgrammar of a larger one. The parse states are not split,
so the productions covered by different tokenizers must be disjoint.

## Longest match

A traditional lexer resolves overlapping tokens by taking the longest
match. DParser doesn't need this, because it can try both. But it is
available when a language defines its tokens that way:

- `make_dparser -l` turns on longest match for the whole grammar.
- `${declare longest_match nonterminal...}` turns it on for the states
  reached from those nonterminals, and `${declare all_matches
  nonterminal...}` turns it off again for others.
- Without arguments, `${declare longest_match}` and `${declare
  all_matches}` set the default for the whole grammar.

C++ is an example where longest match is wrong: in `List<List<int>>` the
closing `>>` must be read as two `>` tokens.
