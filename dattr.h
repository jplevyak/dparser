/*
  Attributes after parsing: synthesized and inherited attributes over a saved
  parse tree, evaluated on demand, cached, and checked for cycles.
*/
#ifndef _dattr_H_
#define _dattr_H_

#include "dparse.h"

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct D_AttrNode D_AttrNode;
typedef struct D_AttrTree D_AttrTree;

typedef enum { D_ATTR_SYN, D_ATTR_INH } D_AttrKind;

/* An attribute.
   D_ATTR_SYN: eval computes the value of node (child_index is -1).
   D_ATTR_INH: eval computes the value that node gives to its child number
     child_index; for the root, eval is also called with the root and
     child_index -1 for the root's own value.
   eval writes the value to out (size bytes, zeroed) and returns nonzero, or
   returns zero if it has no equation for this case.  Then a synthesized
   attribute is undefined (d_attr_get returns NULL), and an inherited one is
   copied down: the value comes from the next ancestor with an equation. */
typedef struct D_Attr D_Attr;
struct D_Attr {
  const char *name;
  D_AttrKind kind;
  int (*eval)(D_AttrTree *t, D_Attr *a, D_AttrNode *node, int child_index, void *out);
  int size;                              /* bytes of value storage (aligned to 16) */
  void (*free)(D_Attr *a, void *value);  /* optional: called with the storage of each value computed */
  void *data;                            /* yours */
};

/* Reports a cycle; chain[0..n-1] is the chain of (node, attribute) requests,
   from the first request on the cycle to the request that closed it. */
typedef void (*D_AttrCycleFn)(D_AttrTree *t, int n, D_AttrNode **nodes, D_Attr **attrs);

/* An attribute tree for the saved parse tree under root, as seen through
   d_get_child.  A parse node reached from several parents gets a separate
   D_AttrNode for each.  Returns NULL if there is no saved tree. */
D_AttrTree *d_attr_tree(D_Parser *p, D_ParseNode *root, D_Attr **attrs, int n_attrs, void *ctx);
void d_attr_tree_free(D_AttrTree *t);

/* The value of attribute a at n, evaluating it if needed, or NULL if it is
   undefined or depends on itself (a cycle, which is reported). */
void *d_attr_get(D_AttrTree *t, D_AttrNode *n, D_Attr *a);

void *d_attr_ctx(D_AttrTree *t);
D_Parser *d_attr_parser(D_AttrTree *t);
int d_attr_cycles(D_AttrTree *t); /* the number of cycles found so far */
void d_attr_set_cycle_fn(D_AttrTree *t, D_AttrCycleFn fn); /* default: report on stderr */

D_AttrNode *d_attr_root(D_AttrTree *t);
D_AttrNode *d_attr_parent(D_AttrNode *n);
int d_attr_index(D_AttrNode *n); /* index within the parent; -1 for the root */
int d_attr_n_children(D_AttrNode *n);
D_AttrNode *d_attr_child(D_AttrNode *n, int i);
D_ParseNode *d_attr_parse_node(D_AttrNode *n);
int d_attr_symbol(D_AttrNode *n);
const char *d_attr_symbol_name(D_AttrTree *t, D_AttrNode *n);
int d_attr_production(D_AttrNode *n); /* d_get_production of the parse node */

#if defined(__cplusplus)
}
#endif

#endif
