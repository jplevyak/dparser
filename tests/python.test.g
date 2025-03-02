/* Grammar from Python 2.2.2 Grammar/Grammar, converted to dparser */

{
#include "dparse_tables.h"
  typedef struct PythonGlobals {
    int indent_stack[1024];
    int *current_indent;
    int implicit_line_joining;
  } PythonGlobals;
#define D_ParseNode_Globals PythonGlobals
  int python_indent(PythonGlobals **p_globals);
  int python_dedent(PythonGlobals **p_globals);
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

stmt: simple_stmt | compound_stmt;
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
INDENT: [ if (!python_indent(&$g)) return -1; ] ;
DEDENT: [ if (!python_dedent(&$g)) return -1; ] ;
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

LP ::= '(' [ $g->implicit_line_joining++; ];
RP ::= ')' [ $g->implicit_line_joining--; ];
LB ::= '[' [ $g->implicit_line_joining++; ];
RB ::= ']' [ $g->implicit_line_joining--; ];
LC ::= '{' [ $g->implicit_line_joining++; ];
RC ::= '}' [ $g->implicit_line_joining--; ];

{

#include "dparse.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void print_pg(PythonGlobals *pg, char *s) {
  int i, n;
  n = pg->current_indent - pg->indent_stack;
  for (i = 0; i < n; i++)
    printf("%d ", pg->indent_stack[i]);
  printf("%s\n", s);
}

void python_whitespace(struct D_Parser *parser, d_loc_t *loc, void **p_globals) {
  char *p = loc->s;
  PythonGlobals *pg = *p_globals;
  int i;
  if (!pg) {
    *p_globals = (void**)(pg = (PythonGlobals*)malloc(sizeof(PythonGlobals)));
    memset(pg, 0, sizeof(*pg));
    pg->current_indent = &pg->indent_stack[2];
  }
  if (parser->loc.s == p)
    i = 0;
  else
    i = p[-1] == '\n' ? 0 : -1;
  while (1) {
    switch (*p) {
      case '#': p++; while (*p && *p != '\n') p++; break;
      case ' ': p++; if (i >= 0) i++; break;
      case '\t': p++; if (i >= 0) i = (i + 7) & ~7; break;
      case '\n': if (i >= 0 || pg->implicit_line_joining) { loc->line++; p++; i = 0; break; }
                   /* else fall through */
      default: goto Ldone;
    }
  }
Ldone:;
    if (i >= 0 && !pg->implicit_line_joining && *p != '\n')
      if (i != pg->current_indent[-1]) /* || i != pg->current_indent[-2]) */ {
        *pg->current_indent++ = i;
        /* print_pg(pg, "-"); */
      }
    loc->s = p;
}

int python_indent(PythonGlobals **p_globals) {
  PythonGlobals *pg = *p_globals;
  if (pg) {
    if (pg->current_indent[-1] > pg->current_indent[-2])
      return 1;
    if (pg->current_indent[-1] && pg->current_indent[-1] == pg->current_indent[-2] &&
        pg->current_indent[-2] > pg->current_indent[-3]) {
      pg->current_indent--;
      /* print_pg(pg, ">"); */
      return 1;
    }
  }
  return 0;
}

int python_dedent(PythonGlobals **p_globals) {
  int x;
  PythonGlobals *pg = *p_globals;
  if (pg && pg->current_indent[-1] < pg->current_indent[-2]) {
    pg->current_indent--;
    x = pg->current_indent[-1] = pg->current_indent[0];
    while (x == pg->current_indent[-2]) pg->current_indent--;
    /* print_pg(pg, "<"); */
    return 1;
  }
  return 0;
}

}

