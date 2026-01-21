/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#include "d.h"

/* Prime number chosen for initial hash table size to minimize collisions.
   The hash table grows dynamically (doubling + 1) when load factor exceeds 0.5.
   Size is large enough to handle most typical parsing scenarios without resizing. */
#define INITIAL_SYMHASH_SIZE 3137

/*
  How this works.  In a normal symbol table there is simply
  a stack of scopes representing the scoping structure of
  the program.  Because of speculative parsing, this symbol table
  also has a tree of all 'updates' representing different
  views of the state of scoped variables by each speculative
  parse state.  Periodically, when the parse state collapses
  to a single state (we are nolonger speculating), these changes
  are can be 'committed' and the changes pushed into the top
  level hash table.

  All D_Scope's except the top level just have a 'll' of symbols, the
  top level has a 'hash'.

  'updates' is a list of changes to symbols in other scopes.  It is
  searched to find the current version of a symbol with respect to the
  speculative parse path represented by D_Scope.

  'up' points to the enclosing scope, it isn't used much.

  'up_updates' is the prior scope in speculative parsing, it is used find
  the next D_Scope to look in for 'updates' after the current one has been
  searched.

  'down' and 'down_next' are used to hold enclosing scopes, or in the
  case of the top level, sibling scopes (created by commmit).
*/

typedef struct D_SymHash {
  int index;
  int grow;
  Vec(D_Sym *) syms;
} D_SymHash;

/*
 * free_D_Sym - Free a symbol
 * @s: Symbol to free
 *
 * Internal function to deallocate a symbol. Only frees the symbol structure
 * itself, not the name string (which points into the input buffer).
 */
static void free_D_Sym(D_Sym *s) { FREE(s); }

/*
 * symhash_add - Add symbol to hash table
 * @sh: Hash table to add to
 * @s: Symbol to add
 *
 * Adds a symbol to the hash table using chaining for collision resolution.
 * Automatically grows the hash table when load factor exceeds threshold.
 * Preserves insertion order when rehashing.
 *
 * Note: Does not check for duplicates - caller's responsibility.
 */
static void symhash_add(D_SymHash *sh, D_Sym *s) {
  uint i, h = s->hash % sh->syms.n, n;
  D_Sym **v = sh->syms.v, *x;
  Vec(D_Sym *) vv, tv;

  sh->index++;
  s->next = v[h];
  v[h] = s;

  if (sh->index > sh->grow) {
    vv.v = sh->syms.v;
    vv.n = sh->syms.n;
    sh->syms.n = sh->grow;
    sh->grow = sh->grow * 2 + 1;
    sh->syms.v = MALLOC(sh->syms.n * sizeof(void *));
    memset(sh->syms.v, 0, sh->syms.n * sizeof(void *));
    v = sh->syms.v;
    n = sh->syms.n;
    vec_clear(&tv);
    for (i = 0; i < vv.n; i++) /* use temporary to preserve order */
      while (vv.v[i]) {
        x = vv.v[i];
        vv.v[i] = x->next;
        vec_add(&tv, x);
      }
    for (i = 0; i < tv.n; i++) {
      x = tv.v[i];
      h = x->hash % n;
      x->next = v[h];
      v[h] = x;
    }
    vec_free(&tv);
    FREE(vv.v);
  }
}

/*
 * new_D_SymHash - Create a new hash table
 *
 * Allocates and initializes a hash table for the global scope.
 * Sets initial size and growth threshold.
 *
 * Returns: Pointer to new hash table
 */
static D_SymHash *new_D_SymHash(void) {
  D_SymHash *sh = MALLOC(sizeof(D_SymHash));
  memset(sh, 0, sizeof(D_SymHash));
  sh->grow = INITIAL_SYMHASH_SIZE * 2 + 1;
  sh->syms.n = INITIAL_SYMHASH_SIZE;
  sh->syms.v = MALLOC(sh->syms.n * sizeof(void *));
  memset(sh->syms.v, 0, sh->syms.n * sizeof(void *));
  return sh;
}

/*
 * free_D_SymHash - Free hash table and all contained symbols
 * @sh: Hash table to free
 *
 * Frees all symbols in the hash table and the hash table itself.
 * Must only be called on top-level (global) scope hash tables.
 */
static void free_D_SymHash(D_SymHash *sh) {
  uint i;
  D_Sym *sym;
  for (i = 0; i < sh->syms.n; i++)
    for (; sh->syms.v[i]; sh->syms.v[i] = sym) {
      sym = sh->syms.v[i]->next;
      free_D_Sym(sh->syms.v[i]);
    }
  FREE(sh->syms.v);
  FREE(sh);
}

/*
 * new_D_Scope - Create a new scope
 * @parent: Parent scope, or NULL for global scope
 *
 * Creates a new scope for symbol management. If parent is NULL, creates
 * the global (top-level) scope with a hash table. Otherwise, creates a
 * nested scope with a linked list of symbols.
 *
 * The new scope inherits kind and search settings from parent, and is
 * added to the parent's list of child scopes.
 *
 * Memory: Caller owns the returned scope and must free with free_D_Scope().
 *
 * Returns: Pointer to newly created scope
 */
D_Scope *new_D_Scope(D_Scope *parent) {
  D_Scope *st = MALLOC(sizeof(D_Scope));
  memset(st, 0, sizeof(D_Scope));
  if (parent) {
    st->depth = parent->depth + 1;
    st->kind = parent->kind;
    st->search = parent;
    st->up = parent;
    st->up_updates = parent;
    st->down_next = parent->down;
    parent->down = st;
  } else
    st->hash = new_D_SymHash();
  return st;
}

/*
 * equiv_D_Scope - Find equivalent scope without unnecessary updates
 * @current: Current scope to check
 *
 * Walks up the scope chain to find the nearest equivalent scope that has
 * actual content (symbols or updates). This optimizes speculative parsing
 * by collapsing empty intermediate scopes.
 *
 * A scope is equivalent if it:
 * - Has the same depth and parent structure
 * - Contains no symbols (ll/hash) or updates
 * - Has no dynamic scope
 *
 * Returns: Equivalent scope, or current if no simplification possible
 */
D_Scope *equiv_D_Scope(D_Scope *current) {
  D_Scope *s = current, *last = current;
  D_Sym *sy;
  if (!s) return s;
  while (s->depth >= current->depth) {
    if (s->depth == last->depth) {
      if (current->up == s->up)
        last = s;
      else
        break;
    }
    if (s->ll || s->hash) break;
    if (s->dynamic) break;
    sy = s->updates;
    while (sy) {
      if (sy->scope->depth <= current->depth) break;
      sy = sy->next;
    }
    if (sy) break;
    if (!s->up_updates) break;
    s = s->up_updates;
  }
  return last;
}

/*
 * NOTE: Alternative implementation of equiv_D_Scope kept for reference.
 * The current implementation above is more conservative and handles edge
 * cases better. This simpler version is preserved in case future
 * optimization is needed.
 */
#if 0
D_Scope *
equiv_D_Scope(D_Scope *current) {
  D_Scope *s = current;
  while (s) {
    if (s->ll || s->hash)
      break;
    if (s->dynamic) /* conservative */
      break;
    if (s->updates)
      break;
    if (!s->search)
      break;
    if (s->search->up != current->up)
      break;
    if (s->search->up_updates != current->up_updates)
      break;
    s = s->search;
  }
  return s;
}
#endif

/*
 * enter_D_Scope - Enter a scope for speculative parsing
 * @current: Current parse state scope
 * @scope: Scope to enter (typically created with new_D_Scope)
 *
 * Creates a new scope instance for speculative parsing. This allows
 * multiple parse paths to share the same base scope while maintaining
 * separate update histories.
 *
 * The new scope:
 * - Shares depth and kind with the target scope
 * - Searches through the target scope for symbols
 * - Tracks updates relative to current parse state
 *
 * Used when GLR parser explores multiple parse alternatives.
 *
 * Memory: Caller must eventually free with free_D_Scope() or commit
 *         with commit_D_Scope().
 *
 * Returns: New scope instance for speculative parsing
 */
D_Scope *enter_D_Scope(D_Scope *current, D_Scope *scope) {
  D_Scope *st = MALLOC(sizeof(D_Scope)), *parent = scope->up;
  memset(st, 0, sizeof(D_Scope));
  st->depth = scope->depth;
  st->up = parent;
  st->kind = scope->kind;
  st->search = scope;
  /*
   * NOTE: Original optimization for clearing old updates disabled.
   * Current simpler approach (st->up_updates = current) works correctly.
   * This code is preserved in case update chain optimization is needed.
   */
#if 0
  /* clear old updates */
  {
    D_Scope *update_scope = current;
    while (update_scope) {
      D_Sym *sy = update_scope->updates;
      while (sy) {
        if (sy->scope->depth <= current->depth)
          goto Lfound;
        sy = sy->next;
      }
      update_scope = update_scope->up_updates;
    }
Lfound:
    st->up_updates = update_scope;
  }
#else
  st->up_updates = current;
#endif
  st->down_next = current->down;
  current->down = st;
  return st;
}

/*
 * global_D_Scope - Access global scope from nested context
 * @current: Current scope
 *
 * Finds the global (top-level) scope and creates a speculative parse
 * instance to access it. This allows looking up global symbols from
 * deep within nested scopes.
 *
 * Returns: Speculative scope instance pointing to global scope
 */
D_Scope *global_D_Scope(D_Scope *current) {
  D_Scope *g = current;
  while (g->up) g = g->search;
  return enter_D_Scope(current, g);
}

/*
 * scope_D_Scope - Add dynamic scope to current scope
 * @current: Current scope
 * @scope: Dynamic scope to add (e.g., class methods, imported module)
 *
 * Creates a new scope that searches both the current scope chain and
 * an additional dynamic scope. Useful for implementing:
 * - Class method scopes (accessing class variables)
 * - Module imports
 * - Dynamic lookup contexts
 *
 * Symbol lookup will check:
 * 1. Current scope and parents
 * 2. Dynamic scope and its parents
 *
 * Returns: New scope with dynamic scope attached
 */
D_Scope *scope_D_Scope(D_Scope *current, D_Scope *scope) {
  D_Scope *st = MALLOC(sizeof(D_Scope)), *parent = current->up;
  memset(st, 0, sizeof(D_Scope));
  st->depth = current->depth;
  st->up = parent;
  st->kind = current->kind;
  st->search = current;
  st->dynamic = scope;
  st->up_updates = current;
  st->down_next = current->down;
  current->down = st;
  return st;
}

/*
 * free_D_Scope - Free scope and all child scopes
 * @st: Scope to free
 * @force: If non-zero, free even if owned_by_user flag is set
 *
 * Recursively frees a scope hierarchy, including:
 * - All child scopes (down/down_next chain)
 * - All symbols in the scope (hash table or linked list)
 * - All update symbols
 *
 * The owned_by_user flag allows user code to maintain long-lived scopes
 * that won't be freed automatically. Use force=1 to override this and
 * free everything.
 *
 * Memory ownership:
 * - Scope structure: Freed
 * - Symbols: Freed
 * - Symbol names: NOT freed (point into input buffer)
 * - User data: NOT freed (user's responsibility)
 *
 * Typically called on global scope to clean up entire symbol table.
 */
void free_D_Scope(D_Scope *st, int force) {
  D_Scope *s;
  D_Sym *sym;
  for (; st->down; st->down = s) {
    s = st->down->down_next;
    free_D_Scope(st->down, 0);
  }
  if (st->owned_by_user && !force) return;
  if (st->hash)
    free_D_SymHash(st->hash);
  else
    for (; st->ll; st->ll = sym) {
      sym = st->ll->next;
      free_D_Sym(st->ll);
    }
  for (; st->updates; st->updates = sym) {
    sym = st->updates->next;
    free_D_Sym(st->updates);
  }
  FREE(st);
}

/*
 * commit_ll - Recursively commit linked list symbols to hash table
 * @st: Scope with linked list symbols
 * @sh: Hash table to commit to
 *
 * Internal function that moves symbols from nested scope linked lists
 * into the global hash table during commit. Processes scope chain
 * recursively.
 */
static void commit_ll(D_Scope *st, D_SymHash *sh) {
  D_Sym *sym;
  if (st->search) {
    commit_ll(st->search, sh);
    for (; st->ll; st->ll = sym) {
      sym = st->ll->next;
      symhash_add(sh, st->ll);
    }
  }
}

/*
 * commit_update - Update symbol pointers to latest versions
 * @st: Scope to commit from
 * @sh: Hash table containing symbols to update
 *
 * Internal function that updates all symbols in the hash table to point
 * directly to their latest versions. This optimizes future lookups by
 * collapsing update chains after speculative parsing completes.
 */
static void commit_update(D_Scope *st, D_SymHash *sh) {
  uint i;
  D_Sym *s;

  for (i = 0; i < sh->syms.n; i++)
    for (s = sh->syms.v[i]; s; s = s->next) s->update_of = current_D_Sym(st, s);
}

/*
 * commit_D_Scope - Commit speculative parsing changes
 * @st: Scope to commit (must be top-level/global scope)
 *
 * Collapses speculative parsing state when parse succeeds. Moves all
 * symbols from nested scopes into the global hash table and updates
 * symbol pointers to point to latest versions.
 *
 * This is called when:
 * - GLR parser determines a single successful parse path
 * - Ambiguity is resolved
 * - Parse completes successfully
 *
 * Only operates on top-level scope; nested scope commits are no-ops.
 *
 * Returns: Global scope with committed changes
 */
D_Scope *commit_D_Scope(D_Scope *st) {
  D_Scope *x = st;
  if (st->up) return st;
  while (x->search) x = x->search;
  commit_ll(st, x->hash);
  commit_update(st, x->hash);
  return x;
}

/*
 * new_D_Sym - Create a new symbol
 * @st: Scope to create symbol in (NULL allowed for orphan symbols)
 * @name: Pointer to symbol name in input buffer
 * @end: Pointer to character after name, or NULL to use strlen()
 * @sizeof_D_Sym: Size of symbol structure (for user extensions)
 *
 * Creates a new symbol and adds it to the scope. The symbol name is NOT
 * copied - it must point to a buffer that outlives the symbol (typically
 * the input buffer).
 *
 * If @end is provided, length is (@end - @name). Otherwise strlen() is used.
 * If @name is NULL, creates a zero-length symbol.
 *
 * The symbol is automatically added to the scope's hash table (global scope)
 * or linked list (nested scope).
 *
 * Memory: Symbol structure is owned by scope and freed with free_D_Scope().
 *         Symbol name is NOT owned - caller must ensure it remains valid.
 *
 * Macro: Use NEW_D_SYM(st, name, end) for standard symbol size.
 *
 * Returns: Newly created symbol
 */
D_Sym *new_D_Sym(D_Scope *st, char *name, char *end, int sizeof_D_Sym) {
  uint len = end ? end - name : name ? strlen(name) : 0;
  D_Sym *s = MALLOC(sizeof_D_Sym);
  memset(s, 0, sizeof_D_Sym);
  s->name = name;
  s->len = len;
  s->hash = strhashl(name, len);
  s->scope = st;
  if (st) {
    if (st->hash) {
      symhash_add(st->hash, s);
    } else {
      s->next = st->ll;
      st->ll = s;
    }
  }
  return s;
}

/*
 * current_D_Sym - Get current version of a symbol
 * @st: Current scope (determines which updates are visible)
 * @sym: Symbol to get current version of (may be NULL)
 *
 * Returns the most recent version of a symbol along the current parse path.
 * Follows the update chain from the original symbol through all updates
 * visible in the scope's up_updates chain.
 *
 * This is necessary because speculative parsing creates multiple versions
 * of symbols (via UPDATE_D_SYM). This function finds the correct version
 * for the current parse state.
 *
 * Returns: Current version of symbol, or NULL if sym is NULL
 */
D_Sym *current_D_Sym(D_Scope *st, D_Sym *sym) {
  D_Scope *sc;
  D_Sym *uu;

  if (!sym) return NULL;
  if (sym->update_of) sym = sym->update_of;
  /* return the last update */
  for (sc = st; sc; sc = sc->up_updates) {
    for (uu = sc->updates; uu; uu = uu->next)
      if (uu->update_of == sym) return uu;
  }
  return sym;
}

/*
 * find_D_Sym_in_Scope_internal - Search for symbol in specific scope only
 * @st: Scope to search
 * @name: Symbol name
 * @len: Length of name
 * @h: Pre-computed hash of name
 *
 * Internal function that searches only within a specific scope (and its
 * search/dynamic chain at the same depth), not parent scopes.
 *
 * Used to implement find_D_Sym_in_Scope() for duplicate detection.
 *
 * Returns: Symbol if found, NULL otherwise
 */
static D_Sym *find_D_Sym_in_Scope_internal(D_Scope *st, char *name, int len, uint h) {
  D_Sym *ll;
  for (; st; st = st->search) {
    if (st->hash)
      ll = st->hash->syms.v[h % st->hash->syms.n];
    else
      ll = st->ll;
    while (ll) {
      if (ll->hash == h && ll->len == len && !strncmp(ll->name, name, len)) return ll;
      ll = ll->next;
    }
    if (st->dynamic)
      if ((ll = find_D_Sym_in_Scope_internal(st->dynamic, name, len, h))) return ll;
    if (!st->search || st->search->up != st->up) break;
  }
  return NULL;
}

/*
 * find_D_Sym_internal - Search for symbol through scope chain
 * @cur: Scope to start search from
 * @name: Symbol name
 * @len: Length of name
 * @h: Pre-computed hash of name
 *
 * Internal function that searches for a symbol starting from a scope and
 * following the search chain (parent scopes). Also checks dynamic scopes.
 *
 * This is the core lookup routine used by all public find functions.
 *
 * Returns: Symbol if found, NULL otherwise (does NOT return current version)
 */
static D_Sym *find_D_Sym_internal(D_Scope *cur, char *name, int len, uint h) {
  D_Sym *ll;
  if (!cur) return NULL;
  if (cur->hash)
    ll = cur->hash->syms.v[h % cur->hash->syms.n];
  else
    ll = cur->ll;
  while (ll) {
    if (ll->hash == h && ll->len == len && !strncmp(ll->name, name, len)) break;
    ll = ll->next;
  }
  if (!ll) {
    if (cur->dynamic)
      if ((ll = find_D_Sym_in_Scope_internal(cur->dynamic, name, len, h))) return ll;
    if (cur->search) return find_D_Sym_internal(cur->search, name, len, h);
    return ll;
  }
  return ll;
}

/*
 * find_D_Sym - Find symbol in scope chain
 * @st: Scope to start search from
 * @name: Symbol name
 * @end: Pointer to end of name, or NULL to use strlen()
 *
 * Searches for a symbol starting from the given scope and walking up
 * the parent chain. Returns the current version of the symbol (accounting
 * for updates in speculative parsing).
 *
 * This is the standard symbol lookup function.
 *
 * Returns: Current version of symbol if found, NULL if not found
 */
D_Sym *find_D_Sym(D_Scope *st, char *name, char *end) {
  uint len = end ? end - name : strlen(name);
  uint h = strhashl(name, len);
  D_Sym *s = find_D_Sym_internal(st, name, len, h);
  if (s) return current_D_Sym(st, s);
  return NULL;
}

/*
 * find_global_D_Sym - Find symbol in global scope only
 * @st: Current scope (for determining current version)
 * @name: Symbol name
 * @end: Pointer to end of name, or NULL to use strlen()
 *
 * Searches only the global (top-level) scope, ignoring local scopes.
 * Useful for accessing global variables from within nested contexts.
 *
 * Returns the current version relative to @st, even though the search
 * is only in global scope.
 *
 * Returns: Current version of global symbol if found, NULL if not found
 */
D_Sym *find_global_D_Sym(D_Scope *st, char *name, char *end) {
  D_Sym *s;
  uint len = end ? end - name : strlen(name);
  uint h = strhashl(name, len);
  D_Scope *cur = st;
  while (cur->up) cur = cur->search;
  s = find_D_Sym_internal(cur, name, len, h);
  if (s) return current_D_Sym(st, s);
  return NULL;
}

/*
 * find_D_Sym_in_Scope - Find symbol in specific scope only
 * @st: Current scope (for determining current version)
 * @cur: Scope to search (does not search parent scopes)
 * @name: Symbol name
 * @end: Pointer to end of name, or NULL to use strlen()
 *
 * Searches only the specified scope, not its parents. Used primarily for
 * duplicate detection - check if a symbol already exists in the current
 * scope before creating a new one.
 *
 * Example: if (find_D_Sym_in_Scope(scope, scope, "x", NULL))
 *            error("duplicate declaration");
 *
 * Returns: Current version of symbol if found in scope, NULL otherwise
 */
D_Sym *find_D_Sym_in_Scope(D_Scope *st, D_Scope *cur, char *name, char *end) {
  uint len = end ? end - name : strlen(name);
  uint h = strhashl(name, len);
  D_Sym *s = find_D_Sym_in_Scope_internal(cur, name, len, h);
  if (s) return current_D_Sym(st, s);
  return NULL;
}

/*
 * next_D_Sym_in_Scope - Iterate through symbols in scope
 * @scope: Pointer to scope (updated during iteration)
 * @sym: Pointer to symbol (updated to next symbol)
 *
 * Iterates through all symbols in a scope. On first call, *sym should be NULL.
 * On subsequent calls, pass the previously returned symbol.
 *
 * Both @scope and @sym are updated to point to the next symbol. When iteration
 * is complete, returns NULL.
 *
 * Example:
 *   D_Sym *sym = NULL;
 *   D_Scope *scope = my_scope;
 *   while (next_D_Sym_in_Scope(&scope, &sym)) {
 *     // process sym
 *   }
 *
 * Note: For hash tables, iteration order is not guaranteed. For linked lists
 *       (nested scopes), iterates in reverse insertion order.
 *
 * Returns: Next symbol, or NULL if iteration complete
 */
D_Sym *next_D_Sym_in_Scope(D_Scope **scope, D_Sym **sym) {
  D_Sym *last_sym = *sym, *ll = last_sym;
  D_Scope *st = *scope;
  if (ll) {
    ll = ll->next;
    if (ll) goto Lreturn;
  }
  for (; st; st = st->search) {
    if (st->hash) {
      uint i = last_sym ? ((last_sym->hash + 1) % st->hash->syms.n) : 0;
      if (!last_sym || i) ll = st->hash->syms.v[i];
    } else {
      if (!last_sym) ll = st->ll;
    }
    last_sym = 0;
    if (ll) goto Lreturn;
    if (!st->search || st->search->up != st->up) break;
  }
Lreturn:
  if (ll) *sym = ll;
  *scope = st;
  return ll;
}

/*
 * update_additional_D_Sym - Create additional update to a symbol
 * @st: Current scope
 * @sym: Symbol to update (may be NULL)
 * @sizeof_D_Sym: Size of symbol structure
 *
 * Creates a new version of a symbol without creating a new scope. Used when
 * multiple updates occur in the same production/scope.
 *
 * The new symbol:
 * - Copies data from current version of @sym
 * - Points back to original via update_of
 * - Is added to scope's updates list
 *
 * Use UPDATE_D_SYM() for first update (creates new scope).
 * Use update_additional_D_Sym() for subsequent updates in same scope.
 *
 * Returns NULL if @sym is NULL.
 *
 * Macro: Use UPDATE_ADDITIONAL_D_SYM(st, sym) for standard symbol size.
 *
 * Returns: New symbol version, or NULL if sym is NULL
 */
D_Sym *update_additional_D_Sym(D_Scope *st, D_Sym *sym, int sizeof_D_Sym) {
  D_Sym *s;

  if (!sym) return NULL;
  sym = current_D_Sym(st, sym);
  if (!sym) return NULL;
  s = MALLOC(sizeof_D_Sym);
  memcpy(s, sym, sizeof(D_Sym));
  if (sym->update_of) sym = sym->update_of;
  s->update_of = sym;
  s->next = st->updates;
  st->updates = s;
  return s;
}

/*
 * update_D_Sym - Update a symbol (creates new scope)
 * @sym: Symbol to update (may be NULL)
 * @pst: Pointer to current scope (updated to new scope)
 * @sizeof_D_Sym: Size of symbol structure
 *
 * Creates a new version of a symbol AND a new scope for speculative parsing.
 * This is the primary way to update symbols during parsing.
 *
 * The function:
 * 1. Creates new scope with enter_D_Scope(*pst, *pst)
 * 2. Creates new symbol version in that scope
 * 3. Updates *pst to point to new scope
 *
 * Use this for the FIRST update in a production. For subsequent updates
 * in the same production, use update_additional_D_Sym().
 *
 * Returns NULL if @sym is NULL (safe to call on failed lookups).
 *
 * Example:
 *   D_Sym *var = find_D_Sym(scope, "x", NULL);
 *   var = UPDATE_D_SYM(var, &scope);  // scope is updated!
 *   var->user.value = new_value;
 *
 * Macro: Use UPDATE_D_SYM(sym, pst) for standard symbol size.
 *
 * Returns: New symbol version, or NULL if sym is NULL
 */
D_Sym *update_D_Sym(D_Sym *sym, D_Scope **pst, int sizeof_D_Sym) {
  if (!sym) return NULL;
  *pst = enter_D_Scope(*pst, *pst);
  return update_additional_D_Sym(*pst, sym, sizeof_D_Sym);
}

void print_sym(D_Sym *s) {
  char *c = (char *)MALLOC(s->len + 1);
  if (s->len) memcpy(c, s->name, s->len);
  c[s->len] = 0;
  printf("%s, ", c);
  FREE(c);
}

void print_scope(D_Scope *st) {
  printf("SCOPE %p: ", (void *)st);
  printf("  owned: %d, kind: %d, ", st->owned_by_user, st->kind);
  if (st->ll) printf("  LL\n");
  if (st->hash) printf("  HASH\n");
  if (st->hash) {
    uint i;
    for (i = 0; i < st->hash->syms.n; i++)
      if (st->hash->syms.v[i]) print_sym(st->hash->syms.v[i]);
  } else {
    D_Sym *ll = st->ll;
    while (ll) {
      print_sym(ll);
      ll = ll->next;
    }
  }
  printf("\n\n");
  if (st->dynamic) print_scope(st->dynamic);
  if (st->search) print_scope(st->search);
}
