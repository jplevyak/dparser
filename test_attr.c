/*
  Attributes after parsing (dattr.h): a typed language with a synthesized
  `type` and an inherited `env` copied down through the tree, rule numbers
  from d_get_production, a shared parse node, a cycle, and freeing.
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "dattr.h"
#include "test_attr.g.d_parser.h"

extern D_ParserTables parser_tables_attr;

static int failed;

static void expect(const char *name, int ok) {
  printf("%-44s %s\n", name, ok ? "ok" : "FAILED");
  if (!ok) failed++;
}

static const char *sym(D_AttrTree *t, D_AttrNode *n) { return d_attr_symbol_name(t, n); }

static int is(D_AttrTree *t, D_AttrNode *n, const char *name) { return !strcmp(sym(t, n), name); }

/* The text of a node, in a static buffer. */
static const char *text(D_AttrNode *n) {
  static char buf[64];
  D_ParseNode *pn = d_attr_parse_node(n);
  int len = (int)(pn->end - pn->start_loc.s);
  if (len > 63) len = 63;
  memcpy(buf, pn->start_loc.s, len);
  buf[len] = 0;
  return buf;
}

/* ---- the typed language ---- */

typedef struct Var {
  char name[16];
  const char *type;
  struct Var *next;
} Var;

/* Every Var is kept here and freed with the tree's context. */
typedef struct {
  Var *all[256];
  int n;
  int type_defined, type_freed, env_equations;
} Ctx;

static D_Attr attr_env, attr_type;

static void collect_decls(D_AttrTree *t, D_AttrNode *n, Var **env) {
  int i;
  if (is(t, n, "block")) return; /* nested blocks have their own */
  if (is(t, n, "decl")) {
    Ctx *c = d_attr_ctx(t);
    Var *v = calloc(1, sizeof(Var));
    snprintf(v->name, sizeof(v->name), "%s", text(d_attr_child(n, 1)));
    v->type = strcmp(text(d_attr_child(n, 3)), "int") ? "bool" : "int";
    v->next = *env;
    *env = v;
    c->all[c->n++] = v;
    return;
  }
  for (i = 0; i < d_attr_n_children(n); i++) collect_decls(t, d_attr_child(n, i), env);
}

/* env (inherited): empty at the root; a block gives its children its own
   env plus its declarations.  Everything else copies its env down. */
static int eval_env(D_AttrTree *t, D_Attr *attr, D_AttrNode *node, int child, void *out) {
  (void)attr;
  Var **o = out;
  if (child < 0) {
    *o = NULL;
    return 1;
  }
  if (!is(t, node, "block")) return 0;
  ((Ctx *)d_attr_ctx(t))->env_equations++;
  *o = *(Var **)d_attr_get(t, node, &attr_env);
  for (int i = 0; i < d_attr_n_children(node); i++) collect_decls(t, d_attr_child(node, i), o);
  return 1;
}

static const char *type_of(D_AttrTree *t, D_AttrNode *n) {
  const char **v = d_attr_get(t, n, &attr_type);
  return v ? *v : NULL;
}

/* type (synthesized), for expr, name and number. */
static int eval_type(D_AttrTree *t, D_Attr *attr, D_AttrNode *node, int child, void *out) {
  (void)attr;
  const char **o = out;
  (void)child;
  if (is(t, node, "number")) {
    *o = "int";
  } else if (is(t, node, "name")) {
    Var *v = *(Var **)d_attr_get(t, node, &attr_env);
    while (v && strcmp(v->name, text(node))) v = v->next;
    *o = v ? v->type : "undefined";
  } else if (is(t, node, "expr")) {
    int p = d_attr_production(node);
    if (p == D_RULE_expr_0 || p == D_RULE_expr_1) {
      const char *a = type_of(t, d_attr_child(node, 0)), *b = type_of(t, d_attr_child(node, 2));
      if (p == D_RULE_expr_0)
        *o = !strcmp(a, "int") && !strcmp(b, "int") ? "int" : "error";
      else
        *o = !strcmp(a, b) ? "bool" : "error";
    } else { /* name, number or 'true': these rules share one reduction */
      D_AttrNode *c = d_attr_child(node, 0);
      *o = is(t, c, "name") || is(t, c, "number") ? type_of(t, c) : "bool";
    }
  } else
    return 0;
  ((Ctx *)d_attr_ctx(t))->type_defined++;
  return 1;
}

static void free_type(D_Attr *a, void *value) {
  (void)a;
  (void)value;
  (*(int *)a->data)++;
}
static int type_frees;

static D_Attr attr_env = {"env", D_ATTR_INH, eval_env, sizeof(Var *), NULL, NULL};
static D_Attr attr_type = {"type", D_ATTR_SYN, eval_type, sizeof(const char *), free_type, &type_frees};

/* The types of the statements' expressions, in order, joined with ' '. */
static void stmt_types(D_AttrTree *t, D_AttrNode *n, char *out, D_AttrNode **y_name) {
  int i;
  if (is(t, n, "stmt") && is(t, d_attr_child(n, 0), "expr")) {
    strcat(out, *out ? " " : "");
    strcat(out, type_of(t, d_attr_child(n, 0)));
  }
  if (is(t, n, "name") && !strcmp(text(n), "y") && is(t, d_attr_parent(n), "expr") && !*y_name) *y_name = n;
  for (i = 0; i < d_attr_n_children(n); i++) stmt_types(t, d_attr_child(n, i), out, y_name);
}

static D_Parser *parser(const char *start, int save) {
  D_Parser *p = new_D_Parser(&parser_tables_attr, 0);
  p->save_parse_tree = save;
  for (unsigned i = 0; i < parser_tables_attr.nsymbols; i++)
    if (parser_tables_attr.symbols[i].kind == D_SYMBOL_NTERM && !strcmp(parser_tables_attr.symbols[i].name, start))
      p->start_state = parser_tables_attr.symbols[i].start_symbol;
  return p;
}

static void typed_language(void) {
  const char *src = "{ var x : int; var b : bool; x + 1; x == 2; { var y : int; y + x; } b + 1; z; true == b; }";
  D_Parser *p = parser("program", 1);
  D_ParseNode *pn = dparse(p, (char *)src, (int)strlen(src));
  D_Attr *attrs[] = {&attr_env, &attr_type};
  Ctx ctx;
  char types[256] = "";
  D_AttrNode *y = NULL, *owner;
  memset(&ctx, 0, sizeof(ctx));
  expect("typed language parses", pn && !p->syntax_errors);
  D_AttrTree *t = d_attr_tree(p, pn, attrs, 2, &ctx);
  stmt_types(t, d_attr_root(t), types, &y);
  expect("types", !strcmp(types, "int bool int error undefined bool"));
  if (strcmp(types, "int bool int error undefined bool")) printf("  got: %s\n", types);

  /* env at y is the nested block's, copied down to it, not recomputed */
  owner = y;
  while (d_attr_parent(owner) && !is(t, d_attr_parent(owner), "block")) owner = d_attr_parent(owner);
  expect("copy-down shares the block's value",
         y && d_attr_get(t, y, &attr_env) == d_attr_get(t, owner, &attr_env) && owner != y);

  /* rule numbers */
  {
    D_AttrNode *n = y;
    while (n && !is(t, n, "expr")) n = d_attr_parent(n);       /* expr: name */
    D_AttrNode *sum = d_attr_parent(n);                          /* expr: expr '+' expr */
    expect("d_get_production: expr '+' expr", d_attr_production(sum) == D_RULE_expr_0);
    expect("d_get_production: shared reduction", d_attr_production(n) == D_RULE_expr_2 &&
                                                     D_RULE_expr_2 == D_RULE_expr_3);
    expect("d_get_production: terminal is -1", d_attr_production(d_attr_child(sum, 1)) == -1);
    expect("d_get_production: block", d_attr_production(d_attr_parent(owner)) == D_RULE_block_0);
    expect("d_get_production: stmt* list node is -1", d_attr_production(owner) == -1);
  }
  expect("no cycles", d_attr_cycles(t) == 0);
  type_frees = 0;
  d_attr_tree_free(t);
  expect("each computed type is freed once", type_frees == ctx.type_defined && type_frees > 0);
  for (int i = 0; i < ctx.n; i++) free(ctx.all[i]);
  free_D_ParseNode(p, pn);
  free_D_Parser(p);
}

/* ---- a shared node ---- */

static int eval_slot(D_AttrTree *t, D_Attr *attr, D_AttrNode *node, int child, void *out) {
  (void)attr;
  (void)t;
  (void)node;
  if (child < 0) return 0;
  *(int *)out = child;
  return 1;
}
static D_Attr attr_slot = {"slot", D_ATTR_INH, eval_slot, sizeof(int), NULL, NULL};

static void shared_node(void) {
  D_Parser *p = parser("pair", 1);
  D_ParseNode *pn = dparse(p, "p", 1);
  D_Attr *attrs[] = {&attr_slot};
  D_AttrTree *t = d_attr_tree(p, pn, attrs, 1, NULL);
  D_AttrNode *root = d_attr_root(t), *a = d_attr_child(root, 1), *b = d_attr_child(root, 2);
  expect("pair parses", pn && d_attr_n_children(root) == 3);
  expect("the two opt children share a parse node", d_attr_parse_node(a) == d_attr_parse_node(b) && a != b);
  expect("each occurrence gets its own inherited value",
         *(int *)d_attr_get(t, a, &attr_slot) == 1 && *(int *)d_attr_get(t, b, &attr_slot) == 2);
  expect("undefined at the root", d_attr_get(t, root, &attr_slot) == NULL);
  d_attr_tree_free(t);
  free_D_ParseNode(p, pn);
  free_D_Parser(p);
}

/* ---- a cycle ---- */

static D_Attr attr_a, attr_b;
static int eval_a(D_AttrTree *t, D_Attr *attr, D_AttrNode *node, int child, void *out) {
  (void)attr;
  int *b = d_attr_get(t, d_attr_child(node, 0), &attr_b);
  (void)child;
  *(int *)out = b ? *b + 1 : -1;
  return 1;
}
static int eval_b(D_AttrTree *t, D_Attr *attr, D_AttrNode *node, int child, void *out) {
  (void)attr;
  int *a;
  if (child < 0) return 0;
  a = d_attr_get(t, node, &attr_a);
  *(int *)out = a ? *a : -1;
  return 1;
}
static D_Attr attr_a = {"a", D_ATTR_SYN, eval_a, sizeof(int), NULL, NULL};
static D_Attr attr_b = {"b", D_ATTR_INH, eval_b, sizeof(int), NULL, NULL};

static char cycle_report[256];
static void record_cycle(D_AttrTree *t, int n, D_AttrNode **nodes, D_Attr **attrs) {
  cycle_report[0] = 0;
  for (int i = 0; i < n; i++) {
    strcat(cycle_report, i ? " -> " : "");
    strcat(cycle_report, attrs[i]->name);
    strcat(cycle_report, "@");
    strcat(cycle_report, d_attr_symbol_name(t, nodes[i]));
  }
}

static void cycle(void) {
  D_Parser *p = parser("cyc", 1);
  D_ParseNode *pn = dparse(p, "c", 1);
  D_Attr *attrs[] = {&attr_a, &attr_b};
  D_AttrTree *t = d_attr_tree(p, pn, attrs, 2, NULL);
  int *a;
  d_attr_set_cycle_fn(t, record_cycle);
  a = d_attr_get(t, d_attr_root(t), &attr_a);
  expect("cycle is reported once", d_attr_cycles(t) == 1);
  expect("cycle chain", !strcmp(cycle_report, "a@cyc -> b@c -> a@cyc"));
  if (strcmp(cycle_report, "a@cyc -> b@c -> a@cyc")) printf("  got: %s\n", cycle_report);
  expect("the outer value is computed from NULL", a && *a == 0);
  d_attr_tree_free(t);
  free_D_ParseNode(p, pn);
  free_D_Parser(p);
}

static void no_saved_tree(void) {
  D_Parser *p = parser("cyc", 0);
  D_ParseNode *pn = dparse(p, "c", 1);
  D_Attr *attrs[] = {&attr_a};
  expect("no saved tree: no attribute tree", d_attr_tree(p, pn, attrs, 1, NULL) == NULL);
  free_D_ParseNode(p, pn);
  free_D_Parser(p);
}

int main(void) {
  setvbuf(stdout, NULL, _IONBF, 0);
  typed_language();
  shared_node();
  cycle();
  no_saved_tree();
  if (failed) {
    printf("%d attribute tests FAILED\n", failed);
    return 1;
  }
  printf("all attribute tests passed\n");
  return 0;
}
