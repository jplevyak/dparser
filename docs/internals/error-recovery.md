# Error Recovery

A scannerless GLR parser can't use the usual recovery methods, which
assume one stack and a token stream. DParser uses a simple scheme that
works well for C-like languages: on an error, it pretends that the
innermost suitable construct ended at the next occurrence of its closing
string, and continues from there.

## Recovery hints

When the tables are built, `build_error_recovery()` in `lr.c` looks at
every item in every state. For an item in a rule that **has more than one
element and ends with a string terminal**, such as

```c
statement: expression . ';'
block:     '{' statement* . '}'
```

the state records a hint: the closing string (`;`, `}`), the rule's
symbol, and the *depth*, the number of elements before the dot. If a
state has several items with the same closing string, the smallest depth
is kept.

## At run time

When no parse can continue (there are no pending shifts and no accept),
`error_recovery()` runs:

1. **Report.** The error location (the furthest position reached) is
   stored in `parser->loc`. If this is a new line, `syntax_errors` is
   incremented and `syntax_error_fn` is called, so cascading errors on the
   same line are reported once. If `error_recovery` is off, the parse
   fails here.
2. **Search.** Starting from the SNodes at the furthest position, the
   stack graph is searched backwards, breadth first. For each state with
   recovery hints, the remaining input is searched for each hint's closing
   string.
3. **Choose.** The best candidate is the one whose closing string occurs
   **earliest** in the input. Ties go to the deeper stack, then to the
   hint with the larger depth.
4. **Repair.** A synthetic parse node is created that covers the input
   from the error to just after the closing string, and a synthetic
   reduction combines it with the `depth` elements already on the stack
   into the hint's symbol. For `statement: expression ';'` with the
   expression partly parsed, the result is a `statement` covering
   everything up to and including the next `;`.
5. **Continue.** Parsing resumes after the closing string.

The synthesized node is marked as evaluated, so its final action never
runs. Its children that were parsed correctly before the error keep
their values.

If no hint matches anywhere in the remaining input, the parse fails.

## Designing for recovery

- Rules that end in a literal string are recovery points. Statements
  ending in `;` and blocks ending in `}` give good recovery.
- The closing string is found with a plain text search, so it may be
  found inside a string literal or comment. In practice this rarely
  matters.
- Rules that end in a regex or a nonterminal are not recovery points.

## Right epsilon hints

The other hints computed by `lr.c` are not about errors but about
efficiency. For an item where everything after the dot is nullable, such
as `A: B . C D` with `C` and `D` able to match nothing,
`build_right_epsilon_hints()` records the rule, the number of remaining
symbols and the state reached after them.

At run time, when `goto_PNode()` reaches a state through a non-terminal
(not a shift), it checks the state's hints. For each one it finds the
SNode where the rule started and queues the reduction of `A` directly,
pruned to paths through the new state. Without the hint the parser would
first have to reduce the empty `C` and `D` one at a time, creating
intermediate states and nodes for each.
