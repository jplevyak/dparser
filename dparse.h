/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/
#ifndef _dparse_H_
#define _dparse_H_

#if defined(__cplusplus)
extern "C" {
#endif

#include "dparse_tables.h"
#include "dsymtab.h"

struct D_Parser;
struct D_ParserTables;
struct D_Scope;
struct D_ParseNode;
struct D_Parser_User;  // Optional user data.

typedef void *d_voidp;
#ifndef D_ParseNode_User
#define D_ParseNode_User d_voidp
#endif
#ifndef D_ParseNode_Globals
#define D_ParseNode_Globals void
#endif

#define NO_DPN ((D_ParseNode *)0x1)

typedef void (*D_SyntaxErrorFn)(struct D_Parser *);
typedef struct D_ParseNode *(*D_AmbiguityFn)(struct D_Parser *, int n, struct D_ParseNode **v);
typedef void (*D_FreeNodeFn)(struct D_ParseNode *d);

/* Threaded state: an immutable value per parse path, flowing left to right.
   Values are interned (equal values share one pointer) and owned by the
   parser, which frees them in free_D_Parser.  With D_Parser.state_fns NULL,
   values are compared by pointer and are neither interned nor freed. */
typedef struct D_StateFns {
  unsigned (*hash)(void *state);
  int (*equal)(void *a, void *b);  /* nonzero if equal */
  void (*free)(void *state);       /* optional */
  int (*prefer)(void *a, void *b); /* optional: >0 prefer a, <0 prefer b, 0 neither */
} D_StateFns;

typedef struct D_Parser {
  D_ParseNode_Globals *initial_globals; /* global values */
  D_WhiteSpaceFn initial_white_space_fn;
  struct D_Scope *initial_scope;
  D_SyntaxErrorFn syntax_error_fn;
  D_AmbiguityFn ambiguity_fn;
  D_FreeNodeFn free_node_fn;
  d_loc_t loc;     /* initial location, set on error */
  int start_state; /* do not move or change without fixing copy_user_configurables() */
  /* user configurables */
  int sizeof_user_parse_node;
  int save_parse_tree;
  int dont_compare_stacks;
  int dont_fixup_internal_productions;
  int fixup_EBNF_productions;
  int dont_merge_epsilon_trees;
  int dont_use_height_for_disambiguation;
  int dont_use_greediness_for_disambiguation;
  int dont_use_deep_priorities_for_disambiguation;
  int commit_actions_interval; /* 0 is immediate */
  int error_recovery;
  int partial_parses;
  /* parse results */
  int syntax_errors; /* do not move or change without fixing copy_user_configurables() */
  /* threaded state (not copied to subparsers) */
  D_StateFns *state_fns;
  void *initial_state;
} D_Parser;

typedef struct D_ParseNode {
  int symbol;
  d_loc_t start_loc;
  char *end;
  char *end_skip;
  struct D_Scope *scope;
  D_ParseNode_User user;
} D_ParseNode;

D_Parser *new_D_Parser(struct D_ParserTables *t, int sizeof_ParseNode_User);
void free_D_Parser(D_Parser *p);
D_ParseNode *dparse(D_Parser *p, char *buf, int buf_len);
void free_D_ParseNode(D_Parser *p, D_ParseNode *pn);
void free_D_ParseTreeBelow(D_Parser *p, D_ParseNode *pn);

int d_get_number_of_children(D_ParseNode *pn);
D_ParseNode *d_get_child(D_ParseNode *pn, int child);
D_ParseNode *d_find_in_tree(D_ParseNode *pn, int symbol);
char *d_ws_before(D_Parser *p, D_ParseNode *pn); /* points BEFORE leading ws */
char *d_ws_after(D_Parser *p, D_ParseNode *pn);  /* points AFTER trailing ws */

void d_pass(D_Parser *p, D_ParseNode *pn, int pass_number);

void *d_intern_state(D_Parser *p, void *state); /* the canonical pointer; the parser owns it */
void *d_get_state(D_ParseNode *pn);             /* the state after pn */
void *d_get_state_before(D_ParseNode *pn);      /* the state before pn */
void *d_get_whitespace_state(D_Parser *p);      /* the state, in a whitespace function */
void **d_state_slot(D_ParseNode *pn);           /* used by generated code for ${state} */

int resolve_amb_greedy(D_Parser *dp, int n, D_ParseNode **v);

char *d_dup_pathname_str(const char *str);

#if defined(__cplusplus)
}
#endif

#endif
