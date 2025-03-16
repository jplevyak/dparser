%module dparser_swigc
%{
#include "pydparser.h"
%}

%include "pydparser.h"

typedef struct d_loc_t {
  void *s: /* converting to a string would be too expensive */
  char *pathname, *ws;
  int col, line;
} d_loc_t;

typedef struct D_ParseNode {
  int			symbol;
  d_loc_t		start_loc;
  user_pyobjects	user;
} D_ParseNode;

D_ParseNode *d_get_child(D_ParseNode *pn, int child);
D_ParseNode *d_find_in_tree(D_ParseNode *pn, int symbol);
int d_get_number_of_children(D_ParseNode *pn);

