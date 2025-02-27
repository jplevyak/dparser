/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#include "gramgram.h"  // must appear before dparser.h
#include "d.h"

extern D_ParserTables parser_tables_dparser_gram;

static char *action_types[] = {"ACCEPT", "SHIFT", "REDUCE"};

static void print_state(State *s);

Production *new_production(Grammar *g, char *name) {
  Production *p;
  if ((p = lookup_production(g, name, strlen(name)))) {
    FREE(name);
    return p;
  }
  p = MALLOC(sizeof(Production));
  memset(p, 0, sizeof(Production));
  vec_add(&g->productions, p);
  p->name = name;
  p->name_len = strlen(name);
  return p;
}

static Elem *new_elem(void) {
  Elem *e = MALLOC(sizeof(Elem));
  memset(e, 0, sizeof(Elem));
  return e;
}

Rule *new_rule(Grammar *g, Production *p) {
  Rule *r = MALLOC(sizeof(Rule));
  memset(r, 0, sizeof(Rule));
  r->prod = p;
  r->end = new_elem();
  r->end->kind = ELEM_END;
  r->end->rule = r;
  r->action_index = g->action_index;
  return r;
}

static Term *new_term(void) {
  Term *term = MALLOC(sizeof(Term));
  memset(term, 0, sizeof(Term));
  return term;
}

static Elem *new_elem_term(Term *t, Rule *r) {
  Elem *e = new_elem();
  e->kind = ELEM_TERM;
  e->e.term = t;
  e->rule = r;
  vec_add(&r->elems, e);
  return e;
}

Elem *new_elem_nterm(Production *p, Rule *r) {
  Elem *e = new_elem();
  e->kind = ELEM_NTERM;
  e->e.nterm = p;
  e->rule = r;
  return e;
}

static Elem *new_term_string(Grammar *g, char *s, char *e, Rule *r) {
  Term *t = new_term();
  Elem *elem;

  t->string = MALLOC(e - s + 1);
  memcpy(t->string, s, e - s);
  t->string[e - s] = 0;
  t->string_len = e - s;
  vec_add(&g->terminals, t);
  elem = new_elem_term(t, r);
  return elem;
}

char *escape_string_for_regex(const char *s) {
  char *ss = (char *)MALLOC((strlen(s) + 1) * 2), *sss = ss;
  for (; *s; s++) {
    switch (*s) {
      case '(':
      case ')':
      case '[':
      case ']':
      case '-':
      case '^':
      case '*':
      case '?':
      case '+':
      case '\\':
        *ss++ = '\\';
        /* fall through */
      default:
        *ss++ = *s;
        break;
    }
  }
  *ss = 0;
  return sss;
}

static void unescape_term_string(Term *t) {
  char *s, *start = 0, *ss;
  int length, base = 0;

  for (ss = s = t->string; *s; s++) {
    if (*s == '\\') {
      switch (s[1]) {
        case '\\':
          if (t->kind == TERM_STRING) {
            *ss = '\\';
            s++;
            break;
          } else
            goto Ldefault;
        case 'b':
          *ss = '\b';
          s++;
          break;
        case 'f':
          *ss = '\f';
          s++;
          break;
        case 'n':
          *ss = '\n';
          s++;
          break;
        case 'r':
          *ss = '\r';
          s++;
          break;
        case 't':
          *ss = '\t';
          s++;
          break;
        case 'v':
          *ss = '\v';
          s++;
          break;
        case 'a':
          *ss = '\a';
          s++;
          break;
        case 'c':
          *ss = 0;
          return;
        case '\"':
          if (t->kind == TERM_REGEX) {
            *ss = '\"';
            s++;
            break;
          } else
            goto Ldefault;
        case '\'':
          if (t->kind == TERM_STRING) {
            *ss = '\'';
            s++;
            break;
          } else
            goto Ldefault;
        case 'x':
          length = 0;
          if (isxdigit_(s[2])) {
            base = 16;
            start = s + 2;
            length++;
            if (isxdigit_(s[3])) length++;
          }
          s += length + 1;
          goto Lncont;
        case 'd':
          length = 0;
          if (isdigit_(s[2])) {
            base = 10;
            start = s + 2;
            length++;
            if (isdigit_(s[3])) {
              length++;
              if (isdigit_(s[4]) &&
                  ((s[2] < '2') || ((s[2] == '2') && ((s[3] < '5') || ((s[3] == '5') && (s[4] < '6'))))))
                length++;
            }
          }
          s += length + 1;
          goto Lncont;
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
          length = 1;
          base = 8;
          start = s + 1;
          if (isdigit_(s[2]) && (s[2] != '8') && (s[2] != '9')) {
            length++;
            if (isdigit_(s[3]) && (s[3] != '8') && (s[3] != '9')) {
              length++;
            }
          }
          s += length;
          /* fall through */
        Lncont:
          if (length > 0) {
            char saved_c = start[length];
            start[length] = '\0';
            *ss = (unsigned char)strtol(start, NULL, base);
            start[length] = saved_c;
            if (*s > 0) break;
            d_fail("encountered an escaped NULL while processing '%s'", t->string);
          } else
            goto next;
        Ldefault:
        default:
          *ss++ = *s;
          *ss = s[1];
          s++;
          break;
      }
    } else
      *ss = *s;
    ss++;
  next:;
  }
  *ss = 0;
  t->string_len = strlen(t->string);
  if (!t->string_len) d_fail("empty string after unescape '%s'", t->string);
}

Elem *new_string(Grammar *g, char *s, char *e, Rule *r) {
  Elem *x = new_term_string(g, s + 1, e - 1, r);
  x->e.term->kind = (*s == '"') ? TERM_REGEX : TERM_STRING;
  unescape_term_string(x->e.term);
  return x;
}

Elem *new_utf8_char(Grammar *g, char *s, char *e, Rule *r) {
  char utf8_code[4];
  unsigned long utf32_code, base, len = 0;
  Elem *x;
  for (utf32_code = 0, base = 1; e >= s + 3; base *= 16) {
    e--;
    if (*e >= '0' && *e <= '9')
      utf32_code += base * (*e - '0');
    else if (*e >= 'a' && *e <= 'f')
      utf32_code += base * (*e - 'a' + 10);
    else if (*e >= 'A' && *e <= 'F')
      utf32_code += base * (*e - 'A' + 10);
  }
  if (utf32_code < 0x80) {
    utf8_code[0] = utf32_code;
    len = 1;
  } else if (utf32_code < 0x800) {
    utf8_code[0] = 0xc0 | ((utf32_code >> 6) & 0x1f);
    utf8_code[1] = 0x80 | (utf32_code & 0x3f);
    len = 2;
  } else if (utf32_code < 0x10000) {
    utf8_code[0] = 0xe0 | ((utf32_code >> 12) & 0x0f);
    utf8_code[1] = 0x80 | ((utf32_code >> 6) & 0x3f);
    utf8_code[2] = 0x80 | (utf32_code & 0x3f);
    len = 3;
  } else if (utf32_code < 0x02000000) {
    utf8_code[0] = 0xf0 | ((utf32_code >> 18) & 0x07);
    utf8_code[1] = 0x80 | ((utf32_code >> 12) & 0x3f);
    utf8_code[2] = 0x80 | ((utf32_code >> 6) & 0x3f);
    utf8_code[3] = 0x80 | (utf32_code & 0x3f);
    len = 4;
  } else {
    d_fail("UTF32 Unicode value U+%8X too large for valid UTF-8 encoding (cf. Unicode Spec 4.0, section 3.9)",
           utf32_code);
  }
  x = new_term_string(g, utf8_code, utf8_code + len, r);
  x->e.term->kind = TERM_STRING;
  return x;
}

Elem *new_ident(char *s, char *e, Rule *r) {
  Elem *x = new_elem();
  x->kind = ELEM_UNRESOLVED;
  x->e.unresolved.string = dup_str(s, e);
  x->e.unresolved.len = strlen(x->e.unresolved.string);
  x->rule = r;
  if (r) vec_add(&r->elems, x);
  return x;
}

void new_token(Grammar *g, char *s, char *e) {
  Term *t = new_term();
  t->string = MALLOC(e - s + 1);
  memcpy(t->string, s, e - s);
  t->string[e - s] = 0;
  t->string_len = e - s;
  vec_add(&g->terminals, t);
  t->kind = TERM_TOKEN;
}

Elem *new_code(Grammar *g, char *s, char *e, Rule *r) {
  Elem *x = new_term_string(g, s, e, r);
  x->e.term->kind = TERM_CODE;
  return x;
}

Elem *dup_elem(Elem *e, Rule *r) {
  Elem *ee = MALLOC(sizeof(Elem));
  memcpy(ee, e, sizeof(Elem));
  if (ee->kind == ELEM_UNRESOLVED) ee->e.unresolved.string = dup_str(e->e.unresolved.string, 0);
  ee->rule = r;
  return ee;
}

void add_global_code(Grammar *g, char *start, char *end, int line) {
  if (!g->code)
    g->code = MALLOC(sizeof(Code) * 4);
  else if (!((g->ncode + 1) & 4))
    g->code = REALLOC(g->code, sizeof(Code) * (g->ncode + 4));
  g->code[g->ncode].code = dup_str(start, end);
  g->code[g->ncode].line = line;
  g->ncode++;
}

void new_declaration(Grammar *g, Elem *e, uint kind) {
  Declaration *d = MALLOC(sizeof(*d));
  d->elem = e;
  d->kind = kind;
  d->index = g->declarations.n;
  vec_add(&g->declarations, d);
}

void add_declaration(Grammar *g, char *start, char *end, uint kind, uint line) {
  if (start == end) {
    switch (kind) {
      case DECLARE_SET_OP_PRIORITY:
        g->set_op_priority_from_rule = 1;
        return;
      case DECLARE_STATES_FOR_ALL_NTERMS:
        g->states_for_all_nterms = 1;
        return;
      case DECLARE_LONGEST_MATCH:
        g->longest_match = 1;
        break;
      case DECLARE_ALL_MATCHES:
        g->longest_match = 0;
        break;
      case DECLARE_TOKENIZE:
        g->tokenizer = 1;
        break;
      case DECLARE_SAVE_PARSE_TREE:
        g->save_parse_tree = 1;
        return;
      default:
        d_fail("declare expects argument, line %d", line);
    }
  }
  switch (kind) {
    case DECLARE_WHITESPACE:
      g->default_white_space = dup_str(start, end);
      return;
    case DECLARE_SET_OP_PRIORITY:
      d_fail("declare does not expect argument, line %d", line);
    default:
      new_declaration(g, new_ident(start, end, NULL), kind);
      break;
  }
}

D_Pass *find_pass(Grammar *g, char *start, char *end) {
  uint i, l;
  while (*start && isspace_(*start)) start++;
  l = end - start;
  for (i = 0; i < g->passes.n; i++)
    if (l == g->passes.v[i]->name_len && !strncmp(g->passes.v[i]->name, start, l)) return g->passes.v[i];
  return NULL;
}

void add_pass(Grammar *g, char *start, char *end, uint kind, uint line) {
  if (find_pass(g, start, end))
    d_fail("duplicate pass '%s' line %d", dup_str(start, end), line);
  else {
    D_Pass *p = MALLOC(sizeof(*p));
    p->name = dup_str(start, end);
    p->name_len = end - start;
    p->kind = kind;
    p->index = g->pass_index++;
    vec_add(&g->passes, p);
  }
}

void add_pass_code(Grammar *g, Rule *r, char *pass_start, char *pass_end, char *code_start, char *code_end,
                   uint pass_line, uint code_line) {
  D_Pass *p = find_pass(g, pass_start, pass_end);
  if (!p) d_fail("unknown pass '%s' line %d", dup_str(pass_start, pass_end), pass_line);
  while (r->pass_code.n <= p->index) vec_add(&r->pass_code, NULL);
  r->pass_code.v[p->index] = MALLOC(sizeof(Code));
  r->pass_code.v[p->index]->code = dup_str(code_start, code_end);
  r->pass_code.v[p->index]->line = code_line;
}

Production *new_internal_production(Grammar *g, Production *p) {
  char *n = p ? p->name : " _synthetic";
  int maxLen = strlen(n) + 21;
  char *name = MALLOC(maxLen);
  if (name == NULL) {
    d_fail("could not allocate enough memory for a new_internal_production");
    return NULL;
  }
  maxLen--;
  Production *pp = NULL, *tp = NULL, *ttp;
  uint i, found = 0;
  snprintf(name, maxLen, "%s__%d", n, g->productions.n);
  pp = new_production(g, name);
  pp->internal = INTERNAL_HIDDEN;
  pp->regex = p ? p->regex : 0;
  if (p) {
    for (i = 0; i < g->productions.n; i++) {
      if (found) {
        ttp = g->productions.v[i];
        g->productions.v[i] = tp;
        tp = ttp;
      } else if (p == g->productions.v[i]) {
        found = 1;
        tp = g->productions.v[i + 1];
        g->productions.v[i + 1] = pp;
        i++;
      }
    }
  }
  return pp;
}

void conditional_EBNF(Grammar *g) {
  Production *pp;
  Rule *rr;

  pp = new_internal_production(g, g->p);
  pp->internal = INTERNAL_CONDITIONAL;
  rr = new_rule(g, pp);
  vec_add(&rr->elems, last_elem(g->r));
  last_elem(g->r)->rule = rr;
  rr->elems.v[rr->elems.n - 1]->rule = rr;
  vec_add(&pp->rules, rr);
  vec_add(&pp->rules, new_rule(g, pp));
  last_elem(g->r) = new_elem_nterm(pp, g->r);
}

void star_EBNF(Grammar *g) {
  Production *pp;
  Rule *rr;

  pp = new_internal_production(g, g->p);
  pp->internal = INTERNAL_STAR;
  rr = new_rule(g, pp);
  if (!g->right_recursive_BNF) {
    vec_add(&rr->elems, new_elem_nterm(pp, rr));
    vec_add(&rr->elems, last_elem(g->r));
    last_elem(g->r) = new_elem_nterm(pp, g->r);
    last_elem(rr)->rule = rr;
  } else {
    vec_add(&rr->elems, last_elem(g->r));
    last_elem(g->r) = new_elem_nterm(pp, g->r);
    last_elem(rr)->rule = rr;
    vec_add(&rr->elems, new_elem_nterm(pp, rr));
  }
  vec_add(&pp->rules, rr);
  vec_add(&pp->rules, new_rule(g, pp));
}

void plus_EBNF(Grammar *g) {
  Production *pp;
  Rule *rr;
  Elem *elem;

  pp = new_internal_production(g, g->p);
  pp->internal = INTERNAL_PLUS;
  rr = new_rule(g, pp);
  if (!g->right_recursive_BNF) {
    elem = last_elem(g->r);
    vec_add(&rr->elems, new_elem_nterm(pp, rr));
    vec_add(&rr->elems, dup_elem(elem, rr));
    last_elem(g->r) = new_elem_nterm(pp, g->r);
    if (g->r->rule_priority) {
      rr->rule_priority = g->r->rule_priority;
      rr->rule_assoc = ASSOC_NARY_LEFT;
    }
  } else {
    elem = last_elem(g->r);
    vec_add(&rr->elems, dup_elem(elem, rr));
    last_elem(g->r) = new_elem_nterm(pp, g->r);
    vec_add(&rr->elems, new_elem_nterm(pp, rr));
    if (g->r->rule_priority) {
      rr->rule_priority = g->r->rule_priority;
      rr->rule_assoc = ASSOC_NARY_RIGHT;
    }
  }
  vec_add(&pp->rules, rr);
  rr = new_rule(g, pp);
  vec_add(&rr->elems, elem);
  elem->rule = rr;
  vec_add(&pp->rules, rr);
}

void rep_EBNF(Grammar *g, int min, int max) {
  Production *pp;
  Rule *rr;
  Elem *elem;
  int i, j;
  if (max < min) max = min;

  pp = new_internal_production(g, g->p);
  elem = last_elem(g->r);
  for (i = min; i <= max; i++) {
    rr = new_rule(g, pp);
    for (j = 0; j < i; j++) vec_add(&rr->elems, dup_elem(elem, rr));
    vec_add(&pp->rules, rr);
  }
  last_elem(g->r) = new_elem_nterm(pp, g->r);
  FREE(elem);
}

void initialize_productions(Grammar *g) {
  Production *pp = new_production(g, dup_str("0 Start", 0));
  pp->internal = INTERNAL_HIDDEN;
}

void finish_productions(Grammar *g) {
  Production *pp = g->productions.v[0];
  Rule *rr = new_rule(g, pp);
  vec_add(&rr->elems, new_elem_nterm(NULL, rr));
  vec_add(&pp->rules, rr);
  rr->elems.v[0]->e.nterm = g->productions.v[1];
}

Production *lookup_production(Grammar *g, char *name, uint l) {
  uint i;

  for (i = 0; i < g->productions.n; i++) {
    Production *pp = g->productions.v[i];
    if (pp->name_len != l || strncmp(pp->name, name, l)) continue;
    return pp;
  }
  return NULL;
}

static Term *lookup_token(Grammar *g, char *name, int l) {
  uint i;

  for (i = 0; i < g->terminals.n; i++) {
    Term *t = g->terminals.v[i];
    if (t->kind != TERM_TOKEN || t->string_len != l || strncmp(t->string, name, l)) continue;
    return t;
  }
  return NULL;
}

static Term *unique_term(Grammar *g, Term *t) {
  uint i;
  for (i = 0; i < g->terminals.n; i++)
    if (t->kind == g->terminals.v[i]->kind && t->string_len == g->terminals.v[i]->string_len &&
        t->term_priority == g->terminals.v[i]->term_priority && t->term_name == g->terminals.v[i]->term_name &&
        (!g->set_op_priority_from_rule ||
         (t->op_assoc == g->terminals.v[i]->op_assoc && t->op_priority == g->terminals.v[i]->op_priority)) &&
        !strncmp(t->string, g->terminals.v[i]->string, t->string_len))
      return g->terminals.v[i];
  return t;
}

static void compute_nullable(Grammar *g) {
  uint i, j, k, changed = 1;
  Elem *e;

  /* ensure that the trivial case is the first cause */
  for (i = 0; i < g->productions.n; i++) {
    for (j = 0; j < g->productions.v[i]->rules.n; j++)
      if (!g->productions.v[i]->rules.v[j]->elems.n) {
        g->productions.v[i]->nullable = g->productions.v[i]->rules.v[j];
        break;
      }
  }
  /* transitive closure */
  while (changed) {
    changed = 0;
    for (i = 0; i < g->productions.n; i++) {
      if (!g->productions.v[i]->nullable)
        for (j = 0; j < g->productions.v[i]->rules.n; j++) {
          for (k = 0; k < g->productions.v[i]->rules.v[j]->elems.n; k++) {
            e = g->productions.v[i]->rules.v[j]->elems.v[k];
            if (e->kind != ELEM_NTERM || !e->e.nterm->nullable) goto Lnot_nullable;
          }
          changed = 1;
          g->productions.v[i]->nullable = g->productions.v[i]->rules.v[j];
          break;
        }
    Lnot_nullable:;
    }
  }
}

/*
  verify and cleanup the grammar datastructures
  - resolve non-terminals
  - set element indexes
*/
static void resolve_grammar(Grammar *g) {
  uint i, j, k, l;
  Production *p, *pp;
  Rule *r;
  Elem *e;
  Term *last_term, *t;

  g->rule_index = 0;
  for (i = 0; i < g->productions.n; i++) {
    p = g->productions.v[i];
    if (p != lookup_production(g, p->name, p->name_len)) d_fail("duplicate production '%s'", p->name);
    p->index = i;
    for (j = 0; j < p->rules.n; j++) {
      r = p->rules.v[j];
      r->index = g->rule_index++;
      last_term = NULL;
      for (k = 0; k < r->elems.n; k++) {
        e = r->elems.v[k];
        e->index = k;
        if (e->kind == ELEM_UNRESOLVED) {
          l = e->e.unresolved.len;
          if ((pp = lookup_production(g, e->e.unresolved.string, l))) {
            FREE(e->e.unresolved.string);
            e->e.unresolved.string = 0;
            e->kind = ELEM_NTERM;
            e->e.nterm = pp;
          } else if ((t = lookup_token(g, e->e.unresolved.string, l))) {
            FREE(e->e.unresolved.string);
            e->e.unresolved.string = 0;
            e->kind = ELEM_TERM;
            e->e.term = t;
          } else {
            char str[256];
            strncpy(str, e->e.unresolved.string, l);
            str[l < 255 ? l : 255] = 0;
            d_fail("unresolved identifier: '%s'", str);
          }
        }
        if (e->kind == ELEM_TERM) last_term = e->e.term;
      }
      r->end->index = r->elems.n;
      if (g->set_op_priority_from_rule) {
        if (last_term && r->rule_assoc) {
          last_term->op_assoc = r->rule_assoc;
          last_term->op_priority = r->rule_priority;
        }
      }
    }
  }
  for (i = 0; i < g->terminals.n; i++) g->terminals.v[i]->index = i;
  compute_nullable(g);
}

static void merge_identical_terminals(Grammar *g) {
  uint i, j, k;
  Production *p;
  Rule *r;
  Elem *e;

  for (i = 0; i < g->productions.n; i++) {
    p = g->productions.v[i];
    for (j = 0; j < p->rules.n; j++) {
      r = p->rules.v[j];
      for (k = 0; k < r->elems.n; k++) {
        e = r->elems.v[k];
        if (e->kind == ELEM_TERM) e->e.term = unique_term(g, e->e.term);
      }
    }
  }
}

void print_term(Term *t) {
  char *s = t->string ? escape_string(t->string) : NULL;
  if (t->term_name)
    printf("term_name(\"%s\") ", t->term_name);
  else if (t->kind == TERM_STRING) {
    if (!t->string || !*t->string)
      printf("<EOF> ");
    else
      printf("string(\"%s\") ", s);
  } else if (t->kind == TERM_REGEX) {
    printf("regex(\"%s\") ", s);
  } else if (t->kind == TERM_CODE)
    printf("code(\"%s\") ", s);
  else if (t->kind == TERM_TOKEN)
    printf("token(\"%s\") ", s);
  else
    d_fail("unknown token kind");
  if (s) FREE(s);
}

void print_elem(Elem *ee) {
  if (ee->kind == ELEM_TERM)
    print_term(ee->e.term);
  else if (ee->kind == ELEM_UNRESOLVED)
    printf("%s ", ee->e.unresolved.string);
  else
    printf("%s ", ee->e.nterm->name);
}

struct EnumStr {
  uint e;
  char *s;
} assoc_strings[] = {{ASSOC_NONE, "$none"},
                     {ASSOC_NARY_LEFT, "$left"},
                     {ASSOC_NARY_RIGHT, "$right"},
                     {ASSOC_UNARY_LEFT, "$unary_left"},
                     {ASSOC_UNARY_RIGHT, "$unary_right"},
                     {ASSOC_BINARY_LEFT, "$binary_left"},
                     {ASSOC_BINARY_RIGHT, "$binary_right"},
                     {ASSOC_NO, "$noassoc"}};

static char *assoc_str(uint e) {
  uint i;

  for (i = 0; i < sizeof(assoc_strings) / sizeof(assoc_strings[0]); i++)
    if (e == assoc_strings[i].e) return assoc_strings[i].s;
  return assoc_strings[0].s;
}

void print_rule(Rule *r) {
  uint k;

  printf("%s: ", r->prod->name);
  for (k = 0; k < r->elems.n; k++) print_elem(r->elems.v[k]);
  if (r->speculative_code.code) printf("SPECULATIVE_CODE\n%s\nEND CODE\n", r->speculative_code.code);
  if (r->final_code.code) printf("FINAL_CODE\n%s\nEND CODE\n", r->final_code.code);
}

void print_grammar(Grammar *g) {
  uint i, j, k;
  Production *pp;
  Rule *rr;

  if (!g->productions.n) return;
  printf("PRODUCTIONS\n\n");
  for (i = 0; i < g->productions.n; i++) {
    pp = g->productions.v[i];
    printf("%s (%d)\n", pp->name, i);
    for (j = 0; j < pp->rules.n; j++) {
      rr = pp->rules.v[j];
      if (!j)
        printf("\t: ");
      else
        printf("\t| ");
      for (k = 0; k < rr->elems.n; k++) print_elem(rr->elems.v[k]);
      if (rr->op_priority) printf("op %d ", rr->op_priority);
      if (rr->op_assoc) printf("%s ", assoc_str(rr->op_assoc));
      if (rr->rule_priority) printf("rule %d ", rr->rule_priority);
      if (rr->rule_assoc) printf("%s ", assoc_str(rr->rule_assoc));
      if (rr->speculative_code.code) printf("%s ", rr->speculative_code.code);
      if (rr->final_code.code) printf("%s ", rr->final_code.code);
      printf("\n");
    }
    printf("\t;\n");
    printf("\n");
  }
  printf("TERMINALS\n\n");
  for (i = 0; i < g->terminals.n; i++) {
    printf("\t");
    print_term(g->terminals.v[i]);
    printf("(%d)\n", i + g->productions.n);
  }
  printf("\n");
}

static void print_item(Item *i) {
  uint j, end = 1;

  printf("\t%s: ", i->rule->prod->name);
  for (j = 0; j < i->rule->elems.n; j++) {
    Elem *e = i->rule->elems.v[j];
    if (i == e) {
      printf(". ");
      end = 0;
    }
    print_elem(e);
  }
  if (end) printf(". ");
  printf("\n");
}

static void print_conflict(char *kind, uint *conflict) {
  if (!*conflict) {
    printf("  CONFLICT (before precedence and associativity)\n");
    *conflict = 1;
  }
  printf("\t%s conflict ", kind);
  printf("\n");
}

static void print_state(State *s) {
  uint j, conflict = 0;

  printf("STATE %d (%d ITEMS)%s\n", s->index, s->items.n, s->accept ? " ACCEPT" : "");
  for (j = 0; j < s->items.n; j++) print_item(s->items.v[j]);
  if (s->gotos.n) printf("  GOTO\n");
  for (j = 0; j < s->gotos.n; j++) {
    printf("\t");
    print_elem(s->gotos.v[j]->elem);
    printf(" : %d\n", s->gotos.v[j]->state->index);
  }
  printf("  ACTION\n");
  for (j = 0; j < s->reduce_actions.n; j++) {
    Action *a = s->reduce_actions.v[j];
    printf("\t%s\t", action_types[a->kind]);
    print_rule(a->rule);
    printf("\n");
  }
  for (j = 0; j < s->shift_actions.n; j++) {
    Action *a = s->shift_actions.v[j];
    printf("\t%s\t", action_types[a->kind]);
    if (a->kind == ACTION_SHIFT) {
      print_term(a->term);
      printf("%d", a->state->index);
    }
    printf("\n");
  }
  if (s->reduce_actions.n > 1) print_conflict("reduce/reduce", &conflict);
  if (s->reduce_actions.n && s->shift_actions.n) print_conflict("shift/reduce", &conflict);
  printf("\n");
}

void print_states(Grammar *g) {
  uint i;

  for (i = 0; i < g->states.n; i++) print_state(g->states.v[i]);
}

uint state_for_declaration(Grammar *g, uint iproduction) {
  uint i;

  for (i = 0; i < g->declarations.n; i++)
    if (g->declarations.v[i]->kind == DECLARE_STATE_FOR && g->declarations.v[i]->elem->e.nterm->index == iproduction)
      return 1;
  return 0;
}

static void make_elems_for_productions(Grammar *g) {
  uint i, j, k, l;
  Rule *rr;
  Production *pp, *ppp;

  pp = g->productions.v[0];
  for (i = 0; i < g->productions.n; i++)
    if (!g->productions.v[i]->internal) {
      if (g->states_for_all_nterms || state_for_declaration(g, i)) {
        /* try to find an existing elem */
        for (j = 0; j < g->productions.n; j++)
          for (k = 0; k < g->productions.v[j]->rules.n; k++) {
            rr = g->productions.v[j]->rules.v[k];
            for (l = 0; l < rr->elems.n; l++)
              if (rr->elems.v[l]->e.term_or_nterm == g->productions.v[i]) {
                g->productions.v[i]->elem = rr->elems.v[l];
                break;
              }
          }
        if (j >= g->productions.n) { /* not found */
          g->productions.v[i]->elem = new_elem_nterm(g->productions.v[i], new_rule(g, pp));
          g->productions.v[i]->elem->rule->index = g->rule_index++; /* fake */
        }
      }
    }
  if (!g->states_for_all_nterms && g->states_for_whitespace &&
      (ppp = lookup_production(g, "whitespace", sizeof("whitespace") - 1))) {
    ppp->elem = new_elem_nterm(ppp, new_rule(g, pp));
    ppp->elem->rule->index = g->rule_index++; /* fake */
  }
}

static void convert_regex_production_one(Grammar *g, Production *p) {
  uint j, k, l;
  Production *pp;
  Rule *r, *rr;
  Elem *e;
  Term *t;
  int circular = 0;
  char *buf = 0, *b, *s;
  int buf_len = 0;

  if (p->regex_term) /* already done */
    return;
  if (p->in_regex) d_fail("circular regex production '%s'", p->name);
  p->in_regex = 1;
  for (j = 0; j < p->rules.n; j++) {
    r = p->rules.v[j];
    if (r->final_code.code || (r->speculative_code.code && p->rules.n > 1))
      d_fail("final and/or multi-rule code not permitted in regex productions '%s'", p->name);
    for (k = 0; k < r->elems.n; k++) {
      e = r->elems.v[k];
      if (e->kind == ELEM_NTERM) {
        if (!e->e.nterm->regex)
          d_fail("regex production '%s' cannot invoke non-regex production '%s'", p->name, e->e.nterm->name);
        pp = e->e.nterm;
        for (l = 0; l < pp->rules.n; l++)
          if (pp->rules.v[l]->speculative_code.code || pp->rules.v[l]->final_code.code)
            d_fail("code not permitted in rule %d of regex productions '%s'", l, p->name);
        if (p != pp) {
          convert_regex_production_one(g, pp);
          buf_len += pp->regex_term->string_len + 5;
        } else {
          circular = 1;
          buf_len += 5;
        }
      } else { /* e->kind == ELEM_TERM */
        if (e->e.term->kind == TERM_CODE || e->e.term->kind == TERM_TOKEN)
          d_fail("regex production '%s' cannot include scanners or tokens");
        buf_len += e->e.term->string_len + 5;
      }
    }
  }
  b = buf = (char *)MALLOC(buf_len + 1);
  t = new_term();
  t->kind = TERM_REGEX;
  t->string = buf;
  t->index = g->terminals.n;
  t->regex_production = p;
  vec_add(&g->terminals, t);
  p->regex_term = t;
  p->regex_term->term_name = dup_str(p->name, 0);
  if (circular) { /* attempt to match to regex operators */
    if (p->rules.n != 2)
    Lfail:
      d_fail("unable to resolve circular regex production: '%s'", p->name);
    l = p->rules.v[0]->elems.n + p->rules.v[1]->elems.n;
    if (l == 2 || l == 3) {
      if (p->rules.v[0]->elems.n != 2 && p->rules.v[1]->elems.n != 2) goto Lfail;
      r = p->rules.v[0]->elems.n == 2 ? p->rules.v[0] : p->rules.v[1];
      rr = p->rules.v[0] == r ? p->rules.v[1] : p->rules.v[0];
      if (r->elems.v[0]->e.nterm != p && r->elems.v[1]->e.nterm != p) goto Lfail;
      e = r->elems.v[0]->e.nterm == p ? r->elems.v[1] : r->elems.v[1];
      if (rr->elems.n && e->e.term_or_nterm != rr->elems.v[0]->e.term_or_nterm) goto Lfail;
      t = e->kind == ELEM_TERM ? e->e.term : e->e.nterm->regex_term;
      *b++ = '(';
      if (t->kind == TERM_STRING)
        s = escape_string_for_regex(t->string);
      else
        s = t->string;
      memcpy(b, s, strlen(s));
      b += strlen(s);
      if (t->kind == TERM_STRING) FREE(s);
      *b++ = ')';
      if (l == 2)
        *b++ = '*';
      else
        *b++ = '+';
      *b = 0;
      p->regex_term->string_len = strlen(p->regex_term->string);
    } else
      goto Lfail;
  } else { /* handle the base case, p = (r | r'), r = (e e') */
    if (p->rules.n > 1) *b++ = '(';
    for (j = 0; j < p->rules.n; j++) {
      r = p->rules.v[j];
      if (r->elems.n > 1) *b++ = '(';
      for (k = 0; k < r->elems.n; k++) {
        e = r->elems.v[k];
        t = e->kind == ELEM_TERM ? e->e.term : e->e.nterm->regex_term;
        if (t->kind == TERM_STRING)
          s = escape_string_for_regex(t->string);
        else
          s = t->string;
        memcpy(b, s, strlen(s));
        b += strlen(s);
        if (t->kind == TERM_STRING) FREE(s);
      }
      if (r->elems.n > 1) *b++ = ')';
      if (j != p->rules.n - 1) *b++ = '|';
    }
    if (p->rules.n > 1) *b++ = ')';
    *b = 0;
    p->regex_term->string_len = strlen(p->regex_term->string);
  }
  p->in_regex = 0;
}

static void convert_regex_productions(Grammar *g) {
  uint i, j, k;
  Production *p;
  Rule *r;

  for (i = 0; i < g->productions.n; i++) {
    p = g->productions.v[i];
    if (!p->regex) continue;
    convert_regex_production_one(g, p);
  }
  for (i = 0; i < g->productions.n; i++) {
    p = g->productions.v[i];
    for (j = 0; j < p->rules.n; j++) {
      r = p->rules.v[j];
      for (k = 0; k < r->elems.n; k++) {
        if (r->elems.v[k]->kind == ELEM_NTERM && r->elems.v[k]->e.nterm->regex_term) {
          r->elems.v[k]->e.term = r->elems.v[k]->e.nterm->regex_term;
          r->elems.v[k]->kind = ELEM_TERM;
        }
      }
    }
  }
}

static void convert_nary_priorities(Grammar *g) {
  uint i, j;
  Production *p;
  Rule *r;

  for (i = 0; i < g->productions.n; i++) {
    p = g->productions.v[i];
    for (j = 0; j < p->rules.n; j++) {
      r = p->rules.v[j];
      if (IS_NARY_ASSOC(r->rule_assoc) && (IS_RIGHT_ASSOC(r->rule_assoc) || IS_LEFT_ASSOC(r->rule_assoc))) {
        if (r->elems.n > 1) {
          int left = (r->elems.v[0]->kind == ELEM_NTERM && r->elems.v[0]->e.nterm == p);
          int right = (r->elems.v[r->elems.n - 1]->kind == ELEM_NTERM && r->elems.v[r->elems.n - 1]->e.nterm == p);
          if (left && right) {
            if (r->rule_assoc == ASSOC_NARY_LEFT) {
              r->rule_assoc = ASSOC_BINARY_LEFT;
            } else if (r->rule_assoc == ASSOC_NARY_RIGHT) {
              r->rule_assoc = ASSOC_BINARY_RIGHT;
            }
          } else if (left) {
            if (r->rule_assoc == ASSOC_NARY_RIGHT) {
              d_fail("nary rule with right associativity cannot have left recursive nterm");
            }
            r->rule_assoc = ASSOC_UNARY_LEFT;
          } else if (right) {
            if (r->rule_assoc == ASSOC_NARY_LEFT) {
              d_fail("nary rule with left associativity cannot have right recursive nterm");
            }
            r->rule_assoc = ASSOC_UNARY_RIGHT;
          }
        }
      }
    }
  }
}

static void check_default_actions(Grammar *g) {
  Production *pdefault;

  pdefault = lookup_production(g, "_", 1);
  if (pdefault && pdefault->rules.n > 1) d_fail("number of rules in default action != 1");
}

typedef struct {
  struct State *eq;
  struct Rule *diff_rule;
  struct State *diff_state;
} EqState;

void build_eq(Grammar *g) {
  uint i, j, k, changed = 1, x, xx;
  State *s, *ss;
  EqState *eq, *e, *ee;

  eq = (EqState *)MALLOC(sizeof(EqState) * g->states.n);
  memset(eq, 0, sizeof(EqState) * g->states.n);
  while (changed) {
    changed = 0;
    for (i = 0; i < g->states.n; i++) {
      s = g->states.v[i];
      e = &eq[s->index];
      for (j = i + 1; j < g->states.n; j++) {
        ss = g->states.v[j];
        ee = &eq[ss->index];
        if (e->eq || ee->eq) continue;
        if (s->same_shifts != ss->same_shifts && ss->same_shifts != s) continue;
        /* check gotos */
        if (s->gotos.n != ss->gotos.n) continue;
        for (k = 0; k < s->gotos.n; k++) {
          if (elem_symbol(g, s->gotos.v[k]->elem) != elem_symbol(g, ss->gotos.v[k]->elem)) goto Lcontinue;
          if (s->gotos.v[k]->state != ss->gotos.v[k]->state) {
            EqState *ge = &eq[s->gotos.v[k]->state->index];
            EqState *gee = &eq[ss->gotos.v[k]->state->index];
            if (ge->eq != ss->gotos.v[k]->state && gee->eq != s->gotos.v[k]->state) goto Lcontinue;
            if ((ee->diff_state && ee->diff_state != eq[ss->gotos.v[k]->state->index].eq) ||
                (e->diff_state && e->diff_state != eq[s->gotos.v[k]->state->index].eq))
              goto Lcontinue;
            /* allow one different state */
            ee->diff_state = ss->gotos.v[k]->state;
            e->diff_state = s->gotos.v[k]->state;
          }
        }
        /* check reductions */
        if (s->reduce_actions.n != ss->reduce_actions.n) continue;
        for (k = 0; k < s->reduce_actions.n; k++) {
          if (s->reduce_actions.v[k]->rule == ss->reduce_actions.v[k]->rule) continue;
          if (s->reduce_actions.v[k]->rule->prod != ss->reduce_actions.v[k]->rule->prod) goto Lcontinue;
          if ((x = s->reduce_actions.v[k]->rule->elems.n) != (xx = ss->reduce_actions.v[k]->rule->elems.n)) {
            if ((ee->diff_rule && ee->diff_rule != ss->reduce_actions.v[k]->rule) ||
                (e->diff_rule && e->diff_rule != s->reduce_actions.v[k]->rule))
              goto Lcontinue;
            /* allow one different rule */
            ee->diff_rule = ss->reduce_actions.v[k]->rule;
            e->diff_rule = s->reduce_actions.v[k]->rule;
          }
        }
        ee->eq = s;
        changed = 1;
      Lcontinue:;
      }
    }
  }
  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    e = &eq[s->index];
    if (e->eq) {
      if (d_verbose_level > 2) {
        printf("eq %d %d ", s->index, e->eq->index);
        if (e->diff_state) printf("diff state (%d %d) ", e->diff_state->index, eq[e->eq->index].diff_state->index);
        if (e->diff_rule) {
          printf("diff rule ");
          printf("[ ");
          print_rule(e->diff_rule);
          printf("][ ");
          print_rule(eq[e->eq->index].diff_rule);
          printf("]");
        }
        printf("\n");
      }
    }
  }
  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    e = &eq[s->index];
    if (e->eq && e->diff_state) {
      if (eq[e->diff_state->index].diff_rule && eq[e->diff_state->index].diff_rule->elems.n == 2) {
        s->reduces_to = e->eq;
        s->reduces_with = eq[e->eq->index].diff_rule;
        s->reduces_to_then_with = e->diff_rule;
      } else if (eq[eq[e->eq->index].diff_state->index].diff_rule &&
                 eq[eq[e->eq->index].diff_state->index].diff_rule->elems.n == 2) {
        e->eq->reduces_to = s;
        s->reduces_with = e->diff_rule;
        s->reduces_to_then_with = eq[e->eq->index].diff_rule;
      }
    }
  }
  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    if (s->reduces_to)
      if (d_verbose_level) printf("reduces_to %d %d\n", s->index, s->reduces_to->index);
  }
  FREE(eq);
}

Grammar *new_D_Grammar(char *pathname) {
  Grammar *g = (Grammar *)MALLOC(sizeof(Grammar));
  memset(g, 0, sizeof(Grammar));
  g->pathname = dup_str(pathname, pathname + strlen(pathname));
  return g;
}

static void free_rule(Rule *r) {
  uint i;
  FREE(r->end);
  if (r->final_code.code) FREE(r->final_code.code);
  if (r->speculative_code.code) FREE(r->speculative_code.code);
  vec_free(&r->elems);
  for (i = 0; i < r->pass_code.n; i++) {
    FREE(r->pass_code.v[i]->code);
    FREE(r->pass_code.v[i]);
  }
  vec_free(&r->pass_code);
  FREE(r);
}

void free_D_Grammar(Grammar *g) {
  uint i, j, k;

  for (i = 0; i < g->productions.n; i++) {
    Production *p = g->productions.v[i];
    for (j = 0; j < p->rules.n; j++) {
      Rule *r = p->rules.v[j];
      if (r == g->r) g->r = 0;
      for (k = 0; k < r->elems.n; k++) {
        Elem *e = r->elems.v[k];
        if (e == p->elem) p->elem = 0;
        FREE(e);
      }
      if (r->end == p->elem) p->elem = 0;
      free_rule(r);
    }
    vec_free(&p->rules);
    FREE(p->name);
    if (p->elem) {
      free_rule(p->elem->rule);
      FREE(p->elem);
    }
    FREE(p);
  }
  vec_free(&g->productions);
  for (i = 0; i < g->terminals.n; i++) {
    Term *t = g->terminals.v[i];
    if (t->string) FREE(t->string);
    if (t->term_name) FREE(t->term_name);
    FREE(t);
  }
  vec_free(&g->terminals);
  for (i = 0; i < g->actions.n; i++) free_Action(g->actions.v[i]);
  vec_free(&g->actions);
  if (g->scanner.code) FREE(g->scanner.code);
  for (i = 0; i < g->states.n; i++) {
    State *s = g->states.v[i];
    vec_free(&s->items);
    vec_free(&s->items_hash);
    for (j = 0; j < s->gotos.n; j++) {
      FREE(s->gotos.v[j]->elem);
      FREE(s->gotos.v[j]);
    }
    vec_free(&s->gotos);
    vec_free(&s->shift_actions);
    vec_free(&s->reduce_actions);
    for (j = 0; j < s->right_epsilon_hints.n; j++) FREE(s->right_epsilon_hints.v[j]);
    vec_free(&s->right_epsilon_hints);
    for (j = 0; j < s->error_recovery_hints.n; j++) FREE(s->error_recovery_hints.v[j]);
    vec_free(&s->error_recovery_hints);
    if (!s->same_shifts) {
      for (j = 0; j < s->scanner.states.n; j++) {
        vec_free(&s->scanner.states.v[j]->accepts);
        vec_free(&s->scanner.states.v[j]->live);
        FREE(s->scanner.states.v[j]);
      }
      vec_free(&s->scanner.states);
      for (j = 0; j < s->scanner.transitions.n; j++)
        if (s->scanner.transitions.v[j]) {
          vec_free(&s->scanner.transitions.v[j]->live_diff);
          vec_free(&s->scanner.transitions.v[j]->accepts_diff);
          FREE(s->scanner.transitions.v[j]);
        }
      vec_free(&s->scanner.transitions);
    }
    FREE(s->goto_valid);
    FREE(s);
  }
  vec_free(&g->states);
  for (i = 0; i < g->ncode; i++) FREE(g->code[i].code);
  FREE(g->code);
  for (i = 0; i < g->declarations.n; i++) {
    FREE(g->declarations.v[i]->elem);
    FREE(g->declarations.v[i]);
  }
  vec_free(&g->declarations);
  for (i = 0; i < g->passes.n; i++) {
    FREE(g->passes.v[i]->name);
    FREE(g->passes.v[i]);
  }
  vec_free(&g->passes);
  for (i = 0; i < g->all_pathnames.n; i++) FREE(g->all_pathnames.v[i]);
  FREE(g->pathname);
  if (g->default_white_space) FREE(g->default_white_space);
  FREE(g);
}

int parse_grammar(Grammar *g, char *pathname, char *sarg) {
  D_Parser *p;
  int res = 0;
  char *s = sarg;

  vec_add(&g->all_pathnames, dup_str(pathname, 0));
  if (!s)
    if (!(s = sbuf_read(pathname))) return -1;
  if (!g->productions.n) initialize_productions(g);
  p = new_D_Parser(&parser_tables_dparser_gram, sizeof(D_ParseNode_User));
  p->initial_globals = g;
  p->loc.pathname = pathname;
  if (dparse(p, s, strlen(s))) {
    if (g->productions.n > 1) finish_productions(g);
  } else
    res = -1;
  if (!sarg) FREE(s);
  free_D_Parser(p);
  return res;
}

static int scanner_declaration(Declaration *d) {
  switch (d->kind) {
    case DECLARE_TOKENIZE:
    case DECLARE_LONGEST_MATCH:
    case DECLARE_ALL_MATCHES:
      return 1;
    default:
      return 0;
  }
}

static void set_declaration_group(Production *p, Production *root, Declaration *d) {
  uint i, j;
  if (p->declaration_group[d->kind] == root) return;
  if (d->kind == DECLARE_TOKENIZE && p->declaration_group[d->kind]) {
    d_fail("shared tokenize subtrees");
    return;
  }
  p->declaration_group[d->kind] = root;
  p->last_declaration[d->kind] = d;
  for (i = 0; i < p->rules.n; i++) {
    for (j = 0; j < p->rules.v[i]->elems.n; j++)
      if (p->rules.v[i]->elems.v[j]->kind == ELEM_NTERM)
        set_declaration_group(p->rules.v[i]->elems.v[j]->e.nterm, root, d);
  }
}

static void propogate_declarations(Grammar *g) {
  uint i, j, k;
  Production *p, *start = g->productions.v[0];
  Rule *r;
  Elem *e;

  /* global defaults */
  if (g->tokenizer) new_declaration(g, new_elem_nterm(g->productions.v[0], NULL), DECLARE_TOKENIZE);
  if (g->longest_match) new_declaration(g, new_elem_nterm(g->productions.v[0], NULL), DECLARE_LONGEST_MATCH);
  /* resolve declarations */
  for (i = 0; i < g->declarations.n; i++) {
    e = g->declarations.v[i]->elem;
    if (e->kind == ELEM_UNRESOLVED) {
      if (e->e.unresolved.len == 0)
        p = g->productions.v[0];
      else if (!(p = lookup_production(g, e->e.unresolved.string, e->e.unresolved.len)))
        d_fail("unresolved declaration '%s'", e->e.unresolved.string);
      FREE(e->e.unresolved.string);
      e->e.unresolved.string = 0;
      e->kind = ELEM_NTERM;
      e->e.nterm = p;
    }
  }
  /* build declaration groups (covering a production subtrees) */
  for (i = 0; i < g->declarations.n; i++) {
    if (scanner_declaration(g->declarations.v[i])) {
      p = g->declarations.v[i]->elem->e.nterm;
      if (p == start) {
        for (j = 0; j < g->productions.n; j++) {
          g->productions.v[j]->declaration_group[g->declarations.v[i]->kind] = start;
          g->productions.v[j]->last_declaration[g->declarations.v[i]->kind] = g->declarations.v[i];
        }
      } else
        set_declaration_group(p, p, g->declarations.v[i]);
    }
  }
  /* set terminal scan_kind */
  for (i = 0; i < g->productions.n; i++) {
    p = g->productions.v[i];
    for (j = 0; j < p->rules.n; j++) {
      r = p->rules.v[j];
      for (k = 0; k < r->elems.n; k++) {
        e = r->elems.v[k];
        if (e->kind == ELEM_TERM) {
          if (!p->declaration_group[DECLARE_LONGEST_MATCH] && !p->declaration_group[DECLARE_ALL_MATCHES])
            e->e.term->scan_kind = D_SCAN_DEFAULT;
          else if (p->declaration_group[DECLARE_LONGEST_MATCH] && !p->declaration_group[DECLARE_ALL_MATCHES])
            e->e.term->scan_kind = D_SCAN_LONGEST;
          else if (!p->declaration_group[DECLARE_LONGEST_MATCH] && p->declaration_group[DECLARE_ALL_MATCHES])
            e->e.term->scan_kind = D_SCAN_ALL;
          else {
            if (p->last_declaration[DECLARE_LONGEST_MATCH]->index > p->last_declaration[DECLARE_ALL_MATCHES]->index)
              e->e.term->scan_kind = D_SCAN_LONGEST;
            else
              e->e.term->scan_kind = D_SCAN_ALL;
          }
        }
      }
    }
  }
}

static void merge_shift_actions(State *to, State *from) {
  uint i, j;
  for (i = 0; i < from->shift_actions.n; i++) {
    for (j = 0; j < to->shift_actions.n; j++)
      if (from->shift_actions.v[i]->term == to->shift_actions.v[j]->term) goto Lnext;
    vec_add(&to->shift_actions, from->shift_actions.v[i]);
  Lnext:;
  }
}

static void compute_declaration_states(Grammar *g, Production *p, Declaration *d) {
  State *s, *base_s = NULL;
  uint j, k, scanner = scanner_declaration(d);
  (void)p;

  for (j = 0; j < g->states.n; j++) {
    s = g->states.v[j];
    if (d->kind == DECLARE_TOKENIZE) {
      if (!base_s)
        base_s = s;
      else {
        s->same_shifts = base_s;
        merge_shift_actions(base_s, s);
      }
    }
    if (scanner) {
      for (k = 0; k < s->items.n; k++)
        if (s->items.v[k]->kind == ELEM_TERM) switch (s->items.v[k]->e.term->scan_kind) {
            case D_SCAN_LONGEST:
              if (s->scan_kind == D_SCAN_RESERVED || s->scan_kind == D_SCAN_LONGEST)
                s->scan_kind = D_SCAN_LONGEST;
              else
                s->scan_kind = D_SCAN_MIXED;
              break;
            case D_SCAN_ALL:
              if (s->scan_kind == D_SCAN_RESERVED || s->scan_kind == D_SCAN_ALL)
                s->scan_kind = D_SCAN_ALL;
              else
                s->scan_kind = D_SCAN_MIXED;
              break;
            default:
              break;
          }
    }
  }
}

static void map_declarations_to_states(Grammar *g) {
  uint i;
  State *s;

  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    s->scan_kind = D_SCAN_RESERVED;
  }
  /* map groups to sets of states */
  for (i = 0; i < g->declarations.n; i++)
    if (scanner_declaration(g->declarations.v[i]))
      compute_declaration_states(g, g->declarations.v[i]->elem->e.nterm, g->declarations.v[i]);
  for (i = 0; i < g->states.n; i++) {
    s = g->states.v[i];
    if (s->scan_kind == D_SCAN_RESERVED) s->scan_kind = D_SCAN_DEFAULT; /* set the default */
  }
}

int build_grammar(Grammar *g) {
  resolve_grammar(g);
  convert_regex_productions(g);
  convert_nary_priorities(g);
  propogate_declarations(g);
  merge_identical_terminals(g);
  make_elems_for_productions(g);
  check_default_actions(g);
  build_LR_tables(g);
  map_declarations_to_states(g);
  if (d_verbose_level) {
    printf("%d productions %d terminals %d states %d declarations\n", g->productions.n, g->terminals.n, g->states.n,
           g->declarations.n);
  }
  if (d_verbose_level > 1) {
    print_grammar(g);
    print_states(g);
  }
  build_scanners(g);
  build_eq(g);
  return 0;
}

/*   Wlodek Bzyl, <matwb@univ.gda.pl>
 */

static void print_term_escaped(Term *t, int double_escaped) {
  char *s = 0;
  if (t->term_name) {
    printf("%s ", t->term_name);
  } else if (t->kind == TERM_STRING) {
    s = t->string ? escape_string_single_quote(t->string) : NULL;
    if (!t->string || !*t->string)
      printf("<EOF> ");
    else {
      printf("'%s' ", double_escaped ? escape_string_single_quote(s) : s);
      if (t->ignore_case) printf("/i ");
      if (t->term_priority) printf("%sterm %d ", double_escaped ? "#" : "$", t->term_priority);
    }
  } else if (t->kind == TERM_REGEX) {
    char *quote = double_escaped ? "\\\"" : "\"";
    s = t->string ? escape_string(t->string) : NULL;
    /* char *s = t->string; // ? escape_string(t->string) : NULL; */
    printf("%s%s%s ", quote, double_escaped ? escape_string(s) : s, quote);
    if (t->ignore_case) printf("/i ");
    if (t->term_priority) printf("%sterm %d ", double_escaped ? "#" : "$", t->term_priority);
  } else if (t->kind == TERM_CODE) {
    s = t->string ? escape_string(t->string) : NULL;
    printf("code(\"%s\") ", s);
  } else if (t->kind == TERM_TOKEN) {
    s = t->string ? escape_string(t->string) : NULL;
    printf("%s ", s);
  } else
    d_fail("unknown token kind");
  if (s) FREE(s);
}

/* print_elem changed to call print_term_escaped */
static void print_element_escaped(Elem *ee, int double_escaped) {
  if (ee->kind == ELEM_TERM)
    print_term_escaped(ee->e.term, double_escaped);
  else if (ee->kind == ELEM_UNRESOLVED)
    printf("%s ", ee->e.unresolved.string);
  else
    printf("%s ", ee->e.nterm->name);
}

static void print_global_code(Grammar *g) {
  uint i;
  int print_stdio_h = 1;
  printf("%%<");
  for (i = 0; i < g->ncode; i++) {
    printf("%s", g->code[i].code);
    if (strstr(g->code[i].code, "<stdio.h>") != NULL) print_stdio_h = 0;
  }
  if (print_stdio_h) printf("\n  #include <stdio.h>\n");
  printf("%%>\n\n");
}

static void print_production(Production *p) {
  uint j, k;
  Rule *r;
  char *opening[] = {"", "\n\t  [ printf(\"", "\n\t  { printf(\""};
  char *closing[] = {"\n", "\\n\"); ]\n", "\\n\"); }\n"};
  char *middle[] = {"\n\t:   ", "  <-  ", "  <=  "};
  char *assoc[] = {"$", "#", "#"};
  char *speculative_final_closing = "\\n\"); ]"; /* closing[1] without final newline */
  char *next_or_rule = "\t|   ";
  /*  char *regex_production = "  ::=  "; */

  uint variant = 0;

  for (j = 0; j < p->rules.n; j++) {
  Lmore:
    r = p->rules.v[j];
    if (!j) {
      /*
              if (p->regex) {
                printf("%s%s%s", opening[variant], p->name, regex_production);
              } else {
      */
      printf("%s%s%s", opening[variant], p->name, middle[variant]);
      /*      } */
    } else {
      if (variant == 0)
        printf("%s", next_or_rule);
      else
        printf("%s%s%s", opening[variant], p->name, middle[variant]);
    }

    for (k = 0; k < r->elems.n; k++) print_element_escaped(r->elems.v[k], variant);

    if (r->op_assoc) printf(" %s%s ", assoc[variant], assoc_str(r->op_assoc) + 1);
    if (r->op_priority) printf("%d ", r->op_priority);
    if (r->rule_assoc) printf(" %s%s ", assoc[variant], assoc_str(r->rule_assoc) + 1);
    if (r->rule_priority) printf("%d ", r->rule_priority);

    if ((d_rdebug_grammar_level == 1 && variant == 0) || (d_rdebug_grammar_level == 3 && variant == 0)) {
      variant = 1;
      goto Lmore;
    }
    if ((d_rdebug_grammar_level == 2 && variant == 0) || (d_rdebug_grammar_level == 3 && variant == 1)) {
      if (variant == 1) printf("%s", speculative_final_closing);
      variant = 2;
      goto Lmore;
    }

    printf("%s", closing[variant]);
    variant = 0;
  }
  printf("\t;\n");
  printf("\n");
}

static void print_productions(Grammar *g, char *pathname) {
  uint i;
  if (!g->productions.n) {
    printf("/*\n  There were no productions in the grammar %s\n*/\n", pathname);
    return;
  }
  for (i = 1; i < g->productions.n; i++) print_production(g->productions.v[i]);
}

static void print_declare(char *s, char *n) {
  while (*n && (isspace_(*n) || isdigit_(*n))) n++;
  printf(s, n);
}

static void print_declarations(Grammar *g) {
  uint i;

  if (g->tokenizer) printf("${declare tokenize}\n");
  for (i = 0; i < g->declarations.n; i++) {
    Declaration *dd = g->declarations.v[i];
    Elem *ee = dd->elem;
    switch (dd->kind) {
      case DECLARE_LONGEST_MATCH:
        if (g->longest_match)
          printf("${declare longest_match}\n");
        else
          print_declare("${declare longest_match %s}\n", ee->e.nterm->name);
        break;
      case DECLARE_ALL_MATCHES:
        if (!g->longest_match)
          printf("${declare all_matches}\n");
        else
          print_declare("${declare all_matches %s}\n", ee->e.nterm->name);
        break;
      default:
        printf("\n/*\nDeclaration->kind: %d", dd->kind);
        printf("\nElem->kind:        %d\n*/\n", ee->kind);
    }
  }
  if (g->set_op_priority_from_rule) printf("${declare set_op_priority_from_rule}\n");
  if (g->states_for_all_nterms) printf("${declare all_subparsers}\n");
  /* todo: DECLARE_STATE_FOR */
  if (g->default_white_space) printf("${declare whitespace %s}\n", g->default_white_space);
  if (g->save_parse_tree) printf("${declare save_parse_tree}\n");
  /* todo: DECLARE_NUM */

  if (g->scanner.code) printf("${scanner %s}\n", g->scanner.code);

  {
    int token_exists = 0;
    for (i = 0; i < g->terminals.n; i++) {
      Term *t = g->terminals.v[i];
      if (t->kind == TERM_TOKEN) {
        printf("%s %s", token_exists ? "" : "${token", t->string);
        token_exists = 1;
      }
    }
    if (token_exists) printf("}\n");
  }

  printf("\n");
}

void print_rdebug_grammar(Grammar *g, char *pathname) {
  char ver[30];
  d_version(ver);

  printf("/*\n  Generated by Make DParser Version %s\n", ver);
  printf("  Available at http://dparser.sf.net\n*/\n\n");

  print_global_code(g);
  print_declarations(g);
  print_productions(g, pathname);
}
