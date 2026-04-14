# Examination of `check_path_priorities`

DParser employs Tomita's Generalized LR (GLR) parsing algorithm, managing parallel parses through a Graph-Structured Stack (GSS). When dealing with ambiguous grammars—especially expression grammars mapping mathematical operators—GLR parsers can suffer from exponential parallel branching.

`check_path_priorities` is the critical architectural barrier in DParser mitigating this exponential blowup. It evaluates whether a nascent reduction path is mathematically "legal" based entirely on User-Defined Associativities and Priorities, *before* the invalid parse tree branches are fully allocated.

---

## 1. Purpose

The primary purpose is **early pruning of invalid operator-precedence reductions**. 
When the parsing state encounters a sequence like `A + B * C`, standard LR parsing would rely on explicitly layered grammars to force `*` to bind tighter than `+`. DParser allows "flat" grammars (e.g., `Expr: Expr op Expr`) by letting users assign priority numbers. 

`check_path_priorities` dynamically evaluates the stack dynamically. By determining that adding `+` over `*` violates the strict priority definitions, it strictly returns `-1`, prompting the GLR parser to kill the current parser thread and immediately drop the invalid path preventing Graph Stack explosion.

---

## 2. The Algorithm

### The Target Check (`check_path_priorities` Macro)
The evaluation begins as a fast macro wrapping `check_path_priorities_internal(VecZNode *path)`:
```c
#define check_path_priorities(_p) \
  ((_p)->n > 1 && ((_p)->v[0]->pn->op_assoc || (_p)->v[1]->pn->op_assoc) && check_path_priorities_internal(_p))
```
It only fires if the reduction path is sufficiently deep (`> 1`) and contains at least one node mapped as an operator context.

### Graph Sub-Traversal (`check_path_priorities_internal`)
Due to the parallel nature of GLR, a simple linear stack check isn't always possible. `check_path_priorities_internal` maps across the `VecZNode *` (Z-nodes tracking path links). 
- It isolates up to three sequential targets: `pn0`, `pn1`, and `pn2`.
- If the reduction path doesn't contain all 3 targets linearly, it iterates deep into the underlying GSS (`z->sns.v[...]->zns.v[...]`) fanning out to test the validity of *every possible continuation branch* across the parallel state.

### Priority Matching (`check_assoc_priority`)
The isolated node triplets are sent to `check_assoc_priority` to deduce the relationship contexts:
- Are `pn1` and `pn0` nested operators?
- Is `pn0` an operator, and is `pn2` attempting to consume it?

### The Matrix Evaluator (`check_child` and `child_table`)
The exact mathematical truth value of the reduction relies on `check_child(...)`, which indexes directly into a pre-compiled hardcoded mapping array: `child_table[4][3][6]`.
This table maps:
1. **Parent Operator Type** (Binary, Left Unary, Right Unary, Nary)
2. **Child Operator Type** (Binary, Left Unary, Right Unary, Nary)
3. **Priority Differential & Associativity Overlaps** (`>`, `<`, `=LL`, `=LR`, `=RL`, `=RR`)

The lookup instantly determines whether the structural collision implies a valid reduction step, or if it should be rejected.

---

## 3. Effectiveness

The `check_path_priorities` architecture is **exceptionally effective** at delivering deterministic edge protection against GLR exponential branching complexity.

1. **Memory Security (O(1) Matrix Validation):** The matrix `child_table` yields branch-less, `O(1)` validation logic mapped cleanly outside of deep recursive function loops. This keeps the evaluator exceedingly fast per reduction frame.
2. **Pre-Construction Pruning:** Standard GLR parsers instantiate identical ambiguity trees and rely on post-parse analysis (`cmp_pnodes`) to scavenge invalid trees. `check_path_priorities` blocks the memory allocation entirely, discarding the GLR parallel timeline proactively.
3. **Graph-Tolerant Resolution:** Because the algorithm physically traverses GLR `ZNode` mapping links, its priority logic remains safely accurate even when deeply embedded in dense parallel state branches without leaking unhandled ambiguity collisions.
