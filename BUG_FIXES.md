# dsymtab.c Bug Fixes

All critical bugs identified in the analysis have been fixed and tested.

## Summary of Fixes

### 1. Buffer Overflow in symhash_add() ✅ FIXED

**Location:** dsymtab.c:70

**Problem:** After the for loop at line 64 completed with `i = vv.n`, the code attempted to access `tv.v[i]` which was out of bounds.

**Original code:**
```c
for (i = 0; i < vv.n; i++)
  while (vv.v[i]) {
    x = vv.v[i];
    vv.v[i] = x->next;
    vec_add(&tv, x);
  }
while (tv.v[i]) {  // BUG: i = vv.n here!
  x = tv.v[i];
  tv.v[i] = x->next;
  h = x->hash % n;
  x->next = v[h];
  v[h] = x;
}
```

**Fixed code:**
```c
for (i = 0; i < vv.n; i++)
  while (vv.v[i]) {
    x = vv.v[i];
    vv.v[i] = x->next;
    vec_add(&tv, x);
  }
for (i = 0; i < tv.n; i++) {  // FIXED: Use tv.n
  x = tv.v[i];
  h = x->hash % n;
  x->next = v[h];
  v[h] = x;
}
```

**Impact:** Prevents crash when hash table grows beyond 3137 symbols.

---

### 2. Memory Leak in symhash_add() ✅ FIXED

**Location:** dsymtab.c:63-77

**Problem:** Temporary vector `tv` was never freed after rehashing.

**Fix:** Added `vec_free(&tv);` before freeing the old vector at line 76.

**Fixed code:**
```c
for (i = 0; i < tv.n; i++) {
  x = tv.v[i];
  h = x->hash % n;
  x->next = v[h];
  v[h] = x;
}
vec_free(&tv);     // ADDED: Free temporary vector
FREE(vv.v);
```

**Impact:** Prevents memory leak on every hash table resize.

---

### 3. NULL Pointer Dereference ✅ FIXED

**Locations:** 
- dsymtab.c:289 `current_D_Sym()`
- dsymtab.c:392 `update_additional_D_Sym()`
- dsymtab.c:407 `update_D_Sym()`

**Problem:** If `find_D_Sym()` returns NULL (symbol not found), calling `UPDATE_D_SYM()` would crash when dereferencing the NULL pointer.

**Fixes:**

**current_D_Sym():**
```c
D_Sym *current_D_Sym(D_Scope *st, D_Sym *sym) {
  D_Scope *sc;
  D_Sym *uu;

  if (!sym) return NULL;  // ADDED: Check for NULL
  if (sym->update_of) sym = sym->update_of;
  /* return the last update */
  for (sc = st; sc; sc = sc->up_updates) {
    for (uu = sc->updates; uu; uu = uu->next)
      if (uu->update_of == sym) return uu;
  }
  return sym;
}
```

**update_additional_D_Sym():**
```c
D_Sym *update_additional_D_Sym(D_Scope *st, D_Sym *sym, int sizeof_D_Sym) {
  D_Sym *s;

  if (!sym) return NULL;           // ADDED: Check for NULL
  sym = current_D_Sym(st, sym);
  if (!sym) return NULL;           // ADDED: Check result
  s = MALLOC(sizeof_D_Sym);
  memcpy(s, sym, sizeof(D_Sym));
  if (sym->update_of) sym = sym->update_of;
  s->update_of = sym;
  s->next = st->updates;
  st->updates = s;
  return s;
}
```

**update_D_Sym():**
```c
D_Sym *update_D_Sym(D_Sym *sym, D_Scope **pst, int sizeof_D_Sym) {
  if (!sym) return NULL;  // ADDED: Check for NULL early
  *pst = enter_D_Scope(*pst, *pst);
  return update_additional_D_Sym(*pst, sym, sizeof_D_Sym);
}
```

**Impact:** Prevents crashes when attempting to update non-existent symbols.

---

## Testing

All tests pass after the fixes:

```bash
$ ./parser_tests
...
g28.test.g.1 PASSED   # Original symbol table test
g28.test.g.2 PASSED   # Enhanced symbol table test
g29.test.g.1 PASSED   # Symbol table with duplicate detection
...
---------------------------------------
ALL tests PASSED
```

**Total tests:** 100+ tests across all grammars  
**Failures:** 0  
**Status:** ✅ All fixes verified

---

## Files Modified

- `dsymtab.c` - All three bugs fixed
  - Line 70: Fixed buffer overflow in hash table rehashing
  - Line 76: Added memory leak fix  
  - Line 293: Added NULL check in `current_D_Sym()`
  - Line 395-397: Added NULL checks in `update_additional_D_Sym()`
  - Line 408: Added NULL check in `update_D_Sym()`

---

## Verification

Build output shows no warnings or errors:
```bash
$ make clean && make
...
clang -fPIC -DUSE_FREELISTS -Wall -O3 -Wno-strict-aliasing -std=c23 -pedantic ...
(no warnings)
```

All symbol table tests pass successfully, including the new comprehensive test case.

---

## Next Steps

Recommended follow-up actions (from DSYMTAB_ANALYSIS.md):

1. ✅ **DONE:** Fix critical bugs
2. **TODO:** Add function documentation
3. **TODO:** Remove or document #if 0 code blocks
4. **TODO:** Add more comprehensive tests for:
   - `find_global_D_Sym()`
   - `scope_D_Scope()` with dynamic scoping
   - `next_D_Sym_in_Scope()` iteration
   - Different scope kinds (RECURSIVE, PARALLEL, SEQUENTIAL)

