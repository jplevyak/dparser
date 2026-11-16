# 4. Ambiguity

A grammar is *ambiguous* when some input can be parsed in more than one
way. Most parser generators reject such grammars when the tables are
built. DParser accepts them: as a GLR parser it explores every
alternative, and when two alternatives cover exactly the same text it
chooses between them at parse time.

## Ambiguity without priorities

Take the calculator from [chapter 1](calculator.md) and remove the
`$left` and `$right` priorities. Now `1 - 2 - 3` has two parses,
`(1 - 2) - 3` and `1 - (2 - 3)`. The parser does not complain. It quietly
picks one:

```console
$ ./calc "1 - 2 - 3"
1 - 2 - 3 = 2
```

The answer is 2, so it chose `1 - (2 - 3)`. The rule that decided was
*greediness*, described below. It produced a valid parse, but not the one
we want, which is why the calculator gives its rules priorities.

## How DParser chooses

When alternatives cover the same text, DParser applies these rules in
order until one of them decides:

1. **Priorities and associativity.** Rule and operator priorities
   (`$left 10`, `$binary_op_left 2` and so on) are compared, both where
   the operators are adjacent and deeper inside the competing trees. This
   settles most expression grammars.
2. **Greediness.** Compare the parts of the two trees that differ, from
   left to right. At the first position where both have a node for the
   same symbol, prefer the longer node. In effect this favors right-nested
   parses: `1 - (2 - 3)` beats `(1 - 2) - 3`. It is also what makes the
   dangling `else` below come out the usual way.
3. **Height.** Prefer the parse tree with less depth.
4. **Your `ambiguity_fn`.** If nothing else decides, the parser calls the
   function in `parser->ambiguity_fn` with the alternatives. The default
   function stops with a fatal error.

Rules 2 and 3 can be turned off with the `dont_use_greediness_for_disambiguation`
and `dont_use_height_for_disambiguation` parser options. The details are in
[Priorities and Disambiguation](../reference/disambiguation.md).

## Seeing the alternatives

To see an ambiguity that the heuristics would otherwise hide, turn them
off. The default ambiguity function then stops the parse:

```c
p->dont_use_greediness_for_disambiguation = 1;
p->dont_use_height_for_disambiguation = 1;
```

```console
$ ./calc "1 - 2 - 3"
fail: unresolved ambiguity line 1 file (null)
```

If you also set the global `d_verbose_level` to 1 (declared
`extern int d_verbose_level;`), it prints each alternative fully
parenthesized first:

```text
(( 1  -  2 ) -  3 )
( 1  - ( 2  -  3 ))
fail: unresolved ambiguity line 1 file (null)
```

This is the quickest way to find out where a grammar is ambiguous.

## The dangling else

The classic ambiguity is the dangling `else`:

```c
stmt
  : 'if' cond 'then' stmt
  | 'if' cond 'then' stmt 'else' stmt
  | "[a-z]"
  ;
cond: "[A-Z]" ;
```

In `if A then if B then x else y`, the `else` could belong to either `if`.
Greediness attaches it to the nearest one, as most languages require:

```text
( if  A  then ( if  B  then  x  else  y ))
```

## Choosing with your own function

You can make the choice yourself. An ambiguity function receives the
alternative nodes and returns the one to keep. The alternatives' final
actions have not run yet, so decide from the shape of the trees. This
function picks the alternative with the fewest children. At the top level
that is the `if`/`then` without an `else`, so the `else` goes to the inner
`if`:

```c
static D_ParseNode *choose(D_Parser *p, int n, D_ParseNode **v) {
  D_ParseNode *best = v[0];
  for (int i = 1; i < n; i++)
    if (d_get_number_of_children(v[i]) < d_get_number_of_children(best))
      best = v[i];
  return best;
}
...
p->dont_use_greediness_for_disambiguation = 1;  /* so our function is asked */
p->ambiguity_fn = choose;
```

```text
stmt  if A then if B then x else y.
    if  if.
    cond  A.
    then  then.
    stmt  if B then x else y.
        ...
        else  else.
        stmt  y.
```

## Ambiguities that change the symbol table

If the alternatives' [speculative actions](speculative-actions.md) leave
the symbol table in different states, DParser keeps them as separate parse
paths rather than merging them. Each continues with its own symbol table.
If more than one reaches the end of the input, they are presented to your
ambiguity function together at the top of the tree.

## What you learned

- DParser accepts ambiguous grammars and resolves ambiguity at parse time.
- Priorities decide first, then greediness, then tree height, then your
  `ambiguity_fn`.
- Greediness and height can silently pick a parse you didn't intend. Turn
  them off temporarily, with `d_verbose_level` set, to find ambiguities.

Next: [Speculative Actions](speculative-actions.md).
