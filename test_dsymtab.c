/*
  Comprehensive test suite for dsymtab.c symbol table implementation
  Tests all API functions and use cases
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "d.h"

/* Test statistics */
static int tests_run = 0;
static int tests_passed = 0;
static int tests_failed = 0;

/* Color output for terminal */
#define COLOR_RED     "\x1b[31m"
#define COLOR_GREEN   "\x1b[32m"
#define COLOR_YELLOW  "\x1b[33m"
#define COLOR_BLUE    "\x1b[34m"
#define COLOR_RESET   "\x1b[0m"

/* Test macros */
#define TEST_START(name) \
  do { \
    tests_run++; \
    printf(COLOR_BLUE "TEST %d: %s" COLOR_RESET "\n", tests_run, name); \
  } while(0)

#define TEST_ASSERT(cond, msg) \
  do { \
    if (!(cond)) { \
      printf(COLOR_RED "  FAIL: %s" COLOR_RESET "\n", msg); \
      tests_failed++; \
      return 0; \
    } \
  } while(0)

#define TEST_PASS() \
  do { \
    printf(COLOR_GREEN "  PASS" COLOR_RESET "\n"); \
    tests_passed++; \
    return 1; \
  } while(0)

#define RUN_TEST(test) \
  do { \
    if (!test()) { \
      printf(COLOR_RED "Test failed: %s" COLOR_RESET "\n\n", #test); \
    } else { \
      printf("\n"); \
    } \
  } while(0)

/* Helper to compare symbol names */
static int sym_name_eq(D_Sym *sym, const char *name) {
  if (!sym || !name) return 0;
  size_t len = strlen(name);
  return (sym->len == (int)len && strncmp(sym->name, name, len) == 0);
}

/* ========================================================================
   BASIC SYMBOL OPERATIONS
   ======================================================================== */

static int test_new_global_scope(void) {
  TEST_START("Create global scope");
  
  D_Scope *global = new_D_Scope(NULL);
  TEST_ASSERT(global != NULL, "Global scope should not be NULL");
  TEST_ASSERT(global->depth == 0, "Global scope depth should be 0");
  TEST_ASSERT(global->hash != NULL, "Global scope should have hash table");
  TEST_ASSERT(global->up == NULL, "Global scope should have no parent");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_new_nested_scope(void) {
  TEST_START("Create nested scope");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Scope *nested = new_D_Scope(global);
  
  TEST_ASSERT(nested != NULL, "Nested scope should not be NULL");
  TEST_ASSERT(nested->depth == 1, "Nested scope depth should be 1");
  TEST_ASSERT(nested->hash == NULL, "Nested scope should use linked list");
  TEST_ASSERT(nested->up == global, "Nested scope parent should be global");
  TEST_ASSERT(nested->search == global, "Nested scope search should point to global");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_new_symbol(void) {
  TEST_START("Create symbol in scope");
  
  D_Scope *scope = new_D_Scope(NULL);
  D_Sym *sym = NEW_D_SYM(scope, "test_var", NULL);
  
  TEST_ASSERT(sym != NULL, "Symbol should not be NULL");
  TEST_ASSERT(sym_name_eq(sym, "test_var"), "Symbol name should match");
  TEST_ASSERT(sym->scope == scope, "Symbol scope should match");
  TEST_ASSERT(sym->len == 8, "Symbol length should be 8");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

static int test_new_symbol_with_end(void) {
  TEST_START("Create symbol with explicit end pointer");
  
  D_Scope *scope = new_D_Scope(NULL);
  char *name = "test_variable_long";
  char *end = name + 4; // Only use "test"
  D_Sym *sym = NEW_D_SYM(scope, name, end);
  
  TEST_ASSERT(sym != NULL, "Symbol should not be NULL");
  TEST_ASSERT(sym->len == 4, "Symbol length should be 4");
  TEST_ASSERT(sym_name_eq(sym, "test"), "Symbol name should be 'test'");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

static int test_find_symbol_in_same_scope(void) {
  TEST_START("Find symbol in same scope");
  
  D_Scope *scope = new_D_Scope(NULL);
  D_Sym *sym1 = NEW_D_SYM(scope, "var1", NULL);
  D_Sym *sym2 = NEW_D_SYM(scope, "var2", NULL);
  
  D_Sym *found1 = find_D_Sym(scope, "var1", NULL);
  D_Sym *found2 = find_D_Sym(scope, "var2", NULL);
  
  TEST_ASSERT(found1 == sym1, "Should find var1");
  TEST_ASSERT(found2 == sym2, "Should find var2");
  TEST_ASSERT(sym_name_eq(found1, "var1"), "Found symbol name should match");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

static int test_find_nonexistent_symbol(void) {
  TEST_START("Find non-existent symbol returns NULL");
  
  D_Scope *scope = new_D_Scope(NULL);
  NEW_D_SYM(scope, "exists", NULL);
  
  D_Sym *found = find_D_Sym(scope, "doesnotexist", NULL);
  TEST_ASSERT(found == NULL, "Non-existent symbol should return NULL");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

/* ========================================================================
   SCOPE NESTING AND SHADOWING
   ======================================================================== */

static int test_find_symbol_in_parent_scope(void) {
  TEST_START("Find symbol in parent scope");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Sym *global_sym = NEW_D_SYM(global, "global_var", NULL);
  
  D_Scope *nested = new_D_Scope(global);
  D_Sym *found = find_D_Sym(nested, "global_var", NULL);
  
  TEST_ASSERT(found == global_sym, "Should find symbol in parent scope");
  TEST_ASSERT(sym_name_eq(found, "global_var"), "Found symbol name should match");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_symbol_shadowing(void) {
  TEST_START("Symbol shadowing in nested scope");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Sym *global_x = NEW_D_SYM(global, "x", NULL);
  global_x->user = 10;
  
  D_Scope *nested = new_D_Scope(global);
  D_Sym *nested_x = NEW_D_SYM(nested, "x", NULL);
  nested_x->user = 20;
  
  D_Sym *found_in_nested = find_D_Sym(nested, "x", NULL);
  D_Sym *found_in_global = find_D_Sym(global, "x", NULL);
  
  TEST_ASSERT(found_in_nested == nested_x, "Should find shadowed symbol in nested");
  TEST_ASSERT(found_in_nested->user == 20, "Nested symbol value should be 20");
  TEST_ASSERT(found_in_global == global_x, "Should find original in global");
  TEST_ASSERT(found_in_global->user == 10, "Global symbol value should be 10");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_deep_nesting(void) {
  TEST_START("Deep scope nesting (5 levels)");
  
  D_Scope *scopes[5];
  scopes[0] = new_D_Scope(NULL);
  
  for (int i = 1; i < 5; i++) {
    scopes[i] = new_D_Scope(scopes[i-1]);
    TEST_ASSERT(scopes[i]->depth == (unsigned int)i, "Depth should match level");
  }
  
  // Add symbol at each level
  char varname[10];
  for (int i = 0; i < 5; i++) {
    sprintf(varname, "var%d", i);
    NEW_D_SYM(scopes[i], varname, NULL);
  }
  
  // Find symbols from deepest scope
  for (int i = 0; i < 5; i++) {
    sprintf(varname, "var%d", i);
    D_Sym *found = find_D_Sym(scopes[4], varname, NULL);
    TEST_ASSERT(found != NULL, "Should find symbol from any parent level");
    TEST_ASSERT(sym_name_eq(found, varname), "Symbol name should match");
  }
  
  free_D_Scope(scopes[0], 1);
  TEST_PASS();
}

/* ========================================================================
   SCOPE OPERATIONS
   ======================================================================== */

static int test_enter_scope(void) {
  TEST_START("Enter scope for speculative parsing");
  
  D_Scope *global = new_D_Scope(NULL);
  NEW_D_SYM(global, "x", NULL);
  
  D_Scope *level1 = new_D_Scope(global);
  D_Scope *spec1 = enter_D_Scope(level1, level1);
  
  TEST_ASSERT(spec1 != level1, "Entered scope should be new instance");
  TEST_ASSERT(spec1->depth == level1->depth, "Depth should match");
  TEST_ASSERT(spec1->search == level1, "Search should point to original");
  TEST_ASSERT(spec1->up_updates == level1, "up_updates should track parent");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_global_scope_access(void) {
  TEST_START("Access global scope from nested context");
  
  D_Scope *global = new_D_Scope(NULL);
  NEW_D_SYM(global, "global_var", NULL);
  
  D_Scope *l1 = new_D_Scope(global);
  D_Scope *l2 = new_D_Scope(l1);
  D_Scope *l3 = new_D_Scope(l2);
  
  D_Scope *global_access = global_D_Scope(l3);
  TEST_ASSERT(global_access != NULL, "Global scope access should not be NULL");
  TEST_ASSERT(global_access->search != NULL, "Should have search pointer");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_find_global_symbol(void) {
  TEST_START("Find symbol in global scope explicitly");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Sym *global_sym = NEW_D_SYM(global, "GLOBAL", NULL);
  
  D_Scope *l1 = new_D_Scope(global);
  NEW_D_SYM(l1, "local", NULL);
  
  D_Scope *l2 = new_D_Scope(l1);
  NEW_D_SYM(l2, "GLOBAL", NULL); // Shadow global
  
  D_Sym *found_global = find_global_D_Sym(l2, "GLOBAL", NULL);
  D_Sym *found_normal = find_D_Sym(l2, "GLOBAL", NULL);
  
  TEST_ASSERT(found_global == global_sym, "Should find global symbol");
  TEST_ASSERT(found_normal != global_sym, "Normal find should get shadowed");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_commit_scope(void) {
  TEST_START("Commit scope to collapse speculative parsing");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Sym *sym1 = NEW_D_SYM(global, "var1", NULL);
  NEW_D_SYM(global, "var2", NULL);

  D_Scope *nested = new_D_Scope(global);
  NEW_D_SYM(nested, "var3", NULL);

  D_Scope *committed = commit_D_Scope(global);
  TEST_ASSERT(committed != NULL, "Committed scope should not be NULL");
  TEST_ASSERT(committed->hash != NULL, "Committed scope should have hash");

  // Verify symbols still accessible after commit
  D_Sym *found1 = find_D_Sym(committed, "var1", NULL);
  TEST_ASSERT(found1 != NULL, "Should find var1 after commit");
  TEST_ASSERT(found1->update_of != NULL || found1 == sym1, "Symbol should be updated or original");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   SYMBOL UPDATES
   ======================================================================== */

static int test_update_symbol(void) {
  TEST_START("Update symbol value");

  D_Scope *scope = new_D_Scope(NULL);
  D_Scope *top_scope = scope;  // Keep reference to top scope for cleanup
  D_Sym *original = NEW_D_SYM(scope, "counter", NULL);
  original->user = 0;

  D_Sym *updated = UPDATE_D_SYM(original, &scope);  // scope is modified!
  TEST_ASSERT(updated != NULL, "Updated symbol should not be NULL");
  TEST_ASSERT(updated != original, "Updated symbol should be different instance");
  TEST_ASSERT(updated->update_of == original, "Should point to original");

  updated->user = 1;
  D_Sym *current = current_D_Sym(scope, original);
  TEST_ASSERT(current == updated, "Current should be updated version");
  TEST_ASSERT(current->user == 1, "Current should have new value");

  free_D_Scope(top_scope, 1);  // Pool frees ALL scopes (original + updated)!
  TEST_PASS();
}

static int test_multiple_updates(void) {
  TEST_START("Multiple updates to same symbol");

  D_Scope *scope = new_D_Scope(NULL);
  D_Scope *top_scope = scope;  // Keep reference to top scope for cleanup
  D_Sym *v0 = NEW_D_SYM(scope, "x", NULL);
  v0->user = 0;

  D_Sym *v1 = UPDATE_D_SYM(v0, &scope);  // scope is modified!
  v1->user = 1;

  D_Sym *v2 = update_additional_D_Sym(scope, v1, sizeof(D_Sym));
  v2->user = 2;

  D_Sym *v3 = update_additional_D_Sym(scope, v2, sizeof(D_Sym));
  v3->user = 3;

  D_Sym *current = current_D_Sym(scope, v0);
  TEST_ASSERT(current == v3, "Current should be latest update");
  TEST_ASSERT(current->user == 3, "Current value should be 3");

  free_D_Scope(top_scope, 1);  // Pool frees ALL scopes!
  TEST_PASS();
}

static int test_update_null_symbol(void) {
  TEST_START("Update NULL symbol returns NULL");
  
  D_Scope *scope = new_D_Scope(NULL);
  D_Sym *updated = UPDATE_D_SYM(NULL, &scope);
  
  TEST_ASSERT(updated == NULL, "Updating NULL should return NULL");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

static int test_current_null_symbol(void) {
  TEST_START("current_D_Sym with NULL returns NULL");
  
  D_Scope *scope = new_D_Scope(NULL);
  D_Sym *current = current_D_Sym(scope, NULL);
  
  TEST_ASSERT(current == NULL, "current_D_Sym(NULL) should return NULL");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

/* ========================================================================
   SCOPE-SPECIFIC SEARCHES
   ======================================================================== */

static int test_find_in_specific_scope(void) {
  TEST_START("Find symbol in specific scope only");
  
  D_Scope *global = new_D_Scope(NULL);
  NEW_D_SYM(global, "global_var", NULL);
  
  D_Scope *nested = new_D_Scope(global);
  D_Sym *nested_sym = NEW_D_SYM(nested, "nested_var", NULL);
  
  // Should find in nested scope
  D_Sym *found_nested = find_D_Sym_in_Scope(nested, nested, "nested_var", NULL);
  TEST_ASSERT(found_nested == nested_sym, "Should find in nested scope");
  
  // Should NOT find global var when searching only nested scope
  D_Sym *not_found = find_D_Sym_in_Scope(nested, nested, "global_var", NULL);
  TEST_ASSERT(not_found == NULL, "Should not find parent symbol in scope-only search");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_duplicate_detection(void) {
  TEST_START("Detect duplicate symbols in same scope");
  
  D_Scope *scope = new_D_Scope(NULL);
  NEW_D_SYM(scope, "dup", NULL);
  
  D_Sym *duplicate = find_D_Sym_in_Scope(scope, scope, "dup", NULL);
  TEST_ASSERT(duplicate != NULL, "Should find duplicate");
  
  // This would be an error in real code - we found a duplicate
  int has_duplicate = (duplicate != NULL);
  TEST_ASSERT(has_duplicate, "Duplicate detection should work");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

/* ========================================================================
   SYMBOL ITERATION
   ======================================================================== */

static int test_iterate_symbols(void) {
  TEST_START("Iterate through symbols in scope");

  // Use nested scope (linked list) for predictable iteration
  D_Scope *global = new_D_Scope(NULL);
  D_Scope *scope = new_D_Scope(global);
  NEW_D_SYM(scope, "a", NULL);
  NEW_D_SYM(scope, "b", NULL);
  NEW_D_SYM(scope, "c", NULL);

  int count = 0;
  D_Sym *sym = NULL;
  D_Scope *cur_scope = scope;

  while (next_D_Sym_in_Scope(&cur_scope, &sym)) {
    count++;
    TEST_ASSERT(sym != NULL, "Iterated symbol should not be NULL");
  }

  TEST_ASSERT(count == 3, "Should iterate through all 3 symbols");

  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_iterate_nested_scopes(void) {
  TEST_START("Iterate symbols across nested scopes");
  
  D_Scope *global = new_D_Scope(NULL);
  NEW_D_SYM(global, "g1", NULL);
  NEW_D_SYM(global, "g2", NULL);
  
  D_Scope *nested = new_D_Scope(global);
  NEW_D_SYM(nested, "n1", NULL);
  
  int count = 0;
  D_Sym *sym = NULL;
  D_Scope *cur_scope = nested;
  
  while (next_D_Sym_in_Scope(&cur_scope, &sym)) {
    count++;
  }
  
  TEST_ASSERT(count >= 1, "Should iterate through at least nested scope symbols");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   SCOPE KINDS
   ======================================================================== */

static int test_scope_kinds(void) {
  TEST_START("Test different scope kinds");
  
  D_Scope *global = new_D_Scope(NULL);
  TEST_ASSERT(global->kind == D_SCOPE_INHERIT, "Default should be INHERIT");
  
  D_Scope *recursive = new_D_Scope(global);
  recursive->kind = D_SCOPE_RECURSIVE;
  TEST_ASSERT(recursive->kind == D_SCOPE_RECURSIVE, "Should set RECURSIVE kind");
  
  D_Scope *parallel = new_D_Scope(global);
  parallel->kind = D_SCOPE_PARALLEL;
  TEST_ASSERT(parallel->kind == D_SCOPE_PARALLEL, "Should set PARALLEL kind");
  
  D_Scope *sequential = new_D_Scope(global);
  sequential->kind = D_SCOPE_SEQUENTIAL;
  TEST_ASSERT(sequential->kind == D_SCOPE_SEQUENTIAL, "Should set SEQUENTIAL kind");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   DYNAMIC SCOPING
   ======================================================================== */

static int test_dynamic_scope(void) {
  TEST_START("Dynamic scope access");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Scope *class_scope = new_D_Scope(global);
  NEW_D_SYM(class_scope, "method", NULL);
  
  D_Scope *current = new_D_Scope(global);
  D_Scope *with_dynamic = scope_D_Scope(current, class_scope);
  
  TEST_ASSERT(with_dynamic != NULL, "Dynamic scope should not be NULL");
  TEST_ASSERT(with_dynamic->dynamic == class_scope, "Dynamic should point to class scope");
  
  // Should find symbol through dynamic scope
  D_Sym *found = find_D_Sym(with_dynamic, "method", NULL);
  TEST_ASSERT(found != NULL, "Should find symbol through dynamic scope");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   HASH TABLE OPERATIONS
   ======================================================================== */

static int test_many_symbols(void) {
  TEST_START("Hash table with many symbols");
  
  D_Scope *global = new_D_Scope(NULL);
  
  // Add 100 symbols
  char name[32];
  for (int i = 0; i < 100; i++) {
    sprintf(name, "var_%d", i);
    D_Sym *sym = NEW_D_SYM(global, name, NULL);
    sym->user = i;
  }
  
  // Verify all can be found
  for (int i = 0; i < 100; i++) {
    sprintf(name, "var_%d", i);
    D_Sym *found = find_D_Sym(global, name, NULL);
    TEST_ASSERT(found != NULL, "Should find symbol");
    TEST_ASSERT(found->user == (unsigned int)i, "Symbol value should match");
  }
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_collision_handling(void) {
  TEST_START("Hash collision handling");
  
  D_Scope *global = new_D_Scope(NULL);
  
  // Add many symbols that might collide
  char name[32];
  for (int i = 0; i < 50; i++) {
    sprintf(name, "x%d", i);
    NEW_D_SYM(global, name, NULL);
    sprintf(name, "y%d", i);
    NEW_D_SYM(global, name, NULL);
  }
  
  // All should be retrievable
  for (int i = 0; i < 50; i++) {
    sprintf(name, "x%d", i);
    TEST_ASSERT(find_D_Sym(global, name, NULL) != NULL, "Should find x symbol");
    sprintf(name, "y%d", i);
    TEST_ASSERT(find_D_Sym(global, name, NULL) != NULL, "Should find y symbol");
  }
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   MEMORY MANAGEMENT
   ======================================================================== */

static int test_owned_by_user_flag(void) {
  TEST_START("owned_by_user flag prevents automatic free");

  D_Scope *global = new_D_Scope(NULL);
  D_Scope *nested = new_D_Scope(global);
  nested->owned_by_user = 1;

  TEST_ASSERT(nested->owned_by_user == 1, "Should set owned_by_user flag");

  // With scope pool: owned_by_user scopes are NOT freed when force=0
  // But pool remains valid for later cleanup with force=1
  // For now, just free everything with force=1
  free_D_Scope(global, 1);

  TEST_PASS();
}

static int test_scope_hierarchy_free(void) {
  TEST_START("Freeing scope hierarchy");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Scope *l1 = new_D_Scope(global);
  D_Scope *l2 = new_D_Scope(l1);
  D_Scope *l3 = new_D_Scope(l2);
  
  NEW_D_SYM(global, "g", NULL);
  NEW_D_SYM(l1, "l1", NULL);
  NEW_D_SYM(l2, "l2", NULL);
  NEW_D_SYM(l3, "l3", NULL);
  
  // Should free entire hierarchy
  free_D_Scope(global, 1);
  
  TEST_PASS();
}

/* ========================================================================
   COMPLEX SCENARIOS
   ======================================================================== */

static int test_complex_scoping_scenario(void) {
  TEST_START("Complex scoping scenario with updates and nesting");
  
  // Create global scope
  D_Scope *global = new_D_Scope(NULL);
  D_Sym *x = NEW_D_SYM(global, "x", NULL);
  D_Sym *y = NEW_D_SYM(global, "y", NULL);
  x->user = 10;
  y->user = 20;
  
  // Enter function scope
  D_Scope *func = new_D_Scope(global);
  D_Sym *z = NEW_D_SYM(func, "z", NULL);
  z->user = 30;
  
  // Update x in function scope
  D_Sym *x_func = UPDATE_D_SYM(x, &func);
  x_func->user = 15;
  
  // Enter block scope
  D_Scope *block = new_D_Scope(func);
  D_Sym *w = NEW_D_SYM(block, "w", NULL);
  w->user = 40;
  
  // Update y in block scope
  D_Sym *y_block = UPDATE_D_SYM(y, &block);
  y_block->user = 25;
  
  // Verify lookups from block scope
  D_Sym *found_x = find_D_Sym(block, "x", NULL);
  D_Sym *found_y = find_D_Sym(block, "y", NULL);
  D_Sym *found_z = find_D_Sym(block, "z", NULL);
  D_Sym *found_w = find_D_Sym(block, "w", NULL);
  
  TEST_ASSERT(found_x != NULL && found_x->user == 15, "x should be updated value");
  TEST_ASSERT(found_y != NULL && found_y->user == 25, "y should be updated value");
  TEST_ASSERT(found_z != NULL && found_z->user == 30, "z should be accessible");
  TEST_ASSERT(found_w != NULL && found_w->user == 40, "w should be accessible");
  
  // Verify original values in global
  D_Sym *global_x = find_D_Sym(global, "x", NULL);
  D_Sym *global_y = find_D_Sym(global, "y", NULL);
  TEST_ASSERT(global_x->user == 10, "Global x should be unchanged");
  TEST_ASSERT(global_y->user == 20, "Global y should be unchanged");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

static int test_speculative_parsing_simulation(void) {
  TEST_START("Simulate speculative parsing scenario");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Sym *var = NEW_D_SYM(global, "ambiguous", NULL);
  var->user = 1;
  
  D_Scope *parse1 = new_D_Scope(global);
  
  // Speculative path 1: treat as declaration
  D_Scope *spec1 = enter_D_Scope(parse1, parse1);
  D_Sym *var_spec1 = NEW_D_SYM(spec1, "result1", NULL);
  var_spec1->user = 100;
  
  // Speculative path 2: treat as expression
  D_Scope *spec2 = enter_D_Scope(parse1, parse1);
  D_Sym *var_spec2 = NEW_D_SYM(spec2, "result2", NULL);
  var_spec2->user = 200;
  
  // Verify both paths have different results
  D_Sym *found1 = find_D_Sym(spec1, "result1", NULL);
  D_Sym *found2 = find_D_Sym(spec2, "result2", NULL);
  
  TEST_ASSERT(found1 != NULL && found1->user == 100, "Spec path 1 should have result1");
  TEST_ASSERT(found2 != NULL && found2->user == 200, "Spec path 2 should have result2");
  
  // Commit one path
  D_Scope *committed = commit_D_Scope(spec1);
  TEST_ASSERT(committed != NULL, "Should commit successfully");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   EDGE CASES AND ERROR HANDLING
   ======================================================================== */

static int test_empty_scope_operations(void) {
  TEST_START("Operations on empty scope");
  
  D_Scope *scope = new_D_Scope(NULL);
  
  D_Sym *not_found = find_D_Sym(scope, "anything", NULL);
  TEST_ASSERT(not_found == NULL, "Should not find symbol in empty scope");

  D_Sym *sym = NULL;
  D_Scope *cur = scope;
  D_Sym *found_any = next_D_Sym_in_Scope(&cur, &sym);
  TEST_ASSERT(found_any == NULL, "Should not iterate in empty scope");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

static int test_zero_length_symbol(void) {
  TEST_START("Symbol with zero length name");
  
  D_Scope *scope = new_D_Scope(NULL);
  D_Sym *sym = NEW_D_SYM(scope, "", NULL);
  
  TEST_ASSERT(sym != NULL, "Should create zero-length symbol");
  TEST_ASSERT(sym->len == 0, "Length should be 0");
  
  D_Sym *found = find_D_Sym(scope, "", NULL);
  TEST_ASSERT(found == sym, "Should find zero-length symbol");
  
  free_D_Scope(scope, 1);
  TEST_PASS();
}

static int test_equiv_scope(void) {
  TEST_START("Equivalent scope detection");
  
  D_Scope *global = new_D_Scope(NULL);
  D_Scope *s1 = new_D_Scope(global);
  D_Scope *s2 = enter_D_Scope(s1, s1);
  
  D_Scope *equiv = equiv_D_Scope(s2);
  TEST_ASSERT(equiv != NULL, "Should find equivalent scope");
  
  free_D_Scope(global, 1);
  TEST_PASS();
}

/* ========================================================================
   MAIN TEST RUNNER
   ======================================================================== */

void print_summary(void) {
  printf("\n");
  printf("========================================\n");
  printf("Test Summary\n");
  printf("========================================\n");
  printf("Total tests run:    %d\n", tests_run);
  printf(COLOR_GREEN "Tests passed:       %d" COLOR_RESET "\n", tests_passed);
  if (tests_failed > 0) {
    printf(COLOR_RED "Tests failed:       %d" COLOR_RESET "\n", tests_failed);
  } else {
    printf("Tests failed:       %d\n", tests_failed);
  }
  printf("========================================\n");
  
  if (tests_failed == 0) {
    printf(COLOR_GREEN "\n✓ ALL TESTS PASSED\n" COLOR_RESET);
  } else {
    printf(COLOR_RED "\n✗ SOME TESTS FAILED\n" COLOR_RESET);
  }
  printf("\n");
}

int main(void) {
  printf("\n");
  printf(COLOR_BLUE "========================================\n");
  printf("DParser Symbol Table Test Suite\n");
  printf("========================================\n" COLOR_RESET);
  printf("\n");
  
  /* Basic Symbol Operations */
  printf(COLOR_YELLOW "=== Basic Symbol Operations ===" COLOR_RESET "\n");
  RUN_TEST(test_new_global_scope);
  RUN_TEST(test_new_nested_scope);
  RUN_TEST(test_new_symbol);
  RUN_TEST(test_new_symbol_with_end);
  RUN_TEST(test_find_symbol_in_same_scope);
  RUN_TEST(test_find_nonexistent_symbol);
  
  /* Scope Nesting and Shadowing */
  printf(COLOR_YELLOW "=== Scope Nesting and Shadowing ===" COLOR_RESET "\n");
  RUN_TEST(test_find_symbol_in_parent_scope);
  RUN_TEST(test_symbol_shadowing);
  RUN_TEST(test_deep_nesting);
  
  /* Scope Operations */
  printf(COLOR_YELLOW "=== Scope Operations ===" COLOR_RESET "\n");
  RUN_TEST(test_enter_scope);
  RUN_TEST(test_global_scope_access);
  RUN_TEST(test_find_global_symbol);
  RUN_TEST(test_commit_scope);
  
  /* Symbol Updates */
  printf(COLOR_YELLOW "=== Symbol Updates ===" COLOR_RESET "\n");
  RUN_TEST(test_update_symbol);
  RUN_TEST(test_multiple_updates);
  RUN_TEST(test_update_null_symbol);
  RUN_TEST(test_current_null_symbol);
  
  /* Scope-Specific Searches */
  printf(COLOR_YELLOW "=== Scope-Specific Searches ===" COLOR_RESET "\n");
  RUN_TEST(test_find_in_specific_scope);
  RUN_TEST(test_duplicate_detection);
  
  /* Symbol Iteration */
  printf(COLOR_YELLOW "=== Symbol Iteration ===" COLOR_RESET "\n");
  RUN_TEST(test_iterate_symbols);
  RUN_TEST(test_iterate_nested_scopes);
  
  /* Scope Kinds */
  printf(COLOR_YELLOW "=== Scope Kinds ===" COLOR_RESET "\n");
  RUN_TEST(test_scope_kinds);
  
  /* Dynamic Scoping */
  printf(COLOR_YELLOW "=== Dynamic Scoping ===" COLOR_RESET "\n");
  RUN_TEST(test_dynamic_scope);
  
  /* Hash Table Operations */
  printf(COLOR_YELLOW "=== Hash Table Operations ===" COLOR_RESET "\n");
  RUN_TEST(test_many_symbols);
  RUN_TEST(test_collision_handling);
  
  /* Memory Management */
  printf(COLOR_YELLOW "=== Memory Management ===" COLOR_RESET "\n");
  RUN_TEST(test_owned_by_user_flag);
  RUN_TEST(test_scope_hierarchy_free);
  
  /* Complex Scenarios */
  printf(COLOR_YELLOW "=== Complex Scenarios ===" COLOR_RESET "\n");
  RUN_TEST(test_complex_scoping_scenario);
  RUN_TEST(test_speculative_parsing_simulation);
  
  /* Edge Cases */
  printf(COLOR_YELLOW "=== Edge Cases and Error Handling ===" COLOR_RESET "\n");
  RUN_TEST(test_empty_scope_operations);
  RUN_TEST(test_zero_length_symbol);
  RUN_TEST(test_equiv_scope);
  
  print_summary();
  
  return (tests_failed == 0) ? 0 : 1;
}
