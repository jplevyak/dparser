# Speculative Parsing Architecture in DParser

## Overview

DParser implements a **GLR (Generalized LR)** parser using the **Tomita algorithm** with a **Graph-Structured Stack (GSS)**. This architecture enables parsing of ambiguous grammars by exploring multiple parse paths simultaneously and resolving ambiguities after the fact.

The key innovation is **speculative parsing**: actions (shifts and reductions) are executed immediately on all parse paths, even when the parser is uncertain which path is correct. Once ambiguity is resolved, final actions are executed on the successful parse path(s).

---

## GLR Parsing Fundamentals

### Traditional LR Parsing Limitations

Traditional LR parsers (LR(0), SLR, LALR, LR(1)) require:
- **Deterministic grammar**: No shift/reduce or reduce/reduce conflicts
- **Single parse path**: Only one valid interpretation at any point
- **Immediate disambiguation**: Conflicts must be resolved via lookahead

Many practical grammars are **inherently ambiguous** or have local ambiguities that resolve later. Traditional LR parsers cannot handle these grammars.

### GLR Solution: Parallel Parsing

GLR parsers handle ambiguity by:
1. **Exploring all possibilities**: When multiple actions are valid, pursue all of them
2. **Graph-Structured Stack**: Share common stack prefixes across parse paths
3. **Deferred resolution**: Continue parsing until ambiguity resolves naturally
4. **Post-parse disambiguation**: Use priorities, associativity, or semantic actions to choose

---

## Graph-Structured Stack (GSS)

### Traditional Stack vs GSS

**Traditional LR Stack:**
```
[state0] → [state1] → [state2] → [state3]
   ↑
  TOP
```
Single linear stack, one parse state.

**Graph-Structured Stack:**
```
         → [state2a] → [state4]
        /                ↑
[state0] → [state1] ─────┘
        \
         → [state2b] → [state5]
```
Multiple parse paths share common prefixes, multiple active parse states.

### GSS Properties

1. **Sharing**: Common stack prefixes are shared across paths
2. **Compactness**: Exponentially many parse paths in polynomial space
3. **Efficiency**: Avoids duplicate work on shared portions
4. **Merging**: Paths that reach the same state merge automatically

### GSS Nodes

Each GSS node represents:
- **Parser state**: LR state number
- **Symbol**: Grammar symbol that led to this state
- **Parents**: Zero or more parent nodes (multiple incoming edges)
- **Semantic value**: Result of reductions at this node

**Key insight**: When paths converge to the same state with the same lookahead, they share the GSS node.

---

## Speculative Actions in DParser

### Action Types

DParser distinguishes between two types of actions:

1. **Speculative Actions** (Square brackets `[]`)
   - Executed **immediately** during parsing
   - Run on **all active parse paths** simultaneously
   - May execute on paths that will later be discarded
   - Used for building symbol tables, setting up parse state

2. **Final Actions** (Curly braces `{}`)
   - Executed **after** parsing completes
   - Run only on **successful parse path(s)**
   - Guaranteed to execute on valid parse trees
   - Used for code generation, final semantic analysis

### Syntax in Grammar Files

```yacc
expression
  : identifier '=' expression
  [ // SPECULATIVE ACTION
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    s = UPDATE_D_SYM(s, &${scope});
    s->user.value = $2.value;
  ]
  { // FINAL ACTION
    printf("Assignment: %s = %d\n", get_sym_name($0), $2.value);
  }
  ;
```

### Execution Model

#### Phase 1: Speculative Parsing

```
Input: a = b + c

Parser explores multiple interpretations:
  Path A: (a) = (b + c)         [assignment]
  Path B: (a) = (b) + (c)       [invalid: a=b then +c]
  Path C: ambiguous reduction

For EACH path:
  1. Execute speculative actions []
  2. Update symbol table for that path
  3. Continue parsing
  4. Paths may merge, split, or terminate
```

#### Phase 2: Ambiguity Resolution

```
After consuming input:
  - Apply priorities and associativity
  - Eliminate invalid parse trees
  - May result in 0, 1, or multiple valid trees
```

#### Phase 3: Final Actions

```
For each successful parse tree:
  1. Walk the parse tree
  2. Execute final actions {}
  3. Produce output
```

### Why Immediate Speculative Actions?

**Problem**: Symbol table must be updated during parsing to handle:
- **Context-sensitive lexing**: Keywords vs identifiers
- **Type-dependent parsing**: Cast vs multiplication in C: `(type)*ptr` vs `(expr)*ptr`
- **Scope-dependent resolution**: Variable shadowing, nested declarations

**Solution**: Execute speculative actions immediately so:
- Symbol table reflects all possible parse states
- Later parsing decisions can query symbol table
- Each parse path has its own symbol table view

---

## Symbol Table Support for Speculative Parsing

The dsymtab symbol table is specifically designed to support GLR speculative parsing.

### Key Design Features

#### 1. Scope Tree Structure

```
Global Scope (shared)
  ├─ Function Scope A (path 1)
  │   └─ Block Scope A1 (path 1)
  │
  ├─ Function Scope B (path 2)
  │   └─ Block Scope B1 (path 2)
  │
  └─ Merged paths create DAG, not tree
```

Each parse path maintains its own scope chain while sharing common base scopes.

#### 2. Symbol Updates List

Symbols can have multiple versions:

```c
Original Symbol: x = 1
  ↓
Update A: x = 2  (path 1)
  ↓
Update B: x = 3  (path 1, later)

Update C: x = 5  (path 2)
```

Each parse path sees its own version via the `updates` list.

#### 3. Speculative Scope Creation

```c
D_Scope *enter_D_Scope(D_Scope *current, D_Scope *scope)
```

Creates a new scope **instance** for a parse path without modifying the original scope. Multiple paths can "enter" the same scope with different speculative states.

```
Original Scope: { int x; }
                    ↓
    ┌───────────────┴───────────────┐
    ↓                               ↓
Path A Scope                    Path B Scope
{ int x;                        { int x;
  x = 1; }                        x = 2; }
```

#### 4. Update Tracking

```c
typedef struct D_Sym {
  char *name;
  int len;
  unsigned int hash;
  struct D_Scope *scope;
  struct D_Sym *update_of;    // Points to original symbol
  struct D_Sym *next;         // Next in hash chain or updates list
  D_UserSym user;             // User-defined semantic value
} D_Sym;
```

- `update_of`: Links updated symbol to original
- Enables finding "current version" for a parse path
- Forms a chain: original → update1 → update2 → ...

### Symbol Table Operations for Speculative Parsing

#### Creating Speculative Parse Path

```c
// Parser discovers ambiguity, splits into two paths
D_Scope *path1 = enter_D_Scope(current_scope, current_scope);
D_Scope *path2 = enter_D_Scope(current_scope, current_scope);

// Each path has independent view of symbol table
// but shares base scopes
```

#### Updating Symbol on Parse Path

```c
// Find symbol (may be in parent scope)
D_Sym *var = find_D_Sym(path1, "x", NULL);

// Update creates NEW symbol version for this path
var = UPDATE_D_SYM(var, &path1);  // path1 is updated!
var->user.value = 42;

// Path 2 still sees original value
D_Sym *var2 = find_D_Sym(path2, "x", NULL);
// var2->user.value is original
```

#### Finding Current Symbol Version

```c
// On path1, get current version of symbol
D_Sym *current = current_D_Sym(path1, original_sym);
// Returns the most recent update visible on path1

// On path2, same call returns different version
D_Sym *current2 = current_D_Sym(path2, original_sym);
// Returns version visible on path2
```

#### Committing Successful Parse Path

```c
// Parser resolves ambiguity, path1 is successful
D_Scope *final_scope = commit_D_Scope(path1);

// Collapses all updates into global hash table
// Optimizes future lookups
// Discards failed parse paths
```

---

## Speculative Parsing Example

### Grammar with Ambiguity

```yacc
expression
  : identifier ':' expression
  [ // Speculative: Declare new variable
    D_Sym *s = NEW_D_SYM(${scope}, $n0.start_loc.s, $n0.end);
    s->user.value = $2.value;
  ]
  | identifier '=' expression  
  [ // Speculative: Update existing variable
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    s = UPDATE_D_SYM(s, &${scope});
    s->user.value = $2.value;
  ]
  | identifier
  [ // Speculative: Reference variable
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    if (s) $$.value = s->user.value;
  ]
  ;
```

### Parsing Sequence: `a:1; a; a=2; a;`

#### Step 1: Parse `a:1`

```
Input: a:1

Parser State:
  - Single path initially
  - Recognizes identifier 'a'
  - Sees ':' 
  - Matches: identifier ':' expression

Speculative Action:
  D_Sym *s = NEW_D_SYM(global_scope, "a", NULL);
  s->user.value = 1;

Symbol Table:
  Global: { a=1 }
```

#### Step 2: Parse `a`

```
Input: a

Parser State:
  - Matches: identifier
  
Speculative Action:
  D_Sym *s = find_D_Sym(global_scope, "a", NULL);
  if (s) $$.value = s->user.value;  // $$.value = 1

Symbol Table:
  Global: { a=1 }
  
Result: 1
```

#### Step 3: Parse `a=2`

```
Input: a=2

Parser State:
  - Recognizes identifier 'a'
  - Sees '='
  - Matches: identifier '=' expression

Speculative Action:
  D_Sym *s = find_D_Sym(global_scope, "a", NULL);
  s = UPDATE_D_SYM(s, &global_scope);  // Creates update
  s->user.value = 2;

Symbol Table:
  Global: { a=1 }
    Update: a=2 (linked to original)

update_of chain: a(original,1) ← a(update,2)
```

#### Step 4: Parse `a` (again)

```
Input: a

Speculative Action:
  D_Sym *s = find_D_Sym(global_scope, "a", NULL);
  // Returns a=2 (current version via update chain)
  $$.value = s->user.value;  // $$.value = 2

Result: 2
```

### More Complex: Ambiguous Parse

Consider input that could be parsed two ways:

```
Input: x y z

Grammar allows:
  Path A: (x y) z     [function call: (x y) then apply to z]
  Path B: x (y z)     [function call: (y z) then apply to x]
```

#### Speculative Parsing Flow

```
Step 1: See 'x'
  Path 1: Active
  
Step 2: See 'y'
  AMBIGUITY DETECTED
  
  Path 1: Reduce x y to function_call
    - Speculative action: record call(x, y)
    - Update symbol table on path 1
    
  Path 2: Shift y (wait for more input)
    - No action yet
    - Symbol table unchanged
    
Step 3: See 'z'
  Path 1: Shift z, then reduce with previous result
    - Speculative action: record call(call(x,y), z)
    - Update symbol table on path 1
    
  Path 2: Reduce y z to function_call
    - Speculative action: record call(y, z)
    - Update symbol table on path 2
  
  Then reduce with x:
    - Speculative action: record call(x, call(y,z))
    - Update symbol table on path 2

Step 4: End of input - Resolve ambiguity
  Both paths are valid!
  
  Apply disambiguation rules:
    - Priorities
    - Associativity  
    - Custom ambiguity handler
    
  Select Path A (or both if truly ambiguous)
  
Step 5: Execute final actions on Path A only
  - Generate code for ((x y) z)
  - Discard Path B's symbol table changes
```

---

## Symbol Table Scope Relationships

### Scope Fields and Their Role

```c
typedef struct D_Scope {
  unsigned int kind : 2;           // INHERIT, RECURSIVE, PARALLEL, SEQUENTIAL
  unsigned int owned_by_user : 1;  // User-managed lifetime
  unsigned int depth;              // Nesting level
  
  D_Sym *ll;                       // Linked list of symbols (nested scopes)
  struct D_SymHash *hash;          // Hash table (global scope only)
  D_Sym *updates;                  // Symbol updates for this parse path
  
  struct D_Scope *search;          // Scope to search for symbols
  struct D_Scope *dynamic;         // Dynamic scope (e.g., class methods)
  struct D_Scope *up;              // Lexical parent scope
  struct D_Scope *up_updates;      // Prior scope in speculative parse path
  struct D_Scope *down;            // First child scope
  struct D_Scope *down_next;       // Next sibling scope
} D_Scope;
```

### Role in Speculative Parsing

| Field | Purpose | Speculative Parsing Role |
|-------|---------|-------------------------|
| `up` | Lexical parent | Defines scope hierarchy |
| `search` | Symbol lookup chain | Shared across parse paths |
| `up_updates` | Parse path parent | Tracks speculative parsing ancestry |
| `updates` | Symbol updates list | Stores path-specific symbol versions |
| `down`/`down_next` | Child scopes | Manages scope lifetime |
| `dynamic` | Additional lookup | Class methods, imports |

### Scope Graph During Parsing

```
Global Scope (depth 0)
  search: NULL
  up: NULL
  up_updates: NULL
  
  ↓ [Parser enters function]
  
Function Scope (depth 1)
  search: Global
  up: Global
  up_updates: Global
  
  ↓ [AMBIGUITY: two possible interpretations]
  
  ┌─────────────────────────┴─────────────────────────┐
  ↓                                                   ↓
Parse Path A Scope (depth 1)                Parse Path B Scope (depth 1)
  search: Function Scope                      search: Function Scope
  up: Global                                  up: Global
  up_updates: Function Scope                  up_updates: Function Scope
  updates: { x_updated }                      updates: { y_updated }
```

### Symbol Lookup Algorithm

```c
D_Sym *find_D_Sym(D_Scope *st, char *name, char *end) {
  // 1. Find symbol in base scopes (may be in parent)
  D_Sym *s = find_D_Sym_internal(st, name, len, hash);
  
  // 2. Get current version for THIS parse path
  if (s) return current_D_Sym(st, s);
  
  return NULL;
}

D_Sym *current_D_Sym(D_Scope *st, D_Sym *sym) {
  // Follow update chain to find version for this parse path
  if (sym->update_of) sym = sym->update_of;  // Get original
  
  // Walk up_updates chain looking for updates
  for (D_Scope *sc = st; sc; sc = sc->up_updates) {
    for (D_Sym *uu = sc->updates; uu; uu = uu->next) {
      if (uu->update_of == sym) 
        return uu;  // Found updated version on this path
    }
  }
  
  return sym;  // No updates, return original
}
```

---

## Performance Considerations

### Space Complexity

**Worst case**: O(n²) for highly ambiguous grammars
- n parse paths, each with separate scope instance
- In practice, path sharing keeps it near O(n)

**Optimization**: Scope instances share:
- Base scope structures (via `search` pointer)
- Symbol hash tables (global scope)
- Common symbol definitions

**Only path-specific state is duplicated**:
- `updates` lists (symbol versions)
- Parse path ancestry (`up_updates`)

### Time Complexity

**Symbol lookup**: O(1) average for hash table, O(k) for k updates
- Base lookup: O(1) hash table or O(n) linked list
- Update chain walk: O(k) where k = number of updates on path
- Commit optimizes: collapses update chains

**Scope operations**:
- `enter_D_Scope()`: O(1) - creates new instance
- `commit_D_Scope()`: O(n) - merges all updates
- `find_D_Sym()`: O(1) average + O(k) update chain

### Memory Management

**Lifetime**:
- Scopes live until `free_D_Scope()` called
- Failed parse paths discarded automatically
- Successful paths committed to global scope

**Ownership**:
- Parser owns scope tree root
- Scopes own their symbols
- Symbols don't own name strings (point to input buffer)

---

## Real-World Example: C Declaration Ambiguity

### The Problem

C has the infamous **declarator ambiguity**:

```c
typedef int T;
T * x;  // Is this a declaration or multiplication?
```

**Without typedef**: `T * x` is multiplication (T times x)
**With typedef**: `T * x` is declaration (pointer to T named x)

### How DParser Handles It

#### Grammar (simplified)

```yacc
statement
  : expression ';'
  | declaration ';'
  ;

expression
  : identifier '*' identifier
  [ // Speculative: assume multiplication
    $$.type = TYPE_INT;
  ]
  ;

declaration
  : type_name '*' identifier
  [ // Speculative: assume pointer declaration
    D_Sym *s = NEW_D_SYM(${scope}, $n2.start_loc.s, $n2.end);
    s->user.type = TYPE_POINTER;
  ]
  ;

type_name
  : identifier
  [ // Check if identifier is a typedef
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    if (!s || s->user.is_typedef)
      return 1;  // Valid type name
    return 0;    // Not a type
  ]
  ;
```

#### Parsing `T * x;`

```
Step 1: See 'T'
  - Check symbol table: is 'T' a typedef?
  - If YES: Path A (declaration) continues
  - If NO: Path B (expression) continues
  
  Symbol Table Query (speculative action):
    D_Sym *s = find_D_Sym(scope, "T", NULL);
    if (s && s->user.is_typedef) {
      // Path A: declaration
    } else {
      // Path B: expression  
    }

Step 2: See '*'
  Path A: Shift (part of declarator)
  Path B: Shift (multiplication operator)

Step 3: See 'x'
  Path A: Recognize as declarator
    Speculative action:
      D_Sym *new_var = NEW_D_SYM(scope, "x", NULL);
      new_var->user.type = TYPE_POINTER;
      new_var->user.base_type = T;
  
  Path B: Recognize as identifier
    Speculative action:
      D_Sym *var_x = find_D_Sym(scope, "x", NULL);
      // Use in multiplication

Step 4: See ';'
  Both paths reduce to statement
  
  Disambiguation:
    - If T is typedef: Path A wins
    - If T is not typedef: Path B wins
    
  Selected path's speculative actions become permanent
  Other path's changes are discarded
```

---

## Integration with Grammar Actions

### Action Timing Diagram

```
Parser Timeline:

  Input tokens → [Lexer] → Token stream
                             ↓
  ┌──────────────────────────┴──────────────────────────┐
  ↓                                                      ↓
[Shift Action]                                    [Reduce Action]
  ↓                                                      ↓
[Execute Speculative Action []]                  [Execute Speculative Action []]
  ↓                                                      ↓
Update Symbol Table on THIS parse path            Update Symbol Table on THIS parse path
  ↓                                                      ↓
Continue Parsing ──────────────────────────────────────→

                    ↓ (End of Input)
                    
            [Ambiguity Resolution]
                    ↓
            Select Successful Path(s)
                    ↓
            Commit Symbol Table Changes
                    ↓
            [Execute Final Actions {}]
                    ↓
                  Output
```

### Speculative Action Guarantees

**What speculative actions CAN assume**:
- Symbol table reflects THIS parse path's state
- Actions execute in parse order (for this path)
- Multiple paths execute independently

**What speculative actions CANNOT assume**:
- This parse path will succeed
- Actions will execute on final parse tree
- Side effects are permanent

**Best practices**:
- Keep speculative actions side-effect free (except symbol table)
- Don't do I/O, allocation, or irreversible changes
- Save expensive work for final actions

---

## Debugging Speculative Parsing

### Verbose Mode

DParser's `-v` flag shows parse paths:

```bash
$ ./sample_parser -v input.txt
```

Output shows:
- Parse states created
- Reductions performed
- Ambiguities detected
- Paths merged/discarded

### Symbol Table Inspection

```c
void print_scope(D_Scope *st) {
  printf("SCOPE %p: ", (void *)st);
  printf("  owned: %d, kind: %d, ", st->owned_by_user, st->kind);
  // ... prints symbols ...
}
```

Use in speculative actions to debug symbol table state:

```yacc
expression
  : identifier '=' expression
  [ 
    print_scope(${scope});  // Debug output
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    // ...
  ]
  ;
```

### Common Issues

**Problem**: Symbol not found when it should exist
- **Cause**: Looking in wrong parse path's scope
- **Fix**: Trace `up_updates` chain, verify scope passed to find function

**Problem**: Old symbol value instead of updated
- **Cause**: Not using `current_D_Sym()` or `UPDATE_D_SYM()`
- **Fix**: Always get current version for parse path

**Problem**: Symbol persists after failed parse
- **Cause**: Not cleaning up failed parse paths
- **Fix**: Ensure `free_D_Scope()` on abandoned paths

---

## Advanced Topics

### Local Ambiguity Handling

**Local ambiguity**: Resolved before parse completes

```
Input: a + b * c

Path A: ((a + b) * c)    [wrong precedence]
Path B: (a + (b * c))    [correct precedence]

Parser uses priorities to eliminate Path A immediately
Only Path B's speculative actions persist
```

**Global ambiguity**: Remains until end of input

```
Input: ambiguous_construct

Path A: interpretation1
Path B: interpretation2

Both valid until end
Disambiguation via custom handler or error
```

### Scope Kinds

```c
#define D_SCOPE_INHERIT 0      // Normal lexical scoping
#define D_SCOPE_RECURSIVE 1    // Recursive definitions (functions)
#define D_SCOPE_PARALLEL 2     // Parallel declarations (struct members)
#define D_SCOPE_SEQUENTIAL 3   // Sequential visibility (switch cases)
```

Affects symbol visibility rules, not speculative parsing mechanism.

### Dynamic Scoping

For implementing:
- **Class method scopes**: Access class members without qualification
- **Module imports**: Symbols from imported module
- **Nested name lookup**: C++ namespaces

```c
D_Scope *method_scope = scope_D_Scope(current, class_scope);
// method_scope searches both current and class_scope
```

Works with speculative parsing: each parse path can have different dynamic scopes.

---

## Summary

### Key Takeaways

1. **GLR = Parallel Parsing**: Explore all possibilities simultaneously
2. **GSS = Efficient Storage**: Share common stack prefixes
3. **Speculative Actions = Immediate**: Execute on all paths during parsing
4. **Final Actions = Deferred**: Execute only on successful paths
5. **Symbol Table = Path-Aware**: Each parse path has independent view
6. **Updates = Versioning**: Symbols can have multiple versions per path
7. **Commit = Optimization**: Collapse updates after disambiguation

### Design Philosophy

The speculative parsing architecture enables:
- **Parsing complex grammars**: Handle ambiguity, context-sensitivity
- **Incremental symbol table**: Build during parsing, not after
- **Efficient disambiguation**: Delay decisions until sufficient information
- **Clean abstraction**: Grammar writer focuses on semantics, not parsing strategy

### Further Reading

- **Tomita, Masaru** (1985): *Efficient Parsing for Natural Language*
- **Scott & Johnstone** (2006): *GLL Parsing* (related generalized approach)
- **DParser Manual**: docs/manual.md - Symbol Table section
- **Test Grammars**: tests/g28.test.g, tests/g29.test.g - Working examples

---

## Appendix: Complete Example

### Full Grammar

```yacc
{
#include <stdio.h>

typedef struct My_Sym {
  int value;
  int is_typedef;
} My_Sym;
#define D_UserSym My_Sym

typedef struct My_ParseNode {
  int value;
  struct D_Scope *scope;
} My_ParseNode;
#define D_ParseNode_User My_ParseNode
}

translation_unit: statement*;

statement
  : expression ';'
  { printf("Expression result: %d\n", $0.value); }
  | '{' new_scope statement* '}'
  [ ${scope} = enter_D_Scope(${scope}, $n0.scope); ]
  { ${scope} = commit_D_Scope(${scope}); }
  ;

new_scope: [ ${scope} = new_D_Scope(${scope}); ];

expression
  : identifier ':' expression
  [ // SPECULATIVE: Declare new variable
    D_Sym *s;
    if (find_D_Sym_in_Scope(${scope}, ${scope}, $n0.start_loc.s, $n0.end))
      printf("Warning: duplicate at line %d\n", $n0.start_loc.line);
    s = NEW_D_SYM(${scope}, $n0.start_loc.s, $n0.end);
    s->user.value = $2.value;
    $$.value = s->user.value;
  ]
  { // FINAL: Record declaration in output
    printf("Declared: %s\n", get_symbol_name($0));
  }
  
  | identifier '=' expression
  [ // SPECULATIVE: Update variable
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    if (s) {
      s = UPDATE_D_SYM(s, &${scope});
      s->user.value = $2.value;
      $$.value = s->user.value;
    }
  ]
  { // FINAL: Record assignment
    printf("Assigned: %s = %d\n", get_symbol_name($0), $2.value);
  }
  
  | integer
  [ $$.value = atoi($n0.start_loc.s); ]
  
  | identifier
  [ // SPECULATIVE: Reference variable
    D_Sym *s = find_D_Sym(${scope}, $n0.start_loc.s, $n0.end);
    if (s)
      $$.value = s->user.value;
  ]
  
  | expression '+' expression
  [ $$.value = $0.value + $2.value; ]
  ;

integer: "-?[0-9]+" $term -1;
identifier: "[a-zA-Z_][a-zA-Z_0-9]*";
```

### Example Input & Execution

**Input:**
```
x: 10;
y: 20;
{
  x: 5;
  x + y;
}
x + y;
```

**Parse & Execution:**

1. `x: 10;` - Declare x=10 globally (speculative + final)
2. `y: 20;` - Declare y=20 globally (speculative + final)
3. `{` - Enter new scope (speculative)
4. `x: 5;` - Declare x=5 in local scope (speculative + final, shadows global)
5. `x + y;` - Reference local x(5) + global y(20) = 25 (speculative), print 25 (final)
6. `}` - Exit scope, commit changes (final)
7. `x + y;` - Reference global x(10) + y(20) = 30 (speculative), print 30 (final)

**Output:**
```
Declared: x
Declared: y
Declared: x
Expression result: 25
Expression result: 30
```

**Symbol Table Evolution:**

```
After x:10  → Global: {x=10}
After y:20  → Global: {x=10, y=20}
After {     → Global: {x=10, y=20}
              Local: {} (empty, searches Global)
After x:5   → Global: {x=10, y=20}
              Local: {x=5} (shadows Global.x)
After x+y   → Uses Local.x=5, Global.y=20 → 25
After }     → Global: {x=10, y=20} (Local discarded)
After x+y   → Uses Global.x=10, Global.y=20 → 30
```

This demonstrates the complete speculative parsing cycle with symbol table integration.
