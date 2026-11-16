# Scanning

DParser has no global lexer. Each parse state has its own scanner, which
recognizes only the terminals that can be shifted in that state.

## Building a state's scanner

For each state with shift actions, `lex.c` builds a nondeterministic
automaton (NFA) for all of the state's terminals at once:

- **Strings** are added as a trie, character by character (both cases
  for `/i`).
- **Regular expressions** are compiled by `build_regex_nfa`, which handles
  grouping, alternation, character classes, `?`, `*`, `+` and the trailing
  context operator `/`.

The NFA is converted to a DFA by subset construction. Each DFA state
records which terminals are *accepted* there. Identical scanners are
shared between parse states.

To keep the tables small, a DFA state's transition table (256 entries) is
split into blocks (`make_dparser -b`, default 4). Identical blocks are
stored once. Depending on the number of DFA states, the entries are 8, 16
or 32 bits wide.

## Running a scanner

`scan_buffer()` (in `scan.c`) runs a state's DFA from the current
position for as long as there are transitions. It records:

- the terminals accepted at the **last accepting DFA state**, the longest
  match, and
- through a precomputed per-transition table (`accepts_diff`), every
  terminal that was accepted at a **shorter** length and is no longer
  accepted after the next character.

So a single pass finds *every* terminal that matches at the current
position, at every length. For example, in a state where both `'a'` and
`'ab'` are valid, the input `abc` yields both. Each becomes a separate
shift, and the GLR parser follows both.

The DFA stops at a byte with no transition. Positions at or beyond the
end of the input read as `'\0'`, which never has a transition, so the
scanner never reads past the buffer.

## Filtering matches

The results are filtered before shifting:

1. **Longest match.** If the state's scan kind is `D_SCAN_LONGEST`
   (`make_dparser -l` or `${declare longest_match}`), only the longest
   matches are kept. `D_SCAN_MIXED` states, which mix longest-match and
   all-match terminals, apply this per terminal.
2. **Trailing context.** A regex with `/`, such as `"ab/c"`, produces two
   accepts: one at the end of the context, and a marker at the `/`. The
   marker is kept and the full match is dropped, so the terminal ends
   before the context.
3. **Terminal priorities.** Among matches that end at the same position,
   those with a lower `$term` priority are discarded. Matches of different
   lengths are all kept.

## External scanners

A state that can shift an `${scan fn}` terminal, or any state in a grammar
with `${scanner fn}`, has a generated `scanner_code` function. It is
called before the table-driven scanner, and its results are added to the
same list.

## Whitespace

Whitespace is skipped *after* a terminal is shifted, when the new parse
state is created. This allows the whitespace handling to depend on which
terminal was just recognized. For instance, the Python grammar uses this
for implicit line joining inside brackets.

With a `whitespace` production, the whitespace is skipped by a second,
nested parser that uses the same tables starting from the `whitespace`
production's start state. It runs a partial parse, and the position it
reaches is where the main parse continues.

## Tokenizers

In a *tokenizer* state, the scanner is built from the terminals of **all**
states covered by the tokenizer declaration, not only those valid in the
current state. Matches that the current state can't use cause that parse
path to fail. This mimics a traditional lexer, where reserved words are
never identifiers.
