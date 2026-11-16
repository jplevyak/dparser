# Table Construction

`make_dparser` turns a grammar into tables in four steps: read the
grammar, expand it into plain BNF, build the LR(0) automaton, and build a
scanner for each state.

## Reading the grammar

The grammar language is itself defined in DParser (`grammar.g`), and
`grammar.g.c` is the parser generated from it. Its actions build the data
structures in `gram.h`:

- a **`Production`** per nonterminal, holding its **`Rule`**s;
- each rule a vector of **`Elem`**s, which are terminals, nonterminals or
  an end marker;
- a **`Term`** per distinct terminal (string, regex, external scanner code
  or token), with its priority, name and flags.

Identical terminals are shared, so `';'` written in ten rules is one
terminal. Terminals with different `$name`s stay distinct, and with
`-p`, so do terminals with different operator priorities.

An augmented start production is added at index 0. Reaching the end of its
rule is what makes a state an *accept* state.

## EBNF expansion

EBNF operators are rewritten into *internal productions*, named after the
production that contains them (`program__2` and so on):

| Construct | Expansion (default, left recursive) |
|---|---|
| `x?` | `P: x \| ;` |
| `x*` | `P: P x \| ;` |
| `x+` | `P: P x \| x ;` |
| `x@n:m` | `P: x...x (n times) \| ... \| x...x (m times) ;` |
| `( a \| b )` | `P: a \| b ;` |
| `{ code }` inside a rule | `P: { code } ;`, an empty rule carrying the action |

With `make_dparser -r`, `*` and `+` use right recursion (`P: x P`)
instead. Left recursion is the default because it keeps the parse stack
shallow.

The internal productions are marked with their kind (`INTERNAL_STAR`,
`INTERNAL_PLUS` and so on). The runtime uses this to flatten their nodes
when committing the tree: a left-recursive chain of `P` nodes becomes one
node with a child per repetition.

[Regex productions](../reference/grammar.md#regex-productions) (`::=`)
are not expanded. Their rules are combined into one regular expression
string and become a single terminal.

## LR(0) states

`lr.c` builds the canonical LR(0) item sets:

1. The start state is the closure of the item for the augmented start
   rule.
2. For each state and each symbol after a dot, the *goto* state is the
   closure of the items with the dot moved past that symbol. States with
   identical item sets are shared through a hash table.
3. If start states are requested (`-A`, `${declare subparser}`, or a
   `whitespace` production), a start state is also built for each such
   production.

The actions for each state are then:

- **shift** for each terminal after a dot;
- **reduce** for each item with the dot at the end, **with no lookahead**;
- **accept** if the augmented start rule is complete.

There is no LALR or LR(1) lookahead computation, and conflicts are not
errors. A state may have several reductions, or shifts and reductions
together; the GLR runtime simply tries all of them. Because scanning is
per state, invalid continuations die out as soon as their next terminal
fails to match.

The goto table is stored compactly: each state has an offset into a
shared table indexed by symbol, with a bit vector saying which symbols
have valid gotos.

## Hints for the runtime

Two kinds of hints are computed per state.

**Right epsilon hints.** If an item is followed only by nullable
nonterminals, as in `A: B . C D` with `C` and `D` both able to match the
empty string, the state records a hint: the rule, how many symbols are
left, and the state that would be reached after them. The runtime uses it
to perform the reduction of `A` immediately without first reducing every
empty `C` and `D`. See [Error Recovery](error-recovery.md#right-epsilon-hints).

**Error recovery hints.** For each item in a rule that ends with a string
terminal, such as `stmt: expr . ';'` or `block: '{' stmts . '}'`, the
state records that string and how far into the rule the item is. These
drive [error recovery](error-recovery.md).

## Scanners

Finally, `lex.c` builds a scanner for each state that has shift actions;
see [Scanning](scanning.md). States with the same set of terminals share
one scanner.

## Writing the tables

`write_tables.c` writes everything as static C data structures, with each
action compiled into a C function. Alternatively, with `-B`, it writes a
relocatable binary image (see [Binary Tables](binary-tables.md)). The
generated names all end in the grammar identifier (`gram` by default), so
several grammars can be linked into one program.

With `make_dparser -v` you can see the number of productions, states and
scanners built.
