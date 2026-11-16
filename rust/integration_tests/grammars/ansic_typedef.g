{
// tests/ansic.test.g with Rust actions: typedef names are tracked in the
// symbol table by speculative actions, which decide how C is parsed.  A
// symbol's user value is 1 for a typedef name.
#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}
}

${declare tokenize}
${declare longest_match}

translation_unit: external_declaration+ ;

external_declaration : function_definition | declaration ;

function_definition : declaration_specifiers declarator compound_statement ;

declaration : declaration_specifiers init_declarator_list? ';' [
  if ${parser}.find_in_tree(&$n0, ${string typedef}).is_some() {
    if let Some(n) = ${parser}.find_in_tree(&$n1, ${nterm identifier}) {
      let s = ${parser}.symtab.new_sym(${scope}, n.string);
      ${parser}.symtab.sym_mut(s).user = 1;
    }
  }
];

declaration_specifiers 
  : (storage_class_specifier | type_specifier | type_qualifier)+ ;

storage_class_specifier: 'auto' | 'register' | 'static' | 'extern' | 'typedef';

type_specifier: 'void' | 'char' | 'short' | 'int' | 'long' | 'float' 
  | 'double' | 'signed' | 'unsigned' | struct_or_union_specifier 
  | enum_specifier | typeID;

type_qualifier: 'const' | 'volatile';

typeID: ident [
  match ${parser}.symtab.find_sym(${scope}, $n0.string) {
    Some(s) if ${parser}.symtab.sym(s).user != 0 => {}
    _ => { ${reject}; }
  }
];

init_declarator_list :	init_declarator (',' init_declarator)* ;
init_declarator : declarator ('=' initializer)? ;

struct_or_union_specifier: ('struct' | 'union') 
  ( struct_ident | struct_ident? '{' struct_declaration+ '}') ;

struct_declaration : specifier_qualifier_list struct_declarator_list ';' ;

specifier_qualifier_list : (type_specifier | type_qualifier)+ ;

struct_declarator_list : struct_declarator (',' struct_declarator)* ;

struct_declarator : declarator | declarator? ':' constant;

enum_specifier : 'enum' 
  ( identifier ('{' enumerator_list '}')? 
  | '{' enumerator_list '}') ;
enumerator_list : enumerator (',' enumerator)* ;
enumerator : identifier ('=' constant_expression)?;

declarator : '*' type_qualifier* declarator | direct_declarator ;

direct_declarator : identifier declarator_suffix*
                  | '(' declarator ')' declarator_suffix* ;

declarator_suffix : '[' constant_expression? ']'
		  | '(' parameter_list? ')';

parameter_list : parameter_declaration_list ( ',' '...' )? ;

parameter_declaration 
  : declaration_specifiers (declarator? | abstract_declarator) ;

initializer : assignment_expression
	    | '{' initializer (',' initializer)* '}' ;

type_name : specifier_qualifier_list abstract_declarator ;

abstract_declarator : '*' type_qualifier* abstract_declarator 
  | '(' abstract_declarator ')' abstract_declarator_suffix+
  | ('[' constant_expression? ']')+
  | ;

abstract_declarator_suffix
  : '[' constant_expression? ']'
  | '('  parameter_declaration_list? ')' ;

parameter_declaration_list
  : parameter_declaration ( ',' parameter_declaration )* ;

statement_list : (statement)+ ;

statement 
  : labeled_statement
  | expression ';'
  | compound_statement
  | selection_statement
  | iteration_statement
  | jump_statement
  | ';' ;

labeled_statement
  : identifier ':' statement
  | 'case' constant_expression ':' statement
  | 'default' ':' statement ;

compound_statement : '{' (declaration)* statement_list? '}' ;

selection_statement
  : 'if' '(' expression ')' statement ('else' statement)?
  | 'switch' '(' expression ')' statement ;

iteration_statement
  : 'while' '(' expression ')' statement
  | 'do' statement 'while' '(' expression ')' ';'
  | 'for' '(' expression? ';' expression? ';' expression? ')' statement ;

jump_statement
  : 'goto' identifier ';'
  | 'continue' ';'
  | 'break' ';'
  | 'return' expression? ';' 
  ;

expression : assignment_expression (',' assignment_expression)* ;

assignment_expression : conditional_expression 
  ( assignment_operator assignment_expression)? ;
assignment_operator: 
  '=' | '*=' | '/=' | '%=' | '+=' | '-=' | '<<=' | '>>=' | '&=' | '|=';

conditional_expression : logical_or_expression 
  ('?' logical_or_expression ':' logical_or_expression)? ;

constant_expression : conditional_expression ;

logical_or_expression :	logical_and_expression 
  ('||' logical_and_expression)* ;

logical_and_expression : inclusive_or_expression 
  ('&&' inclusive_or_expression)* ;

inclusive_or_expression : exclusive_or_expression 
  ('|' exclusive_or_expression)* ;

exclusive_or_expression : and_expression ('^' and_expression)* ;

and_expression : equality_expression ('&' equality_expression)* ;

equality_expression : relational_expression 
  (('!=' | '==') relational_expression)* ;

relational_expression : shift_expression
 (('<' | '>' | '<=' | '>=') shift_expression)* ;

shift_expression : additive_expression (('<<' | '>>') additive_expression)* ;

additive_expression : multiplicative_expression
  (('+' | '-') multiplicative_expression)* ;

multiplicative_expression : cast_expression 
  (('*' | '/' | '%') cast_expression)* ;

cast_expression : '(' type_name ')' cast_expression | unary_expression ;

unary_expression 
  : postfix_expression
  | '++' unary_expression
  | '--' unary_expression
  | unary_operator cast_expression
  | 'sizeof' ('(' type_name ')' | unary_expression) ;

unary_operator : '&' | '*' | '-' | '~' | '!' ;

postfix_expression : primary_expression
  ('[' expression ']' 
  | '(' argument_expression_list? ')'
  | '.' identifier
  | '->' identifier
  | '++'
  | '--'
  )* ;

primary_expression 
  : identifier
  | constant
  | string+
  | '(' expression ')'
  ;

argument_expression_list
  : assignment_expression (',' assignment_expression)* ;

struct_ident : ident;

identifier : ident [
  if let Some(s) = ${parser}.symtab.find_sym(${scope}, $n0.string) {
    if ${parser}.symtab.sym(s).user != 0 { ${reject}; }
  }
];

constant : decimalint | hexint | octalint | character | float1 | float2;

character: "'([^'\\]|\\[^])*'";
string: "\"([^\"\\]|\\[^])*\"";
decimalint: "[1-9][0-9]*[uUlL]?" $term -1;
hexint: "(0x|0X)[0-9a-fA-F]+[uUlL]?" $term -2;
octalint: "0[0-7]*[uUlL]?" $term -3;
float1: "([0-9]+.[0-9]*|[0-9]*.[0-9]+)([eE][\-\+]?[0-9]+)?[fFlL]?" $term -4;
float2: "[0-9]+[eE][\-\+]?[0-9]+[fFlL]?" $term -5;
ident: "[a-zA-Z_][a-zA-Z0-9_]*" $term -6;
