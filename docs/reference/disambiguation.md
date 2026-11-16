# Priorities and Disambiguation

DParser accepts ambiguous grammars. It resolves ambiguity at parse time,
using priorities you give in the grammar, then built-in rules, then a
function you can supply.

Priorities are integers from `INT_MIN` to `INT_MAX`. A higher number means
a higher priority (binds tighter).

## Terminal priorities

`$term N` after a terminal sets its terminal priority (default 0). When
several terminals match exactly the same text in a state, only those with
the highest priority are kept:

```c
identifier: "[a-z]+" $term -1 ;   // keywords (priority 0) win over identifiers
```

See [Terminals](terminals.md#terminal-priorities).

## Rule priorities

A rule priority applies to the reduction itself, and is written after the
rule's elements:

```c
E: E '+' E $left 10
 | E '*' E $left 20
 | '-' E   $right 30
 | E '^' E $right 40
 ;
```

| Modifier | Meaning |
|---|---|
| `$left N` | Priority `N`, left associative. |
| `$right N` | Priority `N`, right associative. |
| `N` | Priority `N`, no associativity. |

Whether the rule is unary or binary is inferred from the rule. Older
grammars may spell it out with `$unary_left`, `$unary_right`,
`$binary_left` or `$binary_right`. These are equivalent:

```c
E: '-' E $right 1 | E '+' E $left 2 ;
E: '-' E $unary_right 1 | E '+' E $binary_left 2 ;
```

## Operator priorities

Because there is no global tokenizer, an operator's priority can't be
attached to a token as in yacc's `%left`. Instead it is attached to the
*reduction that produces the operator*, and records how the operator is
used:

```c
E: ident op ident ;
op: '*' $binary_op_left 2
  | '+' $binary_op_left 1
  ;
```

| Modifier | Meaning |
|---|---|
| `$unary_op_left N` | A unary operator, left associative. |
| `$unary_op_right N` | A unary operator, right associative. |
| `$binary_op_left N` | A binary operator, left associative. |
| `$binary_op_right N` | A binary operator, right associative. |

[External scanners](terminals.md#external-scanners) can also return
operator priorities for the terminals they match.

Rule and operator priorities can be mixed. They are interpreted at parse
time, not when the tables are built. `make_dparser -p` (or
`${declare set_op_priority_from_rule}`) copies each rule's priority onto
the last terminal of the rule as an operator priority.

## How ambiguity is resolved

Priorities are used in two places.

**While parsing**, before a reduction is made, DParser checks it against
the priorities and associativities of adjacent operators. A reduction that
would put a lower-priority operator directly beneath a higher-priority one
(for example, an unparenthesized `+` as an operand of `*`) is never built.
This is what keeps operator-heavy grammars efficient. See
[Disambiguation internals](../internals/disambiguation.md).

**When two different parses of the same nonterminal cover exactly the
same text**, they are compared by the following rules, in order. The first
rule that prefers one parse decides:

1. **Priorities.** If both parses involve rules or operators with
   priorities, the nodes that are not shared between the two trees are
   compared: sorted by least height, then highest priority, then earliest
   start, and compared pairwise. The first difference decides, in favor of
   the higher priority. This follows the intuition that higher-priority
   rules should be resolved first. In unusual grammars, where many parses
   are possible and a distant high-priority reduction is involved, the
   result can be surprising; restructuring the grammar fixes that.
2. **Greediness.** The unshared nodes are compared from left to right; at
   the first position where both trees have a node for the same symbol,
   the longer node wins. This settles the dangling `else` the usual way and
   tends to favor right-nested parses.
3. **Height.** The parse tree with less height wins.

If none of these decide, both parses are kept as an ambiguity. When the
parser later commits to that part of the tree:

4. **Empty subtrees without actions** that are ambiguous are merged
   silently, since the choice can't matter.
5. **The ambiguity function** `parser->ambiguity_fn` is called with the
   alternatives and returns the one to keep. The default function
   aborts with `unresolved ambiguity`, after printing the alternatives if
   `d_verbose_level` is set.

### Options

These `D_Parser` fields turn rules off:

| Field | Effect |
|---|---|
| `dont_use_deep_priorities_for_disambiguation` | Skip rule 1. |
| `dont_use_greediness_for_disambiguation` | Skip rule 2. |
| `dont_use_height_for_disambiguation` | Skip rule 3. |
| `dont_merge_epsilon_trees` | Skip rule 4. |
| `dont_compare_stacks` | Disable an optimization that prunes some parse stacks early using operator priorities; it handles some cases that would otherwise be exponential. |

## Writing an ambiguity function

```c
typedef struct D_ParseNode *(*D_AmbiguityFn)(struct D_Parser *p, int n,
                                             struct D_ParseNode **v);
```

The function receives the `n` alternatives in `v` and must return one of
them. The rest are freed. The alternatives' final actions have not run
yet, so choose by looking at the trees: their symbols, children and text.

```c
static D_ParseNode *pick_first(D_Parser *p, int n, D_ParseNode **v) {
  return v[0];
}
...
parser->ambiguity_fn = pick_first;
```

`dparse.h` also declares `resolve_amb_greedy(parser, n, v)`, which applies
the greediness and height rules to the alternatives and returns the index
of the one they prefer.

## Debugging ambiguity

To see where a grammar is ambiguous:

1. Set `d_verbose_level = 1` (declare it `extern int d_verbose_level;`).
2. Turn off greediness and height so they don't hide ambiguities.
3. Parse a sample input. The default ambiguity function prints each
   alternative fully parenthesized, then stops:

    ```text
    (( 1  -  2 ) -  3 )
    ( 1  - ( 2  -  3 ))
    fail: unresolved ambiguity line 1 file (null)
    ```

See also the [Ambiguity tutorial](../tutorial/ambiguity.md).
