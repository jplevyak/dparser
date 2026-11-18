/* Python Grammar for DParser */

{
#include "dparse.h"

  /* The threaded state of a parse path: the depth of open
     brackets, inside which newlines are whitespace, and the stack of
     indentation columns.  States are interned by py_state, so equal states
     are the same pointer; NULL is the initial state. */
#define PY_MAX_INDENT 100
  typedef struct PyState {
    int joining;
    int n;
    int indent[PY_MAX_INDENT];
  } PyState;
  const PyState *py_state(const PyState *s);
  const PyState *py_get(void *state);
  const PyState *py_with(void *state, int joining_change);
  int py_column(D_Parser *p, char *s);
  int py_indent(D_Parser *p, void *state, char *s, void **result);
  int py_dedent(D_Parser *p, void *state, char *s, void **result);
  int py_line(D_Parser *p, void *state, char *s);
  void python_whitespace(struct D_Parser *p, d_loc_t *loc, void **p_globals);
}

${declare longest_match}
${declare whitespace python_whitespace}

file_input: (NL | stmt)*;

/* Tokens */
NAME: "[a-zA-Z_][a-zA-Z0-9_]*" $term -1;
/* Soft keywords: also names, so both readings are tried. */
MATCH: "match" $term -1;
CASE: "case" $term -1;
NUMBER ::= integer | floatnumber | imagnumber;
STRING ::= stringprefix?(shortstring | longstring);

/* A single underscore may separate digits, as in 1_000; it may not lead,
   trail or double up. */
integer ::= decimalinteger | octinteger | hexinteger | bininteger;
decimalinteger ::= "[1-9](_?[0-9])*|0(_?0)*";
octinteger ::= "0[oO](_?[0-7])+";
hexinteger ::= "0[xX](_?[0-9a-fA-F])+";
bininteger ::= "0[bB](_?[01])+";

digitpart ::= "[0-9](_?[0-9])*";
floatnumber ::= pointfloat | exponentfloat;
pointfloat ::= digitpart '.' digitpart? | '.' digitpart;
exponentfloat ::= (digitpart | pointfloat) exponent;
exponent ::= "[eE][+-]?" digitpart;
imagnumber ::= (floatnumber | digitpart) "[jJ]";

stringprefix ::= 'r' | 'u' | 'R' | 'U' | 'f' | 'F' | 'fr' | 'Fr' | 'fR' | 'FR' | 'rf' | 'rF' | 'Rf' | 'RF' | 't' | 'T' | 'tr' | 'Tr' | 'tR' | 'TR' | 'rt' | 'rT' | 'Rt' | 'RT' | 'b' | 'B' | 'br' | 'Br' | 'bR' | 'BR' | 'rb' | 'rB' | 'Rb' | 'RB';
shortstring ::= "'" shortstringsingleitem* "'" | '"' shortstringdoubleitem* '"';
longstring ::= "'''" longstringsingleitem* "'''" | '"""' longstringdoubleitem* '"""';

shortstringsingleitem ::= shortstringsinglechar | escapeseq;
shortstringdoubleitem ::= shortstringdoublechar | escapeseq;
/* One or two quotes are content only when something else follows them, so
   a long string ends at the first unescaped triple quote, not the last. */
longstringsingleitem ::= longstringsinglechar | "'" "'"? longstringsinglechar;
longstringdoubleitem ::= longstringdoublechar | '"' '"'? longstringdoublechar;

shortstringsinglechar ::= "[^\\\n\']";
shortstringdoublechar ::= "[^\\\n\"]";
longstringsinglechar ::= "[^\\\']" | escapeseq;
longstringdoublechar ::= "[^\\\"]" | escapeseq;
escapeseq ::= "\\[^]";

NL: '\n';
/* INDENT and DEDENT change the indentation stack in the state; LINE checks
   that a statement starts at the current indentation. */
INDENT: [ if (!py_indent(${parser}, ${state}, $n.start_loc.s, &${state})) ${reject}; ] ;
DEDENT: [ if (!py_dedent(${parser}, ${state}, $n.start_loc.s, &${state})) ${reject}; ] ;
LINE: [ if (!py_line(${parser}, ${state}, $n.start_loc.s)) ${reject}; ] ;

/* Statements */
stmt: LINE (simple_stmt | compound_stmt);
simple_stmt: small_stmt (';' small_stmt)* ';'? NL;
small_stmt: expr_stmt | del_stmt | pass_stmt | flow_stmt | import_stmt | global_stmt | nonlocal_stmt | assert_stmt;

expr_stmt: testlist_star_expr (annassign | augassign (yield_expr|testlist) | ('=' (yield_expr|testlist_star_expr))*)
         | type_alias;
annassign: ':' test ('=' (yield_expr|testlist_star_expr))?;
type_alias: "type" NAME type_params? '=' test;

/* Assignments */
augassign: '+=' | '-=' | '*=' | '@=' | '/=' | '%=' | '&=' | '|=' | '^=' | '<<=' | '>>=' | '**=' | '//=';

/* Del Statement */
del_stmt: 'del' del_targets;
del_targets: del_target (',' del_target)* ','?;
del_target: NAME | LP del_targets RP | LB del_targets RB | atom_expr_del;
atom_expr_del: atom_expr; /* TODO refine this to only allow valid del targets */

/* Pass Statement */
pass_stmt: 'pass';

/* Flow Statements */
flow_stmt: break_stmt | continue_stmt | return_stmt | raise_stmt | yield_stmt;
break_stmt: 'break';
continue_stmt: 'continue';
return_stmt: 'return' testlist?;
yield_stmt: yield_expr;
raise_stmt: 'raise' (test ('from' test)?)?;

/* Import Statements */
import_stmt: import_name | import_from;
import_name: 'import' dotted_as_names;
import_from: 'from' (('.' | '...')* dotted_name | ('.' | '...')+) 'import' ('*' | LP import_as_names RP | import_as_names);
import_as_name: NAME ('as' NAME)?;
dotted_as_name: dotted_name ('as' NAME)?;
import_as_names: import_as_name (',' import_as_name)* ','?;
dotted_as_names: dotted_as_name (',' dotted_as_name)*;
dotted_name: NAME ('.' NAME)*;

/* Global/Nonlocal */
global_stmt: 'global' NAME (',' NAME)*;
nonlocal_stmt: 'nonlocal' NAME (',' NAME)*;

/* Assert */
assert_stmt: 'assert' test (',' test)?;

/* Compound Statements (Placeholder) */
compound_stmt: if_stmt | while_stmt | for_stmt | try_stmt | with_stmt | funcdef | classdef | match_stmt;

if_stmt: 'if' test ':' suite ('elif' test ':' suite)* ('else' ':' suite)?;
while_stmt: 'while' test ':' suite ('else' ':' suite)?;
for_stmt: 'async'? 'for' exprlist 'in' testlist ':' suite ('else' ':' suite)?;
try_stmt: 'try' ':' suite ((except_clause ':' suite)+ ('else' ':' suite)? ('finally' ':' suite)? | 'finally' ':' suite);
with_stmt: 'async'? 'with' with_item (',' with_item)* ':' suite;
funcdef: decorators? 'async'? 'def' NAME type_params? parameters ('->' test)? ':' suite;
classdef: decorators? 'class' NAME type_params? (LP arguments? RP)? ':' suite;
match_stmt: MATCH test ':' NL INDENT case_block+ DEDENT;

suite: simple_stmt | NL INDENT stmt+ DEDENT;

/* Case Block */
case_block: LINE CASE pattern guard? ':' suite;
guard: 'if' test;
pattern: as_pattern | or_pattern;
as_pattern: or_pattern 'as' NAME;
or_pattern: closed_pattern ('|' closed_pattern)*;
closed_pattern: literal_pattern | capture_pattern | wildcard_pattern | value_pattern | group_pattern | sequence_pattern | mapping_pattern | class_pattern;
literal_pattern: NUMBER | STRING | 'None' | 'True' | 'False';
capture_pattern: NAME [ if ($n0.end - $n0.start_loc.s == 1 && *$n0.start_loc.s == '_') return -1; ];
wildcard_pattern: '_';
value_pattern: dotted_name;
group_pattern: LP pattern RP;
sequence_pattern: LB patterns? RB | LP patterns? RP;
patterns: pattern (',' pattern)* ','?;
mapping_pattern: LC items_pattern? RC;
items_pattern: key_value_pattern (',' key_value_pattern)* ','?;
key_value_pattern: (literal_pattern | value_pattern) ':' pattern;
class_pattern: dotted_name LP patterns? RP; /* Simplified */

/* Decorators */
decorators: decorator+;
decorator: '@' dotted_name (LP arguments? RP)? NL;

/* Functions/Classes Helpers */
parameters: LP (param_item (',' param_item)* ','?)? RP;
param_item: param | '*' NAME? | '**' NAME;
param: NAME (':' test)? ('=' test)?;
arguments: arglist; 
arglist: argument (',' argument)* ','?;
argument: test ('=' test)? | '*' test | '**' test;
type_params: LB type_param (',' type_param)* RB;
type_param: NAME;

/* Expressions */
test: named_expr | or_test ('if' or_test 'else' test)? | lambdef;
named_expr: NAME ':=' test;
testlist: test (',' test)* ','?;
testlist_star_expr: (test|star_expr) (',' (test|star_expr))* ','?;
star_expr: '*' expr;

or_test: and_test ('or' and_test)*;
and_test: not_test ('and' not_test)*;
not_test: 'not' not_test | comparison;
comparison: expr (comp_op expr)*;
comp_op: '<'|'>'|'=='|'>='|'<='|'!='|'in'|'not' 'in'|'is'|'is' 'not';

expr: xor_expr ('|' xor_expr)*;
xor_expr: and_expr ('^' and_expr)*;
and_expr: shift_expr ('&' shift_expr)*;
shift_expr: arith_expr (('<<'|'>>') arith_expr)*;
arith_expr: term (('+'|'-') term)*;
term: factor (('*'|'@'|'/'|'%'|'//') factor)*;
factor: ('+'|'-'|'~') factor | power;
power: await_expr ('**' factor)? | atom_expr ('**' factor)?;
await_expr: 'await' atom_expr;

atom_expr: (ATOM_NAME | atom) trailer*;
atom:   LP (yield_expr|testlist_comp)? RP |
       LB testlist_comp? RB |
       LC dictorsetmaker? RC |
       NUMBER | STRING+ | '...' | 'None' | 'True' | 'False';

ATOM_NAME: NAME; /* Separate to allow different priorities if needed */

trailer: LP arguments? RP | LB subscriptlist RB | '.' NAME;
subscriptlist: subscript (',' subscript)* ','?;
subscript: test | test? ':' test? sliceop?;
sliceop: ':' test?;

testlist_comp: (test|star_expr) ( comp_for | (',' (test|star_expr))* ','? );
comp_for: 'async'? 'for' exprlist 'in' or_test comp_iter?;
comp_iter: comp_for | 'if' test_nocond comp_iter?;
test_nocond: or_test ('if' or_test 'else' test_nocond)? | lambdef_nocond;
lambdef_nocond: 'lambda' varargslist? ':' test_nocond;

dictorsetmaker: ( ((test ':' test | '**' expr) (comp_for | (',' (test ':' test | '**' expr))* ','?)) |
                  ((test | star_expr) (comp_for | (',' (test | star_expr))* ','?)) );

lambdef: 'lambda' varargslist? ':' test;
varargslist: (vfpdef ('=' test)? ',')* ('*' NAME (',' '**' NAME)? | '**' NAME)? | vfpdef ('=' test)? (',' vfpdef ('=' test)?)* ','?;
vfpdef: NAME;

exprlist: (expr|star_expr) (',' (expr|star_expr))* ','?;
yield_expr: 'yield' ('from' test | testlist?);

with_item: test ('as' expr)?;
except_clause: 'except' (test ('as' NAME)?)?;

/* Brackets: inside them newlines are whitespace (implicit line joining).
   The terminals' actions run when they are shifted, so the whitespace right
   after a bracket already sees the new depth. */
LP ::= '(' [ ${state} = (void *)py_with(${state}, 1); ];
RP ::= ')' [ ${state} = (void *)py_with(${state}, -1); ];
LB ::= '[' [ ${state} = (void *)py_with(${state}, 1); ];
RB ::= ']' [ ${state} = (void *)py_with(${state}, -1); ];
LC ::= '{' [ ${state} = (void *)py_with(${state}, 1); ];
RC ::= '}' [ ${state} = (void *)py_with(${state}, -1); ];

{

#include <stdlib.h>
#include <string.h>

/* Interning: a chained hash table of states, kept for the life of the
   process (there are few distinct states). */
#define PY_STATE_BUCKETS 1024
typedef struct PyStateEntry {
  struct PyStateEntry *next;
  PyState s;
} PyStateEntry;
static PyStateEntry *py_states[PY_STATE_BUCKETS];
static const PyState py_initial = {0, 1, {0}};

static unsigned py_hash(const PyState *s) {
  unsigned h = (unsigned)s->joining * 31 + (unsigned)s->n;
  int i;
  for (i = 0; i < s->n; i++) h = h * 31 + (unsigned)s->indent[i];
  return h;
}

static int py_equal(const PyState *a, const PyState *b) {
  return a->joining == b->joining && a->n == b->n && !memcmp(a->indent, b->indent, a->n * sizeof(int));
}

const PyState *py_state(const PyState *s) {
  unsigned h = py_hash(s) % PY_STATE_BUCKETS;
  PyStateEntry *e;
  if (py_equal(s, &py_initial)) return NULL;
  for (e = py_states[h]; e; e = e->next)
    if (py_equal(&e->s, s)) return &e->s;
  e = (PyStateEntry *)malloc(sizeof(PyStateEntry));
  e->s = *s;
  e->next = py_states[h];
  py_states[h] = e;
  return &e->s;
}

const PyState *py_get(void *state) { return state ? (const PyState *)state : &py_initial; }

const PyState *py_with(void *state, int joining_change) {
  PyState s = *py_get(state);
  s.joining += joining_change;
  if (s.joining < 0) s.joining = 0;
  return py_state(&s);
}

/* The column of s if it starts its line (tabs to multiples of 8), else -1. */
int py_column(D_Parser *p, char *s) {
  char *start = p->loc.s, *b = s;
  int col = 0;
  while (b > start && (b[-1] == ' ' || b[-1] == '\t')) b--;
  if (b > start && (b[-1] != '\n' || (b - 1 > start && b[-2] == '\\'))) return -1;
  for (; b < s; b++) col = *b == '\t' ? (col / 8 + 1) * 8 : col + 1;
  return col;
}

/* Open a level at the column of s, which must be deeper than the current one. */
int py_indent(D_Parser *p, void *state, char *s, void **result) {
  PyState x = *py_get(state);
  int col = py_column(p, s);
  if (col <= x.indent[x.n - 1] || x.n >= PY_MAX_INDENT) return 0;
  x.indent[x.n++] = col;
  *result = (void *)py_state(&x);
  return 1;
}

/* Close one level; the column of s must match an enclosing level. */
int py_dedent(D_Parser *p, void *state, char *s, void **result) {
  PyState x = *py_get(state);
  int col = py_column(p, s), i;
  if (col < 0 || col >= x.indent[x.n - 1]) return 0;
  for (i = 0; i < x.n - 1 && x.indent[i] != col; i++);
  if (i >= x.n - 1) return 0;
  x.n--;
  *result = (void *)py_state(&x);
  return 1;
}

int py_line(D_Parser *p, void *state, char *s) {
  const PyState *x = py_get(state);
  return py_column(p, s) == x->indent[x->n - 1];
}

void python_whitespace(struct D_Parser *parser, d_loc_t *loc, void **p_globals) {
  char *p = loc->s;
  int joining = py_get(d_get_whitespace_state(parser))->joining;
  int at_line_start = parser->loc.s == p || p[-1] == '\n';
  (void)p_globals;
  while (1) {
    switch (*p) {
      case '#': p++; while (*p && *p != '\n') p++; break;
      case ' ': case '\t': case '\f': p++; break;
      case '\\': if (p[1] == '\n') { p += 2; loc->line++; } else goto Ldone; break;
      /* blank lines, and newlines inside brackets, are whitespace */
      case '\n': if (at_line_start || joining) { loc->line++; p++; at_line_start = 1; break; }
                 goto Ldone;
      case '\r': if (p[1] == '\n') { p++; break; } goto Ldone;
      default: goto Ldone;
    }
  }
Ldone:
  loc->s = p;
}

}
