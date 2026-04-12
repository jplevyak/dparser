# GLR Ambiguity & Error-Recovery Runtime Mechanics

The native `lr.c` generator builds highly specialized internal lookahead mappings specifically intended to optimize the GLR behavior within `parse.c`. The two most foundational optimization models built into states natively are the `right_epsilon_hints` and `error_recovery_hints`.

## 1. Right Epsilon Shortcuts (`right_epsilon_hints`)

### The Problem
In standard GLR compiling architectures, a "nullable" rule path (where a rule eventually reduces down to completely empty/epsilon characters) generates massive computational headaches. If you have $A \rightarrow B C D$ and $C, D$ evaluate to $\epsilon$, a standard GLR algorithm spawns empty parallel parser branch threads traversing through the empty blocks iteratively doing useless state transitions just to ultimately reduce the node. 

### The Hint's Purpose (in `lr.c`)
During state compilation (`build_right_epsilon_hints`), if the generator encounters an LR `Item` where all remaining trailing tokens in the parsing layout natively evaluate to `ELEM_NTERM` configurations mathematically mapped as `nullable`, it explicitly attaches a `right_epsilon_hints` flag pointing mathematically backwards from the expected finished subset state.

### Runtime Utilization (in `parse.c`)
Inside the transition tracing block `goto_PNode()` (around line `1125`), these hints are consumed seamlessly. 
If a new target stack node (`new_ps`) encounters parsing sequences possessing no explicit terminal shifts (`!pn->shift`), the runtime immediately looks at the state's `right_epsilon_hints` vector. It looks backwards recursively locating the parent node where the epsilon chain started (`pre_ps`), and pushes an explicit immediate reduction command backwards onto the parent stack pointer directly manually:
```c
Reduction *r = add_Reduction(p, pre_ps->zns.v[k], pre_ps, h->reduction);
```
This forcibly closes the parser bracket bypassing thousands of empty $O_a \rightarrow O_b$ thread instantiations.

---

## 2. Token Graph Resynchronization (`error_recovery_hints`)

### The Problem
When parallel parser algorithms crash on unmatched syntax boundaries, standard deterministic parsers fully break. GLR structures contain numerous branching realities dynamically, meaning standard recovery implementations (just dropping characters until the code looks recognizable) do not mathematically cleanly splice onto split parsing trees.

### The Hint's Purpose (in `lr.c`)
`build_error_recovery` searches all compiled internal rules explicitly matching layouts terminating exclusively onto hardcoded `TERM_STRING` terminals (for example, rules terminating explicitly at a literal `";"` or `"}"`). It attaches the expected character string natively onto the active `Item` depth state map, passing the expected synchronization payload natively to the states.

### Runtime Utilization (in `parse.c`)
During runtime, if an error is caught natively dropping all possible LR threading queues into the void, `dparser` invokes `do_error_recovery` (around `1680`). 
It pools *all* active `SNode` branch edges out of the `snode_hash` block and runs a broad heuristic scan evaluating active recovery flags locally.
1. It queries any existing node containing `sn->state->error_recovery_hints`.
2. It launches an independent `find_substr(s, er->string)` sweep natively out across the unparsed character terminal streams searching for the hint token (e.g. `";"`).
3. If it discovers the matched token, it compares recursive branching depths across the active valid pointers natively parsing that literal depth. 
4. The system forcibly elects the state holding the tightest structural root graph bindings locally (`best_sn->depth < sn->depth`) and forcefully splices the token root over to intercept standard parsing naturally. 
