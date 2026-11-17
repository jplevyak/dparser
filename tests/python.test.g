/* Grammar from Python 2.2.2 Grammar/Grammar, converted to dparser */

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
${declare subparser single_input}
${declare subparser eval_input}
${declare whitespace python_whitespace}

file_input: (NL | stmt)*;
single_input: NL | simple_stmt | compound_stmt NL;
eval_input: testlist NL*;

decorator: '@' dotted_name ( LP arglist? RP )? NL;
decorators: decorator+;
decorated: decorators (classdef | funcdef);
funcdef: 'def' NAME parameters ':' suite;
parameters: LP varargslist? RP;
varargslist: (fpdef ('=' test)? ',')* ('*' NAME (',' '**' NAME) | '**' NAME) | fpdef ('=' test)? (',' fpdef ('=' test)?)* ','?;
fpdef: NAME | LP fplist RP;
fplist: fpdef (',' fpdef)* ','?;

stmt: LINE (simple_stmt | compound_stmt);
simple_stmt: small_stmt (';' small_stmt)* ';'? NL;
small_stmt: expr_stmt | print_stmt  | 'del' exprlist | 'pass' | flow_stmt | import_stmt | global_stmt | exec_stmt | assert_stmt;
expr_stmt: testlist (augassign testlist | ('=' testlist)*);
augassign: '+=' | '-=' | '*=' | '/=' | '%=' | '&=' | '|=' | '^=' | '<<=' | '>>=' | '**=' | '//=';
print_stmt: 'print' ( ( test (',' test)* ','? )? | '>>' test ( (',' test)+ ','? )? );
pass_stmt: 'pass';
flow_stmt: 'break' | 'continue' | 'return' testlist? | raise_stmt | 'yiled' testlist;
raise_stmt: 'raise' (test (',' test (',' test)?)?)?;
import_stmt: import_name | import_from;
import_name: 'import' dotted_as_names;
import_from: ('from' ('.'* dotted_name | '.'+)
              'import' ('*' | '(' import_as_names ')' | import_as_names));
import_as_name: NAME ('as' NAME)?;
dotted_as_name: dotted_name ('as' NAME)?;
import_as_names: import_as_name (',' import_as_name)* ','?;
dotted_as_names: dotted_as_name (',' dotted_as_name)*;
dotted_name: NAME ('.' NAME)*;
global_stmt: 'global' NAME (',' NAME)*;
exec_stmt: 'exec' expr ('in' test (',' test)?)?;
assert_stmt: 'assert' test (',' test)?;

compound_stmt: if_stmt | while_stmt | for_stmt | try_stmt | with_stmt | funcdef | classdef | decorated;
if_stmt: 'if' test ':' suite ('elif' test ':' suite)* ('else' ':' suite)?;
while_stmt: 'while' test ':' suite ('else' ':' suite)?;
for_stmt: 'for' exprlist 'in' testlist ':' suite ('else' ':' suite)?;
try_stmt: ('try' ':' suite
           ((except_clause ':' suite)+
            ('else' ':' suite)?
            ('finally' ':' suite)? |
            'finally' ':' suite));
with_stmt: 'with' with_item (',' with_item)*  ':' suite;
with_item: test ('as' expr)?;
except_clause: 'except' (test (',' test)?)?;
suite: simple_stmt | NL INDENT stmt+ DEDENT;

testlist_safe: old_test ((',' old_test)+ ','?)?;
old_test: or_test | old_lambdef;
old_lambdef: 'lambda' varargslist? ':' old_test;

test: or_test ('if' or_test 'else' test)? | lambdef;
or_test: and_test ('or' and_test)*;
and_test: not_test ('and' not_test)*;
not_test: 'not' not_test | comparison;
comparison: expr (comp_op expr)*;
comp_op: '<'|'>'|'=='|'>='|'<='|'<>'|'!='|'in'|'not' 'in'|'is'|'is' 'not';
expr: xor_expr ('|' xor_expr)*;
xor_expr: and_expr ('^' and_expr)*;
and_expr: shift_expr ('&' shift_expr)*;
shift_expr: arith_expr (('<<'|'>>') arith_expr)*;
arith_expr: term (('+'|'-') term)*;
term: factor (('*'|'/'|'%'|'//') factor)*;
factor: ('+'|'-'|'~') factor | power;
power: atom trailer* ('**' factor)*;
atom: (LP (yield_expr|testlist_comp)? RP |
       LB listmaker? RB |
       LC dictorsetmaker? RC |
       '`' testlist1 '`' |
       NAME | NUMBER | STRING+);
listmaker: test ( list_for | (',' test)* ','? );
testlist_comp: test ( comp_for | (',' test)* ','? );
lambdef: 'lambda' varargslist? ':' test;
trailer: LP arglist? RP | LB subscriptlist RB | '.' NAME;
subscriptlist: subscript (',' subscript)* ','?;
subscript: '.' '.' '.' | test | test? ':' test? sliceop?;
sliceop: ':' test?;
exprlist: expr (',' expr)* ','?;
testlist: test (',' test)* ','?;
dictorsetmaker: ( (test ':' test (comp_for | (',' test ':' test)* ','?)) |
                  (test (comp_for | (',' test)* ','?)) );

classdef: 'class' NAME (LP testlist? RP)? ':' suite;

arglist: (argument ',')* (argument ','?
             | '*' test (',' argument)* (',' '**' test)?
             | '**' test);
argument: test comp_for? | test '=' test;

list_iter: list_for | list_if;
list_for: 'for' exprlist 'in' testlist_safe list_iter?;
list_if: 'if' test list_iter?;

comp_iter: comp_for | comp_if;
comp_for: 'for' exprlist 'in' or_test comp_iter?;
comp_if: 'if' old_test comp_iter?;

testlist1: test (',' test)*;
encoding_decl: NAME;
yield_expr: 'yield' testlist?;


/* additional material from http://www.python.org/doc/current/ref/grammar.txt */

NL: '\n';
/* INDENT and DEDENT change the indentation stack in the state; LINE checks
   that a statement starts at the current indentation. */
INDENT: [ if (!py_indent(${parser}, ${state}, $n.start_loc.s, &${state})) ${reject}; ] ;
DEDENT: [ if (!py_dedent(${parser}, ${state}, $n.start_loc.s, &${state})) ${reject}; ] ;
LINE: [ if (!py_line(${parser}, ${state}, $n.start_loc.s)) ${reject}; ] ;
NAME ::= (letter|'_') (letter | digit | '_')*;
letter ::= "[a-zA-Z]";
digit ::= "[0-9]";
STRING ::= stringprefix?(shortstring | longstring);
shortstring ::= "'" shortstringsingleitem* "'"
| '"' shortstringdoubleitem* '"';
longstring ::= "'''" longstringitem* "'''"
| '"""' longstringitem* '"""';
shortstringsingleitem ::= shortstringsinglechar | escapeseq;
shortstringdoubleitem ::= shortstringdoublechar | escapeseq;
longstringitem ::= longstringchar | escapeseq;
shortstringsinglechar ::= "[^\\\n\']";
shortstringdoublechar ::= "[^\\\n\"]";
longstringchar ::= "[^\\]";
stringprefix ::= 'r' | 'u' | 'ur' | 'R' | 'U' | 'UR' | 'Ur' | 'uR';
escapeseq ::= "\\[^]";
NUMBER ::= integer | longinteger | floatnumber | imagnumber;
integer ::= decimalinteger | octinteger | hexinteger;
decimalinteger ::= nonzerodigit digit* | '0';
octinteger ::= '0' octdigit+;
hexinteger ::= '0' ('x' | 'X') hexdigit+;
floatnumber ::= pointfloat | exponentfloat;
pointfloat ::= intpart? fraction | intpart '.';
exponentfloat ::= (intpart | pointfloat) exponent;
intpart ::= digit+;
fraction ::= "." digit+;
exponent ::= ("e" | "E") ("+" | "-")? digit+;
imagnumber ::= (floatnumber | intpart) ("j" | "J");
longinteger ::= integer ("l" | "L");
nonzerodigit ::= "[1-9]";
digit ::= "[0-9]";
octdigit ::= "[0-7]";
hexdigit ::= digit | "[a-fA-F]";

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
