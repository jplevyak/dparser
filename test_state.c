/*
  Threaded state (${state}): path-specific values that speculative actions
  read and replace, compared by the parser to keep paths apart.  Each test
  runs with interned states (D_StateFns) and, where it makes sense, with
  plain pointer states (state_fns NULL).
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "dparse.h"

extern D_ParserTables parser_tables_state;
extern D_ParserTables parser_tables_state_ws;

/* States are ints.  With interning they are malloc'd and owned by the
   parser; without it they point into a static table. */
static int interning, live_states;
static int static_states[64];
char st_trace[256];

void *st_make(int v) {
  if (!interning) {
    static_states[v] = v;
    return &static_states[v];
  }
  int *s = malloc(sizeof(int));
  *s = v;
  live_states++;
  return s;
}

int st_val(void *s) { return s ? *(int *)s : 0; }

static unsigned st_hash(void *s) { return (unsigned)*(int *)s * 2654435761u; }
static int st_equal(void *a, void *b) { return *(int *)a == *(int *)b; }
static void st_free(void *s) {
  live_states--;
  free(s);
}
static int st_prefer_larger(void *a, void *b) { return st_val(a) - st_val(b); }

static D_StateFns fns = {st_hash, st_equal, st_free, NULL};
static D_StateFns fns_prefer = {st_hash, st_equal, st_free, st_prefer_larger};

static int ambiguities;
static D_ParseNode *count_ambiguity(D_Parser *p, int n, D_ParseNode **v) {
  (void)p;
  ambiguities += n;
  return v[0];
}

static void quiet(D_Parser *p) { (void)p; }

static int start_state(D_ParserTables *t, const char *name) {
  for (unsigned i = 0; i < t->nsymbols; i++)
    if (t->symbols[i].kind == D_SYMBOL_NTERM && !strcmp(t->symbols[i].name, name)) return t->symbols[i].start_symbol;
  fprintf(stderr, "no start symbol %s\n", name);
  exit(1);
}

/* Skips blanks, and '#' comments when the state is 1. */
static void ws_by_state(D_Parser *p, d_loc_t *loc, void **globals) {
  (void)globals;
  int comments = st_val(d_get_whitespace_state(p)) == 1;
  char *s = loc->s;
  for (;;) {
    if (*s == '\n') {
      loc->line++;
      s++;
    } else if (*s == ' ' || *s == '\t')
      s++;
    else if (*s == '#' && comments)
      while (*s && *s != '\n') s++;
    else
      break;
  }
  loc->s = s;
}

typedef struct {
  D_ParserTables *tables;
  const char *start;
  D_StateFns *fns;
  D_WhiteSpaceFn ws;
} Setup;

/* Parse; return 1 on success.  Records the final actions' trace and the
   number of ambiguity candidates seen. */
static int parse(Setup *s, const char *text) {
  interning = s->fns != NULL;
  st_trace[0] = 0;
  ambiguities = 0;
  D_Parser *p = new_D_Parser(s->tables, 0);
  p->syntax_error_fn = quiet;
  p->ambiguity_fn = count_ambiguity;
  p->state_fns = s->fns;
  p->save_parse_tree = 1;
  if (s->start) p->start_state = start_state(s->tables, s->start);
  if (s->ws) p->initial_white_space_fn = s->ws;
  D_ParseNode *pn = dparse(p, (char *)text, (int)strlen(text));
  int ok = pn && !p->syntax_errors;
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return ok;
}

static int failed;

static void expect(const char *name, int cond) {
  printf("%-44s %s\n", name, cond ? "ok" : "FAILED");
  if (!cond) failed++;
}

static void loop_tests(D_StateFns *f, const char *mode) {
  Setup s = {&parser_tables_state, "loop_program", f, NULL};
  char name[64];
#define T(text, want)                                         \
  snprintf(name, sizeof(name), "%s: %s", mode, text);         \
  expect(name, parse(&s, text) == (want))
  T("while (x) break;", 1);
  T("break;", 0);
  T("while (x) { x; break; }", 1);
  T("while (x) x; break;", 0);
  T("while (x) while (x) { break; } break;", 0);
  T("while (x) { while (x) break; break; }", 1);
#undef T
}

static void mode_tests(D_StateFns *f, const char *mode) {
  Setup s = {&parser_tables_state, "mode_s", f, NULL};
  char name[64];
  snprintf(name, sizeof(name), "%s: mode a p keeps x", mode);
  expect(name, parse(&s, "a p") && !strcmp(st_trace, "x") && !ambiguities);
  snprintf(name, sizeof(name), "%s: mode a q keeps y", mode);
  expect(name, parse(&s, "a q") && !strcmp(st_trace, "y") && !ambiguities);
  s.start = "alt_s";
  snprintf(name, sizeof(name), "%s: alternatives a p keeps x", mode);
  expect(name, parse(&s, "a p") && !strcmp(st_trace, "x") && !ambiguities);
  snprintf(name, sizeof(name), "%s: alternatives a q keeps y", mode);
  expect(name, parse(&s, "a q") && !strcmp(st_trace, "y") && !ambiguities);
}

int main(void) {
  loop_tests(&fns, "interned");
  loop_tests(NULL, "pointers");
  mode_tests(&fns, "interned");
  mode_tests(NULL, "pointers");

  Setup top = {&parser_tables_state, "top_s", &fns, NULL};
  expect("different final states: ambiguity_fn", parse(&top, "b") && ambiguities == 2);
  top.fns = &fns_prefer;
  expect("different final states: prefer picks y", parse(&top, "b") && !strcmp(st_trace, "y") && !ambiguities);
  Setup same = {&parser_tables_state, "same_s", &fns_prefer, NULL};
  expect("same final state: ambiguity_fn", parse(&same, "c") && ambiguities == 2);

  Setup child = {&parser_tables_state, "child_s", &fns, NULL};
  expect("${state N} and final ${state}", parse(&child, "d e") && !strcmp(st_trace, "ok"));

  Setup ws = {&parser_tables_state, "ws_s", &fns, ws_by_state};
  expect("whitespace fn: comment after hash", parse(&ws, "w hash # comment\n w"));
  expect("whitespace fn: comment before hash", !parse(&ws, "w # comment\n hash w"));

  Setup wsp = {&parser_tables_state_ws, NULL, &fns, NULL};
  expect("whitespace productions: comment after hash", parse(&wsp, "w hash # comment\n w"));
  expect("whitespace productions: comment before hash", !parse(&wsp, "w # comment\n hash w"));

  expect("interned states are all freed", live_states == 0);

  if (failed) {
    printf("%d threaded state tests FAILED\n", failed);
    return 1;
  }
  printf("all threaded state tests passed\n");
  return 0;
}
