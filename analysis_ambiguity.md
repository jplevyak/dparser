# Analysis of Parse Node Disambiguation (`cmp_pnodes`)

DParser handles structural ambiguities within the parse forest dynamically at runtime using `cmp_pnodes` (compare parse nodes). When multiple valid reduction trees (`PNode` structures) occupy the exact same spatial bounds, DParser triggers a resolution hierarchy.

## Overview of Disambiguation Options

The progression of ambiguity resolution is controlled via configurations stored in the `Parser->user` struct parameters. They trigger sequentially unless specifically disabled by the user:

> [!NOTE]
> All fallback checks are dependent on whether the prior check resulted in a tie (returned `0`).

1. **`dont_use_deep_priorities_for_disambiguation`** 
   - *Default:* `False`
   - *Usefulness:* **Very High**. Explicit operator precedence mapping natively scales across deep recursive trees allowing complex mathematical/referential evaluations cleanly without endless grammar permutations.
   - *Completeness:* Exhaustive. It bypasses identical structures recursively mapping unshared leaf/internal nodes directly.
2. **`dont_use_greediness_for_disambiguation`** 
   - *Default:* `False`
   - *Usefulness:* **High**. Acts as the primary mechanism for standard "Longest Match" semantics required in nearly all token mapping when user defined priorities are non-existent.
   - *Completeness:* Highly precise. Defers to earliest bounds start time, then longest overall length, ensuring outer bounds envelope the inner nodes.
3. **`dont_use_height_for_disambiguation`** 
   - *Default:* `False`
   - *Usefulness:* **Moderate**. Flatter trees are favored. Suppresses edge-case infinite loops originating from cyclical cascading epsilon-rule unifications.

---

## Deep Dive: `cmp_priorities`

The `cmp_priorities` logic is mathematically precise, deliberately avoiding simple `$1.priority > $2.priority` single-node comparisons. 

### Algorithm Steps:
1. **Divergence Isolation (`get_unshared_pnodes`)**
   It initializes a priority heap starting symmetrically at `x` and `y`. It recursively extracts the immediate children of the *tallest* available nodes. Identical shared trees between the two states are aggressively culled.
2. **Deterministic Sequence Sorting (`prioritycmp`)**
   The unshared elements of `x` and `y` are independently sorted via `qsort`. 
   The hierarchy strictly favors:
   - The presence of *associativity* (nodes lacking associativity definitions are pushed downwards explicitly).
   - *Smallest Height* (Terminal operators rank higher).
   - *Highest Absolute Priority* integer metric.
   - *Earliest Start Index* pointer in the parsed string.
3. **Comparison Matchup (`compare_priorities`)**
   Moves index by index sequentially across both arrays. The moment iteration `[i]` reveals that `x[i]` has a distinct priority advantage over `y[i]`, resolution completes and the dominating tree survives, stripping out the ambiguous alternative forever.

---

## Deep Dive: `cmp_greediness`

When `cmp_priorities` is disabled or results in a tie across trees possessing identical structural priority footprints, `cmp_greediness` executes to break the tie utilizing span size.

### Algorithm Steps:
1. **Divergence Isolation (`get_unshared_pnodes`)**
   It repeats the exact same maximal unsharing extraction utilized by priorities to isolate subtrees efficiently.
2. **Greediness Sequencing (`greedycmp`)**
   Unshared elements are sorted primarily traversing positional layout:
   - Favors earlier starting string indices.
   - Determines deterministic precedence by mathematical symbol ID sequence.
   - Favors the *Longest Ending Bounds*.
3. **Comparison Matchup (`cmp_greediness` loop)**
   Steps across arrays mapping mismatches.
   - *Lexicographical Bounds Wins*: Earliest `start_loc` wins immediately.
   - *Longest Maximal Extent Wins*: Whichever node extends further in bounds terminates resolution recursively.
   - *Fewest Children Win*: If the nodes identically envelope boundaries equivalently, the node requiring the fewest child sub-allocations prevails.

### Completeness Analysis
The ambiguity resolution in DParser provides near-complete safety for virtually all recursive parsing cases. The separation of `get_unshared_pnodes` into a deterministic heap isolation pipeline ensures that exponential tree derivations parse in polynomial runtime envelopes by explicitly truncating any branches functionally identical across ambiguous unifications.
