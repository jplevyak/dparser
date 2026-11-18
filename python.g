/* Python Grammar for DParser */

{
#include "dparse.h"

  /* The threaded state of a parse path: the depth of open
     brackets, inside which newlines are whitespace, the stack of
     indentation columns, and the stack of f-string modes.  States are
     interned by py_state, so equal states are the same pointer; NULL is the
     initial state. */
#define PY_MAX_INDENT 100
#define PY_MAX_FSTRING 64
#define PY_F_TEXT 1  /* the literal text of an f-string */
#define PY_F_FIELD 2 /* the expression of a replacement field */
#define PY_F_SPEC 3  /* a format spec */
#define PY_F_BRACKET 4 /* a bracket opened in a replacement field */
  typedef struct PyState {
    int joining;
    int n;
    int indent[PY_MAX_INDENT];
    int fn;
    unsigned char fmode[PY_MAX_FSTRING];
  } PyState;
  const PyState *py_state(const PyState *s);
  const PyState *py_get(void *state);
  const PyState *py_with(void *state, int joining_change);
  const PyState *py_fpush(void *state, int mode);
  const PyState *py_fpop(void *state);
  const PyState *py_fclose(void *state);
  int py_fnest_ok(void *state);
  int py_ftop(void *state);
  int py_column(D_Parser *p, char *s);
  int py_indent(D_Parser *p, void *state, char *s, void **result);
  int py_dedent(D_Parser *p, void *state, char *s, void **result);
  int py_line(D_Parser *p, void *state, char *s);
  int py_is_keyword(const char *s, const char *e);
  void python_whitespace(struct D_Parser *p, d_loc_t *loc, void **p_globals);
}

${declare longest_match}
${declare whitespace python_whitespace}

file_input: (NL | stmt)*;

/* Tokens */
/* A keyword outranks NAME only where both are expected, so NAME rejects
   the hard keywords itself.  Any non-ASCII character (as UTF-8 bytes) may
   be in a name; Python allows only letters and the like, but checking
   that would need Unicode's tables. */
NAME: "[a-zA-Z_\x80-\xff][a-zA-Z0-9_\x80-\xff]*" $term -1
  [ if (py_is_keyword($n0.start_loc.s, $n0.end)) ${reject}; ];
/* Hard keywords.  The trailing context keeps a keyword from matching the
   start of a longer word where no NAME is expected (The origin is not
   The or igin). */
FALSE: "False/[^a-zA-Z0-9_\x80-\xff]";
NONE: "None/[^a-zA-Z0-9_\x80-\xff]";
TRUE: "True/[^a-zA-Z0-9_\x80-\xff]";
AND: "and/[^a-zA-Z0-9_\x80-\xff]";
AS: "as/[^a-zA-Z0-9_\x80-\xff]";
ASSERT: "assert/[^a-zA-Z0-9_\x80-\xff]";
ASYNC: "async/[^a-zA-Z0-9_\x80-\xff]";
AWAIT: "await/[^a-zA-Z0-9_\x80-\xff]";
BREAK: "break/[^a-zA-Z0-9_\x80-\xff]";
CLASS: "class/[^a-zA-Z0-9_\x80-\xff]";
CONTINUE: "continue/[^a-zA-Z0-9_\x80-\xff]";
DEF: "def/[^a-zA-Z0-9_\x80-\xff]";
DEL: "del/[^a-zA-Z0-9_\x80-\xff]";
ELIF: "elif/[^a-zA-Z0-9_\x80-\xff]";
ELSE: "else/[^a-zA-Z0-9_\x80-\xff]";
EXCEPT: "except/[^a-zA-Z0-9_\x80-\xff]";
FINALLY: "finally/[^a-zA-Z0-9_\x80-\xff]";
FOR: "for/[^a-zA-Z0-9_\x80-\xff]";
FROM: "from/[^a-zA-Z0-9_\x80-\xff]";
GLOBAL: "global/[^a-zA-Z0-9_\x80-\xff]";
IF: "if/[^a-zA-Z0-9_\x80-\xff]";
IMPORT: "import/[^a-zA-Z0-9_\x80-\xff]";
IN: "in/[^a-zA-Z0-9_\x80-\xff]";
IS: "is/[^a-zA-Z0-9_\x80-\xff]";
LAMBDA: "lambda/[^a-zA-Z0-9_\x80-\xff]";
NONLOCAL: "nonlocal/[^a-zA-Z0-9_\x80-\xff]";
NOT: "not/[^a-zA-Z0-9_\x80-\xff]";
OR: "or/[^a-zA-Z0-9_\x80-\xff]";
PASS: "pass/[^a-zA-Z0-9_\x80-\xff]";
RAISE: "raise/[^a-zA-Z0-9_\x80-\xff]";
RETURN: "return/[^a-zA-Z0-9_\x80-\xff]";
TRY: "try/[^a-zA-Z0-9_\x80-\xff]";
WHILE: "while/[^a-zA-Z0-9_\x80-\xff]";
WITH: "with/[^a-zA-Z0-9_\x80-\xff]";
YIELD: "yield/[^a-zA-Z0-9_\x80-\xff]";

/* Soft keywords: also names, so both readings are tried. */
MATCH: "match" $term -1;
CASE: "case/[^a-zA-Z0-9_\x80-\xff]" $term -1;
TYPE: "type" $term -1;
/* Imaginary numbers are separate so a pattern can require one in a
   complex literal (1+2j). */
NUMBER ::= integer | floatnumber;
IMAGNUMBER ::= imagnumber;

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

/* Strings, bytes, f-strings and t-strings are kept apart: bytes concatenate
   only with bytes and t-strings only with t-strings.  STRING and BYTES are
   single terminals; f-strings and t-strings are parsed (see below). */
STRING ::= stringprefix? (shortstring | longstring);
BYTES ::= bytesprefix (shortbytes | longbytes);
stringprefix ::= 'r' | 'u' | 'R' | 'U';
bytesprefix ::= 'b' | 'B' | 'br' | 'Br' | 'bR' | 'BR' | 'rb' | 'rB' | 'Rb' | 'RB';
fprefix ::= 'f' | 'F' | 'fr' | 'Fr' | 'fR' | 'FR' | 'rf' | 'rF' | 'Rf' | 'RF';
tprefix ::= 't' | 'T' | 'tr' | 'Tr' | 'tR' | 'TR' | 'rt' | 'rT' | 'Rt' | 'RT';
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

/* Bytes hold only ASCII characters. */
shortbytes ::= "'" ("[^\\\n\'\x80-\xff]" | bytesescape)* "'" | '"' ("[^\\\n\"\x80-\xff]" | bytesescape)* '"';
longbytes ::= "'''" longbytessingleitem* "'''" | '"""' longbytesdoubleitem* '"""';
longbytessingleitem ::= longbytessinglechar | "'" "'"? longbytessinglechar;
longbytesdoubleitem ::= longbytesdoublechar | '"' '"'? longbytesdoublechar;
longbytessinglechar ::= "[^\\\'\x80-\xff]" | bytesescape;
longbytesdoublechar ::= "[^\\\"\x80-\xff]" | bytesescape;
bytesescape ::= "\\[^\x80-\xff]";

/* F-strings and t-strings (PEP 701, PEP 750).  The threaded state keeps a
   stack of f-string modes: in literal text and in a format spec the
   whitespace function skips nothing; in a replacement field newlines are
   whitespace, as inside brackets.  Each kind of quote has its own
   terminals, since the quote ends the text.  The text holds {{ and }};
   a backslash before { is literal (f'\{x}'), and \N{...} is an escape.  A
   format spec has no {{ or }}: a { there starts a nested field. */
FSTART_S ::= fprefix "'" [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
FSTART_D ::= fprefix '"' [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
FSTART_TS ::= fprefix "'''" [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
FSTART_TD ::= fprefix '"""' [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
TSTART_S ::= tprefix "'" [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
TSTART_D ::= tprefix '"' [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
TSTART_TS ::= tprefix "'''" [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
TSTART_TD ::= tprefix '"""' [ ${state} = (void *)py_fpush(${state}, PY_F_TEXT); ];
FEND_S ::= "'" [ ${state} = (void *)py_fpop(${state}); ];
FEND_D ::= '"' [ ${state} = (void *)py_fpop(${state}); ];
FEND_TS ::= "'''" [ ${state} = (void *)py_fpop(${state}); ];
FEND_TD ::= '"""' [ ${state} = (void *)py_fpop(${state}); ];
/* A lone backslash, which can only be before a {, ends the text. */
FTEXT_S ::= (fsinglechar | '{{' | '}}')+ '\\'? | '\\';
FTEXT_D ::= (fdoublechar | '{{' | '}}')+ '\\'? | '\\';
FTEXT_TS ::= (ftsinglechar | '{{' | '}}' | "'" "'"? (ftsinglechar | '{{' | '}}'))+ '\\'? | '\\';
FTEXT_TD ::= (ftdoublechar | '{{' | '}}' | '"' '"'? (ftdoublechar | '{{' | '}}'))+ '\\'? | '\\';
/* In a triple-quoted f-string, text or a format spec may end in one or two
   quotes only before a field or the end of the field; anywhere else they
   would be read as the closing quote. */
FQUOTES_TS ::= "'" "'"?;
FQUOTES_TD ::= '"' '"'?;
/* A colon at the top of a replacement field starts the format spec.  The
   terminal takes the spec's leading text too, so there it is longer than
   := and wins (f'{x:=^10}'). */
FCOLON_S ::= ':' fspec_s? [ ${state} = (void *)py_fpush(${state}, PY_F_SPEC); ];
FCOLON_D ::= ':' fspec_d? [ ${state} = (void *)py_fpush(${state}, PY_F_SPEC); ];
FCOLON_TS ::= ':' fspec_ts? [ ${state} = (void *)py_fpush(${state}, PY_F_SPEC); ];
FCOLON_TD ::= ':' fspec_td? [ ${state} = (void *)py_fpush(${state}, PY_F_SPEC); ];
FSPEC_S ::= fspec_s;
FSPEC_D ::= fspec_d;
FSPEC_TS ::= fspec_ts;
FSPEC_TD ::= fspec_td;
fspec_s ::= fsinglechar+;
fspec_d ::= fdoublechar+;
fspec_ts ::= (ftsinglechar | "'" "'"? ftsinglechar)+;
fspec_td ::= (ftdoublechar | '"' '"'? ftdoublechar)+;
fsinglechar ::= "[^{}\\\n\']" | fescape;
fdoublechar ::= "[^{}\\\n\"]" | fescape;
ftsinglechar ::= "[^{}\\\']" | fescape;
ftdoublechar ::= "[^{}\\\"]" | fescape;
fescape ::= "\\[^{}]" | "\\N\{[^{}\\\n]+\}";
LFB ::= '{' [ ${state} = (void *)py_fpush(${state}, PY_F_FIELD); ];
RFB ::= '}' [ ${state} = (void *)py_fclose(${state}); ];
FCONVERSION ::= '!' "[sra]";
/* Fields nest in format specs at most two deep. */
FNEST: [ if (!py_fnest_ok(${state})) ${reject}; ];

fstring: FSTART_S (FTEXT_S | ffield_s)* FEND_S | FSTART_D (FTEXT_D | ffield_d)* FEND_D
       | FSTART_TS (FTEXT_TS | FQUOTES_TS? ffield_ts)* FEND_TS | FSTART_TD (FTEXT_TD | FQUOTES_TD? ffield_td)* FEND_TD;
tstring: TSTART_S (FTEXT_S | ffield_s)* FEND_S | TSTART_D (FTEXT_D | ffield_d)* FEND_D
       | TSTART_TS (FTEXT_TS | FQUOTES_TS? ffield_ts)* FEND_TS | TSTART_TD (FTEXT_TD | FQUOTES_TD? ffield_td)* FEND_TD;
ffield_s: LFB fexpr '='? FCONVERSION? (FCOLON_S (FSPEC_S | FNEST ffield_s)*)? RFB;
ffield_d: LFB fexpr '='? FCONVERSION? (FCOLON_D (FSPEC_D | FNEST ffield_d)*)? RFB;
ffield_ts: LFB fexpr '='? FCONVERSION? (FCOLON_TS (FSPEC_TS | FQUOTES_TS? FNEST ffield_ts)* FQUOTES_TS?)? RFB;
ffield_td: LFB fexpr '='? FCONVERSION? (FCOLON_TD (FSPEC_TD | FQUOTES_TD? FNEST ffield_td)* FQUOTES_TD?)? RFB;
fexpr: yield_expr | testlist_star_expr;
strings: (STRING | fstring)+ | BYTES+ | tstring+;

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

expr_stmt: testlist_star_expr
         | (star_targets '=')+ (yield_expr | testlist_star_expr)
         | single_target augassign (yield_expr | testlist_star_expr)
         | single_target annassign | type_alias;

/* Targets.  Only a name, an attribute or a subscript can be assigned to,
   annotated or deleted, or a tuple or list of them where several may be. */
star_targets: star_target (',' star_target)* ','?;
star_target: '*' target_atom | target_atom;
target_atom: NAME | attr_or_subscript | LP target_atom RP | LP star_target_seq? RP | LB star_targets? RB;
star_target_seq: star_target (',' star_target)+ ','? | star_target ',';
single_target: NAME | LP single_target RP | attr_or_subscript;
attr_or_subscript: (ATOM_NAME | atom) trailer* ('.' NAME | LB subscriptlist RB);
annassign: ':' test ('=' (yield_expr|testlist_star_expr))?;
type_alias: TYPE NAME type_params? '=' test;

/* Assignments */
augassign: '+=' | '-=' | '*=' | '@=' | '/=' | '%=' | '&=' | '|=' | '^=' | '<<=' | '>>=' | '**=' | '//=';

/* Del Statement */
del_stmt: DEL del_targets;
del_targets: del_target (',' del_target)* ','?;
del_target: NAME | attr_or_subscript | LP del_targets? RP | LB del_targets? RB;

/* Pass Statement */
pass_stmt: PASS;

/* Flow Statements */
flow_stmt: break_stmt | continue_stmt | return_stmt | raise_stmt | yield_stmt;
break_stmt: BREAK;
continue_stmt: CONTINUE;
return_stmt: RETURN testlist_star_expr?;
yield_stmt: yield_expr;
raise_stmt: RAISE (test (FROM test)?)?;

/* Import Statements */
import_stmt: import_name | import_from;
import_name: IMPORT dotted_as_names;
import_from: FROM (('.' | '...')* dotted_name | ('.' | '...')+) IMPORT ('*' | LP import_as_names ','? RP | import_as_names);
import_as_name: NAME (AS NAME)?;
dotted_as_name: dotted_name (AS NAME)?;
/* A trailing comma needs the parentheses. */
import_as_names: import_as_name (',' import_as_name)*;
dotted_as_names: dotted_as_name (',' dotted_as_name)*;
dotted_name: NAME ('.' NAME)*;

/* Global/Nonlocal */
global_stmt: GLOBAL NAME (',' NAME)*;
nonlocal_stmt: NONLOCAL NAME (',' NAME)*;

/* Assert */
assert_stmt: ASSERT test (',' test)?;

/* Compound Statements (Placeholder) */
compound_stmt: if_stmt | while_stmt | for_stmt | try_stmt | with_stmt | funcdef | classdef | match_stmt;

if_stmt: IF namedexpr_test ':' suite (ELIF namedexpr_test ':' suite)* (ELSE ':' suite)?;
while_stmt: WHILE namedexpr_test ':' suite (ELSE ':' suite)?;
for_stmt: ASYNC? FOR star_targets IN testlist_star_expr ':' suite (ELSE ':' suite)?;
/* A try statement uses except or except*, not both. */
try_stmt: TRY ':' suite (((except_clause ':' suite)+ | (except_star_clause ':' suite)+) (ELSE ':' suite)? (FINALLY ':' suite)?
                        | FINALLY ':' suite);
with_stmt: ASYNC? WITH (with_item (',' with_item)* | with_items_in_parens) ':' suite;
/* Parenthesized items need an 'as' in them; without one, the parentheses
   are a tuple or a group, which the plain form reads already. */
with_items_in_parens: LP (test ',')* test AS star_target (',' with_item)* ','? RP;
funcdef: decorators? ASYNC? DEF NAME type_params? parameters ('->' test)? ':' suite;
classdef: decorators? CLASS NAME type_params? (LP arguments? RP)? ':' suite;
match_stmt: MATCH (namedexpr_test | (namedexpr_test | star_expr) ',' star_namedexprs?) ':' NL INDENT case_block+ DEDENT;

suite: simple_stmt | NL INDENT stmt+ DEDENT;

/* Case Block */
case_block: LINE CASE patterns guard? ':' suite;
guard: IF namedexpr_test;
patterns: open_sequence_pattern | pattern;
pattern: as_pattern | or_pattern;
as_pattern: or_pattern AS capture_pattern;
or_pattern: closed_pattern ('|' closed_pattern)*;
closed_pattern: literal_pattern | capture_pattern | wildcard_pattern | value_pattern | group_pattern | sequence_pattern | mapping_pattern | class_pattern;
literal_pattern: signed_number | complex_number | strings | NONE | TRUE | FALSE;
signed_number: '-'? (NUMBER | IMAGNUMBER);
complex_number: '-'? NUMBER ('+' | '-') IMAGNUMBER;
capture_pattern: NAME [ if ($n0.end - $n0.start_loc.s == 1 && *$n0.start_loc.s == '_') return -1; ];
wildcard_pattern: '_';
value_pattern: NAME ('.' NAME)+;
group_pattern: LP pattern RP;
sequence_pattern: LB maybe_sequence_pattern? RB | LP open_sequence_pattern? RP;
open_sequence_pattern: maybe_star_pattern ',' maybe_sequence_pattern?;
maybe_sequence_pattern: maybe_star_pattern (',' maybe_star_pattern)* ','?;
maybe_star_pattern: '*' (capture_pattern | wildcard_pattern) | pattern;
mapping_pattern: LC RC | LC double_star_pattern ','? RC | LC items_pattern ',' double_star_pattern ','? RC | LC items_pattern ','? RC;
items_pattern: key_value_pattern (',' key_value_pattern)*;
key_value_pattern: (literal_pattern | value_pattern) ':' pattern;
double_star_pattern: '**' capture_pattern;
class_pattern: dotted_name LP (positional_patterns ','? | keyword_patterns ','? | positional_patterns ',' keyword_patterns ','?)? RP;
positional_patterns: pattern (',' pattern)*;
keyword_patterns: keyword_pattern (',' keyword_pattern)*;
keyword_pattern: NAME '=' pattern;

/* Decorators */
decorators: decorator+;
decorator: '@' namedexpr_test NL;

/* Functions/Classes Helpers */
/* Parameters before a '/' are positional-only; at least one must precede
   it, and it comes before any '*' or '**'. */
parameters: LP param_list? RP;
/* In Python's order: the positional parameters, with a '/' after the
   positional-only ones; then '*' or *args and the keyword-only ones; then
   **kwargs.  Once a positional parameter has a default, the rest must. */
param_list: pos_params (',' star_params)? ','? | star_params ','?;
pos_params: params (',' default_params)? | default_params
          | params ',' '/' (',' params)? (',' default_params)?
          | (params ',')? default_params ',' '/' (',' default_params)?;
params: param (',' param)*;
default_params: default_param (',' default_param)*;
param: NAME (':' test)?;
default_param: NAME (':' test)? '=' test;
star_params: '*' NAME (':' (test | star_expr))? (',' kwonly_param)* (',' kwargs_param)?
           | '*' (',' kwonly_param)+ (',' kwargs_param)? | kwargs_param;
kwonly_param: NAME (':' test)? ('=' test)?;
kwargs_param: '**' NAME (':' test)?;
/* A call's arguments may be a bare generator expression, f(x for x in y),
   but only when it is the sole argument; class bases may not be one. */
call_arguments: arguments | namedexpr_test comp_for;
/* In Python's order: positional arguments and *x; then keyword arguments
   and *x; then keyword arguments and **x. */
arguments: (positional_arg (',' positional_arg)* (',' keyword_args)? | keyword_args) ','?;
positional_arg: namedexpr_test | '*' test;
keyword_args: keyword_arg (',' (keyword_arg | '*' test))* (',' double_star_args)? | double_star_args;
double_star_args: '**' test (',' (keyword_arg | '**' test))*;
keyword_arg: NAME '=' test;
type_params: LB type_param (',' type_param)* RB;
/* A bound or constraints, and a default (Python 3.13); *Ts and **P take
   only a default. */
type_param: NAME (':' test)? ('=' test)? | '*' NAME ('=' (test | star_expr))? | '**' NAME ('=' test)?;

/* Expressions */
/* An assignment expression (x := 1) may stand only where Python allows a
   named_expression; elsewhere it needs parentheses. */
test: or_test (IF or_test ELSE test)? | lambdef;
namedexpr_test: named_expr | test;
named_expr: NAME ':=' test;
star_namedexprs: (namedexpr_test | star_expr) (',' (namedexpr_test | star_expr))* ','?;
testlist: test (',' test)* ','?;
testlist_star_expr: (test|star_expr) (',' (test|star_expr))* ','?;
star_expr: '*' expr;

or_test: and_test (OR and_test)*;
and_test: not_test (AND not_test)*;
not_test: NOT not_test | comparison;
comparison: expr (comp_op expr)*;
comp_op: '<'|'>'|'=='|'>='|'<='|'!='|IN|NOT IN|IS|IS NOT;

expr: xor_expr ('|' xor_expr)*;
xor_expr: and_expr ('^' and_expr)*;
and_expr: shift_expr ('&' shift_expr)*;
shift_expr: arith_expr (('<<'|'>>') arith_expr)*;
arith_expr: term (('+'|'-') term)*;
term: factor (('*'|'@'|'/'|'%'|'//') factor)*;
factor: ('+'|'-'|'~') factor | power;
power: await_expr ('**' factor)? | atom_expr ('**' factor)?;
await_expr: AWAIT atom_expr;

atom_expr: (ATOM_NAME | atom) trailer*;
atom:   LP (yield_expr|testlist_comp)? RP |
       LB testlist_comp? RB |
       LC dictorsetmaker? RC |
       NUMBER | IMAGNUMBER | strings | '...' | NONE | TRUE | FALSE;

ATOM_NAME: NAME; /* Separate to allow different priorities if needed */

trailer: LP call_arguments? RP | LB subscriptlist RB | '.' NAME;
subscriptlist: subscript (',' subscript)* ','?;
subscript: namedexpr_test | star_expr | test? ':' test? sliceop?;
sliceop: ':' test?;

testlist_comp: namedexpr_test comp_for | star_namedexprs;
comp_for: ASYNC? FOR star_targets IN or_test comp_iter?;
comp_iter: comp_for | IF test_nocond comp_iter?;
test_nocond: or_test (IF or_test ELSE test_nocond)? | lambdef_nocond;
lambdef_nocond: LAMBDA varargslist? NOT_FTOP ':' test_nocond;

/* A comprehension's element cannot be starred. */
dictorsetmaker: test ':' test comp_for | (test ':' test | '**' expr) (',' (test ':' test | '**' expr))* ','?
              | namedexpr_test comp_for | star_namedexprs;

/* At the top of a replacement field a colon starts the format spec, so a
   lambda there must be in parentheses. */
lambdef: LAMBDA varargslist? NOT_FTOP ':' test;
NOT_FTOP: [ if (py_ftop(${state})) ${reject}; ];
/* Lambda parameters: as for def, without annotations. */
varargslist: lambda_pos_params (',' lambda_star_params)? ','? | lambda_star_params ','?;
lambda_pos_params: lambda_params (',' lambda_default_params)? | lambda_default_params
                 | lambda_params ',' '/' (',' lambda_params)? (',' lambda_default_params)?
                 | (lambda_params ',')? lambda_default_params ',' '/' (',' lambda_default_params)?;
lambda_params: NAME (',' NAME)*;
lambda_default_params: lambda_default_param (',' lambda_default_param)*;
lambda_default_param: NAME '=' test;
lambda_star_params: '*' NAME (',' lambda_kwonly_param)* (',' '**' NAME)?
                  | '*' (',' lambda_kwonly_param)+ (',' '**' NAME)? | '**' NAME;
lambda_kwonly_param: NAME ('=' test)?;

yield_expr: YIELD (FROM test | testlist_star_expr?);

with_item: test (AS star_target)?;
/* except* handles exception groups; several types need no parentheses
   when there is no 'as' (Python 3.14). */
except_clause: EXCEPT except_types?;
except_star_clause: EXCEPT '*' except_types;
except_types: test (AS NAME)? | test (',' test)+ ','? | test ',';

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
static const PyState py_initial = {0, 1, {0}, 0, {0}};

static unsigned py_hash(const PyState *s) {
  unsigned h = (unsigned)s->joining * 31 + (unsigned)s->n;
  int i;
  for (i = 0; i < s->n; i++) h = h * 31 + (unsigned)s->indent[i];
  for (i = 0; i < s->fn; i++) h = h * 31 + s->fmode[i];
  return h;
}

static int py_equal(const PyState *a, const PyState *b) {
  return a->joining == b->joining && a->n == b->n && !memcmp(a->indent, b->indent, a->n * sizeof(int)) &&
         a->fn == b->fn && !memcmp(a->fmode, b->fmode, a->fn);
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

/* Open or close a bracket.  In an f-string, brackets are also kept on the
   mode stack, so py_ftop can tell the top of a replacement field. */
const PyState *py_with(void *state, int joining_change) {
  PyState s = *py_get(state);
  s.joining += joining_change;
  if (s.joining < 0) s.joining = 0;
  if (s.fn && joining_change > 0 && s.fn < PY_MAX_FSTRING) s.fmode[s.fn++] = PY_F_BRACKET;
  if (s.fn && joining_change < 0 && s.fmode[s.fn - 1] == PY_F_BRACKET) s.fn--;
  return py_state(&s);
}

/* At the top of a replacement field, outside any bracket in it. */
int py_ftop(void *state) {
  const PyState *s = py_get(state);
  return s->fn && s->fmode[s->fn - 1] == PY_F_FIELD;
}

/* Enter f-string text, a replacement field (where, as in brackets, newlines
   are whitespace) or a format spec. */
const PyState *py_fpush(void *state, int mode) {
  PyState s = *py_get(state);
  if (s.fn >= PY_MAX_FSTRING) return (const PyState *)state;
  s.fmode[s.fn++] = (unsigned char)mode;
  if (mode == PY_F_FIELD) s.joining++;
  return py_state(&s);
}

/* Leave f-string text at its closing quote. */
const PyState *py_fpop(void *state) {
  PyState s = *py_get(state);
  if (s.fn && s.fmode[s.fn - 1] == PY_F_TEXT) s.fn--;
  return py_state(&s);
}

/* Leave a replacement field, and its format spec if it has one. */
const PyState *py_fclose(void *state) {
  PyState s = *py_get(state);
  if (s.fn && s.fmode[s.fn - 1] == PY_F_SPEC) s.fn--;
  if (s.fn && s.fmode[s.fn - 1] == PY_F_FIELD) {
    s.fn--;
    if (s.joining > 0) s.joining--;
  }
  return py_state(&s);
}

/* A field may start in a format spec only if the specs open in this
   f-string are at most two deep. */
int py_fnest_ok(void *state) {
  const PyState *s = py_get(state);
  int i, specs = 0;
  for (i = s->fn - 1; i >= 0 && s->fmode[i] != PY_F_TEXT; i--)
    if (s->fmode[i] == PY_F_SPEC) specs++;
  return specs <= 2;
}

/* The column of s if it starts its line (tabs to multiples of 8), else -1.
   A line holding only blanks and a backslash continues into the next one,
   which then starts at the backslash's column. */
int py_column(D_Parser *p, char *s) {
  char *start = p->loc.s, *first = s, *b;
  int col = 0;
  for (;;) {
    b = first;
    while (b > start && (b[-1] == ' ' || b[-1] == '\t')) b--;
    if (b == start || b[-1] != '\n') break;
    /* After other text, a backslash before the newline ends a comment,
       since python_whitespace skips any other backslash-newline. */
    if (b - 1 > start && b[-2] == '\\') {
      char *q = b - 2;
      while (q > start && (q[-1] == ' ' || q[-1] == '\t')) q--;
      if (q == start || q[-1] == '\n') {
        first = b - 2;
        continue;
      }
    }
    break;
  }
  if (b > start && b[-1] != '\n') return -1;
  for (; b < first; b++) col = *b == '\t' ? (col / 8 + 1) * 8 : col + 1;
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

/* Python's hard keywords; match, case, type and _ are soft. */
int py_is_keyword(const char *s, const char *e) {
  static const char *keywords[] = {
    "False", "None", "True", "and", "as", "assert", "async", "await", "break",
    "class", "continue", "def", "del", "elif", "else", "except", "finally",
    "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal",
    "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"};
  size_t n = e - s, i;
  for (i = 0; i < sizeof(keywords) / sizeof(keywords[0]); i++)
    if (strlen(keywords[i]) == n && !strncmp(keywords[i], s, n)) return 1;
  return 0;
}

int py_line(D_Parser *p, void *state, char *s) {
  const PyState *x = py_get(state);
  return py_column(p, s) == x->indent[x->n - 1];
}

void python_whitespace(struct D_Parser *parser, d_loc_t *loc, void **p_globals) {
  char *p = loc->s;
  const PyState *st = py_get(d_get_whitespace_state(parser));
  int joining = st->joining;
  int at_line_start = parser->loc.s == p || p[-1] == '\n';
  (void)p_globals;
  /* In f-string text or a format spec, whitespace is content. */
  if (st->fn && (st->fmode[st->fn - 1] == PY_F_TEXT || st->fmode[st->fn - 1] == PY_F_SPEC)) return;
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
