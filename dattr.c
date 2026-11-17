/*
  Attributes after parsing (see dattr.h).

  The attribute tree is a copy of the saved parse tree with parent links.
  Each node has one slot per attribute: its state, and a pointer to its
  value, which is either the node's own storage or, for an inherited
  attribute copied down, the value of an ancestor.
*/
#include "d.h"
#include "dattr.h"

enum { SLOT_UNEVALUATED, SLOT_IN_PROGRESS, SLOT_DONE, SLOT_UNDEFINED };

struct D_AttrNode {
  D_AttrNode *parent;
  int index;
  int n_children;
  D_AttrNode **children;
  D_ParseNode *pn;
  unsigned char *state; /* per attribute */
  void **value;         /* per attribute: the value, or NULL */
  char *storage;        /* the node's own value storage */
};

struct D_AttrTree {
  D_Parser *parser;
  void *ctx;
  D_Attr **attrs;
  int n_attrs;
  int *offset; /* of each attribute's storage within a node's storage */
  int storage_size;
  D_AttrNode *nodes;
  int n_nodes;
  D_AttrNode **child_ptrs;
  D_AttrNode *root;
  /* the requests being evaluated, for reporting cycles */
  D_AttrNode **stack_nodes;
  D_Attr **stack_attrs;
  int stack_n, stack_max;
  int cycles;
  D_AttrCycleFn cycle_fn;
};

static int count_nodes(D_ParseNode *pn, int *n_children) {
  int i, n = 1, nc = d_get_number_of_children(pn);
  *n_children += nc;
  for (i = 0; i < nc; i++) n += count_nodes(d_get_child(pn, i), n_children);
  return n;
}

static D_AttrNode *build(D_AttrTree *t, D_ParseNode *pn, D_AttrNode *parent, int index, int *next_node,
                         int *next_child, char *storage, unsigned char *states, void **values) {
  D_AttrNode *n = &t->nodes[(*next_node)++];
  int i, k = (int)(n - t->nodes);
  n->parent = parent;
  n->index = index;
  n->pn = pn;
  n->state = states + (size_t)k * t->n_attrs;
  n->value = values + (size_t)k * t->n_attrs;
  n->storage = storage + (size_t)k * t->storage_size;
  n->n_children = d_get_number_of_children(pn);
  n->children = t->child_ptrs + *next_child;
  *next_child += n->n_children;
  for (i = 0; i < n->n_children; i++)
    n->children[i] = build(t, d_get_child(pn, i), n, i, next_node, next_child, storage, states, values);
  return n;
}

static void report_cycle(D_AttrTree *t, int n, D_AttrNode **nodes, D_Attr **attrs) {
  int i;
  fprintf(stderr, "attribute cycle:");
  for (i = 0; i < n; i++)
    fprintf(stderr, "%s %s at %s line %d", i ? " ->" : "", attrs[i]->name, d_attr_symbol_name(t, nodes[i]),
            nodes[i]->pn->start_loc.line);
  fprintf(stderr, "\n");
}

D_AttrTree *d_attr_tree(D_Parser *p, D_ParseNode *root, D_Attr **attrs, int n_attrs, void *ctx) {
  D_AttrTree *t;
  int i, n_children = 0, next_node = 0, next_child = 0;
  char *storage;
  unsigned char *states;
  void **values;
  if (!root || root == NO_DPN) return NULL;
  t = MALLOC(sizeof(*t));
  memset(t, 0, sizeof(*t));
  t->parser = p;
  t->ctx = ctx;
  t->n_attrs = n_attrs;
  t->attrs = MALLOC(sizeof(D_Attr *) * (n_attrs ? n_attrs : 1));
  t->offset = MALLOC(sizeof(int) * (n_attrs ? n_attrs : 1));
  for (i = 0; i < n_attrs; i++) {
    t->attrs[i] = attrs[i];
    t->offset[i] = t->storage_size;
    t->storage_size += (attrs[i]->size + 15) & ~15; /* keep values aligned */
  }
  t->cycle_fn = report_cycle;
  t->n_nodes = count_nodes(root, &n_children);
  t->nodes = MALLOC(sizeof(D_AttrNode) * t->n_nodes);
  t->child_ptrs = MALLOC(sizeof(D_AttrNode *) * (n_children ? n_children : 1));
  storage = MALLOC((size_t)t->storage_size * t->n_nodes + 1);
  states = MALLOC((size_t)t->n_attrs * t->n_nodes + 1);
  values = MALLOC(sizeof(void *) * ((size_t)t->n_attrs * t->n_nodes + 1));
  memset(storage, 0, (size_t)t->storage_size * t->n_nodes + 1);
  memset(states, SLOT_UNEVALUATED, (size_t)t->n_attrs * t->n_nodes + 1);
  memset(values, 0, sizeof(void *) * ((size_t)t->n_attrs * t->n_nodes + 1));
  t->root = build(t, root, NULL, -1, &next_node, &next_child, storage, states, values);
  return t;
}

void d_attr_tree_free(D_AttrTree *t) {
  int i, k;
  if (!t) return;
  for (k = 0; k < t->n_nodes; k++) {
    D_AttrNode *n = &t->nodes[k];
    for (i = 0; i < t->n_attrs; i++)
      if (t->attrs[i]->free && n->state[i] == SLOT_DONE && n->value[i] == n->storage + t->offset[i])
        t->attrs[i]->free(t->attrs[i], n->value[i]);
  }
  if (t->n_nodes) {
    FREE(t->nodes[0].storage);
    FREE(t->nodes[0].state);
    FREE(t->nodes[0].value);
  }
  FREE(t->nodes);
  FREE(t->child_ptrs);
  FREE(t->attrs);
  FREE(t->offset);
  FREE(t->stack_nodes);
  FREE(t->stack_attrs);
  FREE(t);
}

static int attr_index(D_AttrTree *t, D_Attr *a) {
  int i;
  for (i = 0; i < t->n_attrs; i++)
    if (t->attrs[i] == a) return i;
  return -1;
}

static void push(D_AttrTree *t, D_AttrNode *n, D_Attr *a) {
  if (t->stack_n >= t->stack_max) {
    t->stack_max = t->stack_max ? t->stack_max * 2 : 16;
    t->stack_nodes = REALLOC(t->stack_nodes, sizeof(D_AttrNode *) * t->stack_max);
    t->stack_attrs = REALLOC(t->stack_attrs, sizeof(D_Attr *) * t->stack_max);
  }
  t->stack_nodes[t->stack_n] = n;
  t->stack_attrs[t->stack_n] = a;
  t->stack_n++;
}

void *d_attr_get(D_AttrTree *t, D_AttrNode *n, D_Attr *a) {
  int i = attr_index(t, a);
  void *own;
  if (i < 0 || !n) {
    if (i < 0) fprintf(stderr, "d_attr_get: attribute %s is not in this tree\n", a ? a->name : "(null)");
    return NULL;
  }
  switch (n->state[i]) {
    case SLOT_DONE:
      return n->value[i];
    case SLOT_UNDEFINED:
      return NULL;
    case SLOT_IN_PROGRESS: {
      int j = t->stack_n - 1;
      while (j > 0 && !(t->stack_nodes[j] == n && t->stack_attrs[j] == a)) j--;
      push(t, n, a);
      t->cycles++;
      if (t->cycle_fn) t->cycle_fn(t, t->stack_n - j, t->stack_nodes + j, t->stack_attrs + j);
      t->stack_n--;
      return NULL;
    }
  }
  n->state[i] = SLOT_IN_PROGRESS;
  push(t, n, a);
  own = n->storage + t->offset[i];
  memset(own, 0, a->size);
  if (a->kind == D_ATTR_SYN || !n->parent)
    n->value[i] = a->eval(t, a, n, -1, own) ? own : NULL;
  else if (a->eval(t, a, n->parent, n->index, own))
    n->value[i] = own;
  else /* copy-down: the parent's value, defined by some ancestor */
    n->value[i] = d_attr_get(t, n->parent, a);
  t->stack_n--;
  n->state[i] = n->value[i] ? SLOT_DONE : SLOT_UNDEFINED;
  return n->value[i];
}

void *d_attr_ctx(D_AttrTree *t) { return t->ctx; }
D_Parser *d_attr_parser(D_AttrTree *t) { return t->parser; }
int d_attr_cycles(D_AttrTree *t) { return t->cycles; }
void d_attr_set_cycle_fn(D_AttrTree *t, D_AttrCycleFn fn) { t->cycle_fn = fn; }

D_AttrNode *d_attr_root(D_AttrTree *t) { return t->root; }
D_AttrNode *d_attr_parent(D_AttrNode *n) { return n->parent; }
int d_attr_index(D_AttrNode *n) { return n->index; }
int d_attr_n_children(D_AttrNode *n) { return n->n_children; }
D_AttrNode *d_attr_child(D_AttrNode *n, int i) { return i >= 0 && i < n->n_children ? n->children[i] : NULL; }
D_ParseNode *d_attr_parse_node(D_AttrNode *n) { return n->pn; }
int d_attr_symbol(D_AttrNode *n) { return n->pn->symbol; }
int d_attr_production(D_AttrNode *n) { return d_get_production(n->pn); }

const char *d_attr_symbol_name(D_AttrTree *t, D_AttrNode *n) {
  Parser *p = (Parser *)t->parser;
  if (!p || n->pn->symbol < 0 || (uint)n->pn->symbol >= p->t->nsymbols) return "?";
  return p->t->symbols[n->pn->symbol].name;
}
