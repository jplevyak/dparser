/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

/*
 * DParser Symbol Table API
 * ========================
 *
 * MEMORY OWNERSHIP SEMANTICS (NEW: Scope Pool):
 *
 * Scopes (D_Scope):
 *   - Created by: new_D_Scope(), enter_D_Scope(), global_D_Scope(), scope_D_Scope()
 *   - Owned by: Scope pool (automatically tracked)
 *   - Must be freed with: free_D_Scope(top_scope, force)
 *   - NEW: All scopes freed at once from pool (no leaks possible!)
 *   - Automatic tracking: All scopes registered in pool on creation
 *   - Exception: If owned_by_user flag is set, only freed when force=1
 *   - Lifetime: Must outlive any symbols it contains
 *   - IMPORTANT: Always free the top-level scope, not individual child scopes
 *
 * Symbols (D_Sym):
 *   - Created by: new_D_Sym(), UPDATE_D_SYM(), update_additional_D_Sym()
 *   - Owned by: The scope they're created in
 *   - Freed automatically: When scope is freed with free_D_Scope()
 *   - User data (D_UserSym): NOT freed - caller's responsibility
 *   - Symbol name string: NOT owned - points into input buffer
 *
 * Symbol Names:
 *   - NOT copied or owned by symbol table
 *   - Must point to stable memory (input buffer, string pool)
 *   - Must outlive all symbols that reference them
 *   - Typically point directly into parser input buffer
 *
 * Update Symbols:
 *   - Created during speculative parsing
 *   - Owned by scope's updates list
 *   - Freed automatically with scope
 *   - Form a chain via update_of pointer
 *
 * TYPICAL USAGE PATTERN (NEW: With Scope Pool):
 *
 *   // Create global scope (creates pool automatically)
 *   D_Scope *global = new_D_Scope(NULL);
 *
 *   // Create symbol (name must outlive symbol)
 *   D_Sym *sym = NEW_D_SYM(global, "varname", NULL);
 *   sym->user = my_data;  // User responsible for freeing my_data
 *
 *   // Enter nested scope (automatically registered in pool)
 *   D_Scope *local = new_D_Scope(global);
 *
 *   // Update symbol (creates new scope, automatically registered in pool)
 *   D_Scope *scope = local;  // Can save or not save original - no leak!
 *   D_Sym *updated = UPDATE_D_SYM(sym, &scope);  // scope now points to new scope
 *   updated->user = new_data;
 *
 *   // Cleanup (frees ALL scopes from pool - no leaks possible!)
 *   free_D_Scope(global, 1);  // Frees global, local, and UPDATE scope
 *   // User must free my_data and new_data separately
 *
 * SCOPE RELATIONSHIPS:
 *
 *   up         - Lexical parent scope
 *   down       - First child scope
 *   down_next  - Next sibling scope
 *   search     - Scope to search for symbols
 *   dynamic    - Additional scope to search (e.g., class methods)
 *   up_updates - Prior scope in speculative parse path
 *
 * SPECULATIVE PARSING:
 *
 *   GLR parsers create multiple parse paths. Symbol table supports this by:
 *   - enter_D_Scope() creates speculative parse instance
 *   - UPDATE_D_SYM() creates symbol versions per parse path
 *   - commit_D_Scope() collapses to single successful path
 *   - current_D_Sym() finds correct version for parse path
 *
 * See dsymtab.c for detailed implementation notes.
 */

#ifndef _dsymtab_H_
#define _dsymtab_H_

#ifndef D_UserSym
#define D_UserSym unsigned int
#endif

struct D_SymHash;
struct D_Scope;
struct D_ScopePool;

typedef struct D_Sym {
  char *name;
  int len;
  unsigned int hash;
  struct D_Scope *scope;
  struct D_Sym *update_of;
  struct D_Sym *next;
  D_UserSym user;
} D_Sym;

#define D_SCOPE_INHERIT 0
#define D_SCOPE_RECURSIVE 1
#define D_SCOPE_PARALLEL 2
#define D_SCOPE_SEQUENTIAL 3

typedef struct D_Scope {
  unsigned int kind : 2;
  unsigned int owned_by_user : 1; /* don't automatically delete */
  unsigned int depth;
  D_Sym *ll;
  struct D_SymHash *hash;
  D_Sym *updates;
  struct D_Scope *search;     /* scope to start search */
  struct D_Scope *dynamic;    /* dynamic scope (e.g. methods) */
  struct D_Scope *up;         /* enclosing scope */
  struct D_Scope *up_updates; /* prior scope in speculative parse */
  struct D_Scope *down;       /* enclosed scopes (for FREE) */
  struct D_Scope *down_next;  /* next enclosed scope */
  struct D_ScopePool *pool;   /* scope pool (only set on top-level scope) */
} D_Scope;

D_Scope *new_D_Scope(D_Scope *parent);
D_Scope *enter_D_Scope(D_Scope *current, D_Scope *scope);
D_Scope *commit_D_Scope(D_Scope *scope);
D_Scope *equiv_D_Scope(D_Scope *scope);
D_Scope *global_D_Scope(D_Scope *scope);
D_Scope *scope_D_Scope(D_Scope *current, D_Scope *scope);
void free_D_Scope(D_Scope *st, int force);
D_Sym *new_D_Sym(D_Scope *st, char *name, char *end, int sizeof_D_Sym);
#define NEW_D_SYM(_st, _name, _end) new_D_Sym(_st, _name, _end, sizeof(D_Sym))
D_Sym *find_D_Sym(D_Scope *st, char *name, char *end);
D_Sym *find_global_D_Sym(D_Scope *st, char *name, char *end);
/* use for first update in a production to update scope */
D_Sym *update_D_Sym(D_Sym *sym, D_Scope **st, int sizeof_D_Sym);
#define UPDATE_D_SYM(_sym, _st) update_D_Sym(_sym, _st, sizeof(D_Sym))
/* use for first subsequent updates in a production */
D_Sym *update_additional_D_Sym(D_Scope *st, D_Sym *sym, int sizeof_D_Sym);
#define UPDATE_ADDITIONAL_D_SYM(_st, _sym) update_additional_D_Sym(_st, _sym, sizeof(D_Sym))
D_Sym *current_D_Sym(D_Scope *st, D_Sym *sym);
D_Sym *find_D_Sym_in_Scope(D_Scope *st, D_Scope *cur, char *name, char *end);
D_Sym *next_D_Sym_in_Scope(D_Scope **st, D_Sym **sym);
void print_scope(D_Scope *st);

#endif
