/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#include "d.h"

#define INITIAL_ALLITEMS 3359

#define item_hash(_i) \
  (((uint)(_i)->rule->index << 8) + ((uint)((_i)->kind != ELEM_END ? (_i)->index : (_i)->rule->elems.n)))

static int insert_item(State *s, Elem *e) {
  Item *i = e;
  if (set_add(&s->items_hash, i)) {
    vec_add(&s->items, i);
    return 1;
  }
  return 0;
}

static int itemcmp(const void *ai, const void *aj) {
  uint i = item_hash(*(Item **)ai);
  uint j = item_hash(*(Item **)aj);
  return (i > j) ? 1 : ((i < j) ? -1 : 0);
}

static State *new_state(void) {
  State *s = MALLOC(sizeof(State));
  memset(s, 0, sizeof(State));
  return s;
}

static void free_state(State *s) {
  vec_free(&s->items);
  vec_free(&s->items_hash);
  FREE(s);
}

static uint32 state_hash_fn(State *s, hash_fns_t *fns) { return s->hash; }
static int state_cmp_fn(State *a, State *b, hash_fns_t *fns) {
  uint j;
  if (a->items.n != b->items.n) return 1;
  for (j = 0; j < a->items.n; j++)
    if (a->items.v[j] != b->items.v[j]) return 1;
  return 0;
}
static hash_fns_t state_hash_fns = {(hash_fn_t)state_hash_fn, (cmp_fn_t)state_cmp_fn, {0, 0}};

static State *maybe_add_state(Grammar *g, void *states_hash, State *s) {
  State *ss = set_add_fn(states_hash, s, &state_hash_fns);
  if (ss != s) {
    free_state(s);
    return ss;
  }
  s->index = g->states.n;
  vec_add(&g->states, s);
  return s;
}

static Elem *next_elem(Item *i) {
  if (i->index + 1 >= i->rule->elems.n)
    return i->rule->end;
  else
    return i->rule->elems.v[i->index + 1];
}

static State *build_closure(Grammar *g, void *states_hash, State *s) {
  uint j, k;

  for (j = 0; j < s->items.n; j++) {
    Item *i = s->items.v[j];
    Elem *e = i;
    if (e->kind == ELEM_NTERM) {
      Production *pp = e->e.nterm;
      for (k = 0; k < e->e.nterm->rules.n; k++)
        insert_item(s, pp->rules.v[k]->elems.v ? pp->rules.v[k]->elems.v[0] : pp->rules.v[k]->end);
    }
  }
  if (s->items.v != NULL) qsort(s->items.v, s->items.n, sizeof(Item *), itemcmp);
  s->hash = 0;
  for (j = 0; j < s->items.n; j++) s->hash += item_hash(s->items.v[j]);
  return maybe_add_state(g, states_hash, s);
}

static Elem *clone_elem(Elem *e) {
  Elem *ee = MALLOC(sizeof(*ee));
  memcpy(ee, e, sizeof(*ee));
  return ee;
}

static void add_goto(State *s, State *ss, Elem *e) {
  Goto *g = MALLOC(sizeof(Goto));
  g->state = ss;
  g->elem = clone_elem(e);
  vec_add(&s->gotos, g);
}

static void build_state_for(Grammar *g, void *states_hash, State *s, Elem *e) {
  uint j;
  Item *i;
  State *ss = NULL;

  for (j = 0; j < s->items.n; j++) {
    i = s->items.v[j];
    if (i->kind != ELEM_END && i->kind == e->kind && i->e.term_or_nterm == e->e.term_or_nterm) {
      if (!ss) ss = new_state();
      insert_item(ss, next_elem(i));
    }
  }
  if (ss) add_goto(s, build_closure(g, states_hash, ss), e);
}

static void build_new_states(Grammar *g, void *states_hash) {
  uint i, j, k;
  State *s;
  Elem *next;

  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    for (j = 0; j < s->items.n; j++) {
      if (s->items.v[j]->kind != ELEM_END) {
        next = s->items.v[j];
        for (k = 0; k < j; k++) {
          Item *prev = s->items.v[k];
          if (prev->kind != ELEM_END && prev->kind == next->kind && prev->e.term_or_nterm == next->e.term_or_nterm)
            break;
        }
        if (k == j) {
          build_state_for(g, states_hash, s, next);
        }
      }
    }
  }
}

static void build_states_for_each_production(Grammar *g, void *states_hash) {
  uint i;
  for (i = 0; i < g->productions.n; i++)
    if (!g->productions.v[i]->internal && g->productions.v[i]->elem) {
      State *s = new_state();
      insert_item(s, g->productions.v[i]->elem);
      g->productions.v[i]->state = build_closure(g, states_hash, s);
    }
}

uint elem_symbol(Grammar *g, Elem *e) {
  if (e->kind == ELEM_NTERM)
    return e->e.nterm->index;
  else
    return g->productions.n + e->e.term->index;
}

static int gotocmp(const void *aa, const void *bb) {
  Goto *a = *(Goto **)aa, *b = *(Goto **)bb;
  int i = a->state->index, j = b->state->index;
  return ((i > j) ? 1 : ((i < j) ? -1 : 0));
}

static void sort_Gotos(Grammar *g) {
  uint i;

  for (i = 0; i < g->states.n; i++) {
    VecGoto *vg = &g->states.v[i]->gotos;
    if (vg->v != NULL) qsort(vg->v, vg->n, sizeof(Goto *), gotocmp);
  }
}

static void build_LR_sets(Grammar *g) {
  struct {
    uint n;
    uint i;
    State **v;
    State *e[INTEGRAL_VEC_SIZE];
  } states_hash;
  memset(&states_hash, 0, sizeof(states_hash));

  State *s = new_state();
  insert_item(s, g->productions.v[0]->rules.v[0]->elems.v[0]);
  build_closure(g, &states_hash, s);
  build_states_for_each_production(g, &states_hash);
  build_new_states(g, &states_hash);
  sort_Gotos(g);

  if (states_hash.v && states_hash.v != states_hash.e) FREE(states_hash.v);
}

static Action *new_Action(Grammar *g, int akind, Term *aterm, Rule *arule, State *astate) {
  Action *a = MALLOC(sizeof(Action));
  memset(a, 0, sizeof(Action));
  a->kind = akind;
  a->term = aterm;
  a->rule = arule;
  a->state = astate;
  a->index = g->action_count++;
  vec_add(&g->actions, a);
  return a;
}

void free_Action(Action *a) {
  if (a->temp_string) FREE(a->temp_string);
  FREE(a);
}

static void add_action(Grammar *g, State *s, uint akind, Term *aterm, Rule *arule, State *astate) {
  uint i;
  Action *a;

  if (akind == ACTION_REDUCE) {
    /* eliminate duplicates */
    for (i = 0; i < s->reduce_actions.n; i++)
      if (s->reduce_actions.v[i]->rule == arule) return;
    a = new_Action(g, akind, aterm, arule, astate);
    vec_add(&s->reduce_actions, a);
  } else {
    /* eliminate duplicates */
    for (i = 0; i < s->shift_actions.n; i++)
      if (s->shift_actions.v[i]->term == aterm && s->shift_actions.v[i]->state == astate &&
          s->shift_actions.v[i]->kind == akind)
        return;
    a = new_Action(g, akind, aterm, arule, astate);
    vec_add(&s->shift_actions, a);
  }
}

static void init_LR(Grammar *g) { g->action_count = 0; }

static int actioncmp(const void *aa, const void *bb) {
  Action *a = *(Action **)aa, *b = *(Action **)bb;
  uint i, j;
  if (a->kind == ACTION_SHIFT_TRAILING)
    i = a->term->index + 11000000;
  else if (a->kind == ACTION_SHIFT)
    i = a->term->index + 1000000;
  else
    i = a->rule->index;
  if (b->kind == ACTION_SHIFT_TRAILING)
    j = b->term->index + 11000000;
  else if (b->kind == ACTION_SHIFT)
    j = b->term->index + 1000000;
  else
    j = b->rule->index;
  return ((i > j) ? 1 : ((i < j) ? -1 : 0));
}

void sort_VecAction(VecAction *v) { if (v->v != NULL) qsort(v->v, v->n, sizeof(Action *), actioncmp); }

static void build_actions(Grammar *g) {
  uint x, y, z;
  State *s;
  Elem *e;

  for (x = 0; x < g->states.n; x++) {
    s = g->states.v[x];
    for (y = 0; y < s->items.n; y++) {
      e = s->items.v[y];
      if (e->kind != ELEM_END) {
        if (e->kind == ELEM_TERM) {
          for (z = 0; z < s->gotos.n; z++) {
            if (s->gotos.v[z]->elem->e.term == e->e.term)
              add_action(g, s, ACTION_SHIFT, e->e.term, 0, s->gotos.v[z]->state);
          }
        }
      } else if (e->rule->prod->index)
        add_action(g, s, ACTION_REDUCE, NULL, e->rule, 0);
      else
        s->accept = 1;
    }
    sort_VecAction(&s->shift_actions);
    sort_VecAction(&s->reduce_actions);
  }
}

State *goto_State(State *s, Elem *e) {
  uint i;
  for (i = 0; i < s->gotos.n; i++)
    if (s->gotos.v[i]->elem->e.term_or_nterm == e->e.term_or_nterm) return s->gotos.v[i]->state;
  return NULL;
}

static Hint *new_Hint(uint d, State *s, Rule *r) {
  Hint *h = MALLOC(sizeof(*h));
  h->depth = d;
  h->state = s;
  h->rule = r;
  return h;
}

static int hintcmp(const void *ai, const void *aj) {
  Hint *i = *(Hint **)ai;
  Hint *j = *(Hint **)aj;
  return (i->depth > j->depth)
             ? 1
             : ((i->depth < j->depth)
                    ? -1
                    : ((i->rule->index > j->rule->index) ? 1 : ((i->rule->index < j->rule->index) ? -1 : 0)));
}

static void build_right_epsilon_hints(Grammar *g) {
  uint x, y, z;
  State *s, *ss;
  Elem *e;
  Rule *r;

  for (x = 0; x < g->states.n; x++) {
    s = g->states.v[x];
    for (y = 0; y < s->items.n; y++) {
      e = s->items.v[y];
      r = e->rule;
      if (e->kind != ELEM_END) {
        for (z = e->index; z < r->elems.n; z++) {
          if ((r->elems.v[z]->kind != ELEM_NTERM || !r->elems.v[z]->e.nterm->nullable)) goto Lnext;
        }
        ss = s;
        for (z = e->index; z < r->elems.n; z++) ss = goto_State(ss, r->elems.v[z]);
        if (ss && r->elems.n)
          vec_add(&s->right_epsilon_hints, new_Hint(r->elems.n - e->index - 1, ss, r));
        else /* ignore for states_for_each_productions */
          ;
      }
    Lnext:;
    }
    if (s->right_epsilon_hints.n > 1 && s->right_epsilon_hints.v != NULL)
      qsort(s->right_epsilon_hints.v, s->right_epsilon_hints.n, sizeof(Hint *), hintcmp);
  }
}

static void build_error_recovery(Grammar *g) {
  uint i, j, k, depth;
  State *s;
  Rule *r, *rr;
  Elem *e, *ee;

  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    for (j = 0; j < s->items.n; j++) {
      r = s->items.v[j]->rule;
      if (r->elems.n > 1 && r->elems.v[r->elems.n - 1]->kind == ELEM_TERM &&
          r->elems.v[r->elems.n - 1]->e.term->kind == TERM_STRING) {
        depth = s->items.v[j]->index;
        e = r->elems.v[r->elems.n - 1];
        for (k = 0; k < s->error_recovery_hints.n; k++) {
          rr = s->error_recovery_hints.v[k]->rule;
          ee = rr->elems.v[rr->elems.n - 1];
          if (e->e.term->string_len == ee->e.term->string_len && !strcmp(e->e.term->string, ee->e.term->string)) {
            if (s->error_recovery_hints.v[k]->depth > depth) s->error_recovery_hints.v[k]->depth = depth;
            goto Ldone;
          }
        }
        vec_add(&s->error_recovery_hints, new_Hint(depth, NULL, r));
      Ldone:;
      }
    }
    if (s->error_recovery_hints.v != NULL) qsort(s->error_recovery_hints.v, s->error_recovery_hints.n, sizeof(Hint *), hintcmp);
  }
}

void build_LR_tables(Grammar *g) {
  init_LR(g);
  build_LR_sets(g);
  build_actions(g);
  build_right_epsilon_hints(g);
  build_error_recovery(g);
}
