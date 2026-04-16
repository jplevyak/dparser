# Ambiguity Resolution in DParser

DParser handles structural ambiguities within the parse forest dynamically at runtime. When multiple valid reduction trees (`D_ParseNode` structures) occupy the exact same spatial bounds from the source text, DParser attempts to deterministically resolve the ambiguity using a configurable hierarchy of heuristics.

These heuristics can be controlled via the configuration options stored in the `D_Parser` struct, and as a final fallback, you may manually intercede through a user-defined `ambiguity_fn`.

## Core Disambiguation Options

The progression of automatic ambiguity resolution is controlled via the following flags on the `D_Parser` struct. They cascade sequentially until a resolution is reached (unless specifically disabled):

### 1. Deep Priorities (`dont_use_deep_priorities_for_disambiguation`)
* **Default:** `0` (False/Enabled)
* **Behavior:** When enabled, DParser bypasses simple top-node priority checks and recursively crawls down the branches of ambiguous AST variants. It isolates identical subtrees and strictly evaluates the differing divergent paths. It resolves the ambiguity by prioritizing the tree branch containing operators with the mathematically strongest explicit priorities or specific associativities. 
* **Usefulness:** Very High. Explicit operator precedence mapping natively scales across deep recursive trees, resolving mathematical sequences safely without manually writing layered context-free grammars.

### 2. Greediness (`dont_use_greediness_for_disambiguation`)
* **Default:** `0` (False/Enabled)
* **Behavior:** If priorities do not resolve the conflict, DParser falls back to the greediness heuristic. Greediness evaluates the differing leaf bounds of each ambiguous tree path. It favors the earliest bounding start position, followed by explicit lexicographical reduction matching, and finally prioritizes whichever node extends to a larger span length.
* **Usefulness:** High. Greediness fundamentally enforces general "Longest Match" semantics required in token evaluations globally when explicit user priorities are unmapped.

### 3. Tree Height (`dont_use_height_for_disambiguation`)
* **Default:** `0` (False/Enabled)
* **Behavior:** Finally, DParser compares the physical recursion height of the sub-structures. The algorithm prefers the "flatter" tree requiring the fewest reductions.
* **Usefulness:** Moderate. Effectively prevents infinite expansion loops caused by cyclical cascading epsilon rules.

---

## User-Defined Ambiguity Function (`ambiguity_fn`)

If all internal fallback resolutions fail—leaving identical, completely ambiguous internal parses spanning identical layouts—DParser allows you to intercept the node selection programmatically using a custom `ambiguity_fn`.

### Signature
```c
typedef struct D_ParseNode *(*D_AmbiguityFn)(struct D_Parser *dp, int n, struct D_ParseNode **v);
```

### Usage
You can inject your interceptor immediately after instantiating DParser:
```c
D_Parser *parser = new_D_Parser(&parser_tables_gram, SIZEOF_MY_PARSE_NODE);
parser->ambiguity_fn = my_custom_ambiguity_function;
```

### Parameters
* `dp`: A pointer to your current `D_Parser` state struct.
* `n`: An integer count defining exactly how many ambiguous equivalent branches structurally collided.
* `v`: An array of `D_ParseNode *` pointes representing the roots of the `n` parallel ambiguity variations.

### Behavior
Your custom disambiguation function handles inspection on the varying node layouts. You must evaluate the nodes inside `v[0]` up through `v[n-1]`.
* **Return Value:** Return the precise `D_ParseNode *` from `v` that you've determined is the "correct" parse logic to preserve.
* The remaining unselected nodes (and uniquely attached properties beneath them) are safely scavenged and freed by the DParser runtime block, collapsing your tree securely into a deterministic single-flow structure.

---

## Stack Path Protection (`check_path_priorities`)

DParser implements the Generalized LR (GLR) algorithm, which allows parallel parsing threads when conflicts arise. However, for operator-heavy expression grammars, ambiguities can cause an exponential explosion of parallel states in the Graph-Structured Stack (GSS).

DParser mitigates this using the `check_path_priorities` routine, which actively prevents mathematically invalid trees from ever being constructed.

### Behavior
Rather than waiting for recursive tree materialization to eliminate invalid branches via `cmp_pnodes`, `check_path_priorities` examines the active linear GLR stack path directly across the `ZNode` traversal links.
* **Early Pruning:** When a new reduction is theorized, the stack's mathematical relationships are tested. `check_path_priorities` validates the proposed path sequences against an optimized `O(1)` constant-time lookup matrix (`child_table`).
* **Priority Matching:** The matrix explicitly evaluates parent-to-child operator combinations, indexing them by their user-defined numerical absolute priority and associativity properties (evaluating `<, >, =LL, =LR, =RL, =RR`).
* **Effectiveness:** If the structure breaks sequence (e.g., trying to parse a `+` node tighter beneath a `*` node without explicit grouping), the path is rejected (`-1`) prior to instantiation. DParser instantly kills the speculative parsing thread.

This achieves massive algorithmic efficiency, guaranteeing that hardware memory is never wasted generating logically broken syntax structures within deeply recursive grammars.
