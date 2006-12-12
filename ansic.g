{ 
#include <stdio.h>
#include <string.h>

char *reserved_words[] = { "auto", "break", "case", "char", "const", 
  "continue", "default", "do", "double", "else", "enum", "extern", "float", 
  "for", "goto", "if", "int", "long", "register", "return", "short", "signed",
  "sizeof", "static", "struct", "typedef", "union", "unsigned", "void", 
  "volatile", "while", NULL};

static int is_one_of(char *s, char *e, char **list) {
  while (*list) { 
    if (strlen(*list) == e-s && !strncmp(s, *list, e-s)) return 1; 
    list++; 
  }
  return 0;
}
}

program: statements ;

statements: statement*;
statements_expr: statements expression?;
statement: function_definition 
	   | declaration ';' 
	   | expression ';' 
	   | '{' statements_expr '}';

function_definition 
  : declaration_specifiers declarator '{' statements_expr '}' ;

declaration : declaration_specifiers init_declarator_list? ;

init_declarator_list :	init_declarator (',' init_declarator)* ;
init_declarator : declarator ('=' initializer)? ;

declaration_specifiers 
  : (storage_class_specifier | type_specifier | type_qualifier)+ ;

storage_class_specifier: 'auto' | 'register' | 'static' | 'extern' | 'typedef';

type_specifier: 'void' | 'char' | 'short' | 'int' | 'long' | 'float' 
  | 'double' | 'signed' | 'unsigned' | struct_or_union_specifier 
  | enum_specifier | typeID;

type_qualifier: 'const' | 'volatile';

typeID: identifier [
/*
  D_Sym *s = find_sym(${scope}, $n0.start, $n0.end);
  if (!s) ${reject};
  if (!s->user.is_typename) ${reject}; 
*/
];

struct_or_union_specifier: ('struct' | 'union') 
  ( identifier | identifier? '{' struct_declaration+ '}') ;

struct_declaration : specifier_qualifier_list struct_declarator_list ';' ;

specifier_qualifier_list : (type_specifier | type_qualifier)+ ;

struct_declarator_list : struct_declarator (',' struct_declarator)* ;

struct_declarator : declarator | declarator? ':' constant;

enum_specifier : 'enum' 
  ( identifier ('{' enumerator_list '}')? 
  | '{' enumerator_list '}') ;
enumerator_list : enumerator (',' enumerator)* ;
enumerator : identifier ('=' expression)?;

declarator : '*' type_qualifier* declarator | direct_declarator ;

direct_declarator : identifier declarator_suffix*
                  | '(' declarator ')' declarator_suffix* ;

declarator_suffix : '[' expression? ']' | '(' parameter_list? ')';

parameter_list : parameter_declaration_list ( "," "..." )? ;

parameter_declaration 
  : declaration_specifiers (declarator? | abstract_declarator) ;

initializer : expr | '{' initializer (',' initializer)* '}' ;

type_name : specifier_qualifier_list abstract_declarator ;

abstract_declarator 
  : '*' type_qualifier* abstract_declarator 
  | '(' abstract_declarator ')' abstract_declarator_suffix+
  | ('[' expression? ']')+
  | ;

abstract_declarator_suffix
  : '[' expression? ']'
  | '('  parameter_declaration_list? ')' ;

parameter_declaration_list 
  : parameter_declaration ( ',' parameter_declaration )* ;

expression
  : expr
  | expr ',' expr $left 6700
  /* labels */
  | identifier ':' expression $right 6600
  | 'case' expression ':' expression $right 6500
  | 'default' ':' expression $right 6500
  /* conditionals */
  | 'if' '(' statements_expr ')' expression $right 6000
  | 'if' '(' statements_expr ')' statement 'else' expression $right 6100
  | 'switch' '(' statements_expr ')' expression $right 6200
  /* loops */
  | 'while' '(' statements_expr ')' expression $right 6300
  | 'do' statement 'while' expression $right 6400
  | 'for' '(' expression (';' expression (';' expression)?)? ')' 
          expression $right 6500
  /* jump */
  | 'goto' expression? 
  | 'continue' expression? 
  | 'break' expression? 
  | 'return' expression? 
  | expression juxiposition expression
  ;

juxiposition: $binary_op_left 5000;

expr 
  : identifier 
  | constant
  | strings
  | '(' statements_expr')'
  | '[' statements_expr ']'
  | '{' statements_expr '}'
  | expr '?' expression ':' expr $right 8600
  /* post operators */
  | expr '--' $left 9900 
  | expr '++' $left 9900
  | expr '(' statements_expr ')' $left 9900
  | expr '[' statements_expr ']' $left 9900
  | expr '{' statements_expr '}' $left 9900
  /* pre operators */
  | 'sizeof' expression $right 9900
  | '-' expr $right 9800 
  | '+' expr $right 9800
  | '~' expr $right 9800
  | '!' expr $right 9800
  | '*' expr $right 9800 
  | '&' expr $right 9800
  | '--' expr $right 9800 
  | '++' expr $right 9800
  | '(' type_name ')' expr $right 9800
  /* binary operators */
  | expr '->' expr $left 9900
  | expr '.' expr $left 9900
  | expr '*' expr $left 9600 
  | expr '/' expr $left 9600
  | expr '%' expr $left 9600
  | expr '+' expr $left 9500 
  | expr '-' expr $left 9500
  | expr '<<' expr $left 9400 
  | expr '>>' expr $left 9400
  | expr '<' expr $left 9300 
  | expr '<=' expr $left 9300
  | expr '>' expr $left 9300 
  | expr '>=' expr $left 9300
  | expr '==' expr $left 9200 
  | expr '!=' expr $left 9200
  | expr '&' expr $left 9100
  | expr '^' expr $left 9000
  | expr '|' expr $left 8900
  | expr '&&' expr $left 8800 
  | expr '||' expr $left 8700
  | expr '=' expr $left 8500
  | expr '*=' expr $left 8500 
  | expr '/=' expr $left 8500
  | expr '%=' expr $left 8500
  | expr '+=' expr $left 8500 
  | expr '-=' expr $left 8500
  | expr '<<=' expr $left 8500 
  | expr '>>=' expr $left 8500
  | expr '&=' expr $left 8500 
  | expr '|=' expr $left 8500
  | expr '^=' expr $left 8500
  | expr application expr
  ;

application: $binary_op_left 7000;

strings: string | strings string $left 10000;
constant : decimalint | hexint | octalint | character | float1 | float2;
character: "'[^']*'";
string: "\"[^\"]*\"";
decimalint: "[1-9][0-9]*[uUlL]?" $term -1;
hexint: "(0x|0X)[0-9a-fA-F]+[uUlL]?" $term -2;
octalint: "0[0-7]*[uUlL]?" $term -3;
float1: "([0-9]+.[0-9]*|[0-9]*.[0-9]+)([eE][\-\+]?[0-9]+)?[fFlL]?" $term -4;
float2: "[0-9]+[eE][\-\+]?[0-9]+[fFlL]?" $term -5;
identifier: "[a-zA-Z_][a-zA-Z0-9_]*" $term -6 [
  if (is_one_of($n0.start, $n0.end, reserved_words))
    ${reject};
];
