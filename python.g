/* Python Grammar for DParser */

{
#include "dparse_tables.h"
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

  typedef struct PythonGlobals {
    int indent_stack[1024];
    int current_indent;
    int implicit_line_joining;
  } PythonGlobals;
#define D_ParseNode_Globals PythonGlobals
  int python_indent(PythonGlobals **p_globals);
  int python_dedent(PythonGlobals **p_globals);
  void python_whitespace(struct D_Parser *p, d_loc_t *loc, void **p_globals);
}

${declare longest_match}
${declare whitespace python_whitespace}

file_input: (NL | stmt)*;

/* Tokens */
NAME: "[a-zA-Z_][a-zA-Z0-9_]*" $term -1;
NUMBER ::= integer | floatnumber | imagnumber;
STRING ::= stringprefix?(shortstring | longstring);

integer ::= decimalinteger | octinteger | hexinteger | bininteger;
decimalinteger ::= "[1-9]([0-9_]*[0-9])?|0+";
octinteger ::= "0[oO][0-7_]+";
hexinteger ::= "0[xX][0-9a-fA-F_]+";
bininteger ::= "0[bB][0-1_]+";

floatnumber ::= pointfloat | exponentfloat;
pointfloat ::= "[0-9][0-9_]*\.[0-9_]*|[0-9_]+\.";
exponentfloat ::= "([0-9][0-9_]*|[0-9][0-9_]*\.[0-9_]*|[0-9_]+\.)[eE][+-]?[0-9][0-9_]*";
imagnumber ::= (floatnumber | "[0-9][0-9_]*") "[jJ]";

stringprefix ::= 'r' | 'u' | 'ur' | 'R' | 'U' | 'UR' | 'Ur' | 'uR' | 'f' | 'F' | 'fr' | 'Fr' | 'fR' | 'FR' | 'rf' | 'rF' | 'Rf' | 'RF' | 'b' | 'B' | 'br' | 'Br' | 'bR' | 'BR' | 'rb' | 'rB' | 'Rb' | 'RB';
shortstring ::= "'" shortstringsingleitem* "'" | '"' shortstringdoubleitem* '"';
longstring ::= "'''" longstringitem* "'''" | '"""' longstringitem* '"""';

shortstringsingleitem ::= shortstringsinglechar | escapeseq;
shortstringdoubleitem ::= shortstringdoublechar | escapeseq;
longstringitem ::= longstringchar | escapeseq;

shortstringsinglechar ::= "[^\\\n\']";
shortstringdoublechar ::= "[^\\\n\"]";
longstringchar ::= "[^\\]";
escapeseq ::= "\\[^]";

NL: '\n';
INDENT: [ if (!python_indent(&$g)) return -1; ] ;
DEDENT: [ if (!python_dedent(&$g)) return -1; ] ;

/* Statements */
stmt: simple_stmt | compound_stmt;
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
match_stmt: "match" test ':' NL INDENT case_block+ DEDENT;

suite: simple_stmt | NL INDENT stmt+ DEDENT;

/* Case Block */
case_block: "case" pattern guard? ':' suite;
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

/* Helpers */
/* Implicit line joining handling in C code from original grammar */

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

void python_whitespace(struct D_Parser *parser, d_loc_t *loc, void **p_globals) {
  char *p = loc->s;
  PythonGlobals *pg = *p_globals;
  int i;
  if (!pg) {
    *p_globals = (void**)(pg = (PythonGlobals*)malloc(sizeof(PythonGlobals)));
    memset(pg, 0, sizeof(*pg));
    pg->current_indent = 2; // Start at index 2
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
      case '\\': if (p[1] == '\n') { p+=2; loc->line++; } else goto Ldone; break;
      case '\n': if (i >= 0 || pg->implicit_line_joining) { loc->line++; p++; i = 0; break; }
                   /* else fall through */
      default: goto Ldone;
    }
  }
Ldone:;
    if (i >= 0 && !pg->implicit_line_joining && *p != '\n')
      if (i != pg->indent_stack[pg->current_indent-1]) {
        if (pg->current_indent < 1024) {
          pg->indent_stack[pg->current_indent] = i;
          pg->current_indent++;
        }
      }
    loc->s = p;
}

int python_indent(PythonGlobals **p_globals) {
  PythonGlobals *pg = *p_globals;
  if (pg) {
    if (pg->indent_stack[pg->current_indent-1] > pg->indent_stack[pg->current_indent-2])
      return 1;
    if (pg->indent_stack[pg->current_indent-1] && 
        pg->indent_stack[pg->current_indent-1] == pg->indent_stack[pg->current_indent-2] &&
        pg->indent_stack[pg->current_indent-2] > pg->indent_stack[pg->current_indent-3]) {
      pg->current_indent--;
      return 1;
    }
  }
  return 0;
}

int python_dedent(PythonGlobals **p_globals) {
  int x;
  PythonGlobals *pg = *p_globals;
  if (pg && pg->indent_stack[pg->current_indent-1] < pg->indent_stack[pg->current_indent-2]) {
    pg->current_indent--;
    x = pg->indent_stack[pg->current_indent-1] = pg->indent_stack[pg->current_indent]; /* Replacing top with dedented value */
    while (pg->current_indent >= 2 && x == pg->indent_stack[pg->current_indent-2]) {
      pg->current_indent--;
    }
    return 1;
  }
  return 0;
}

}
