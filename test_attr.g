/* Grammar for test_attr.c: attributes after parsing.  make_dparser -A -H 1
   writes start states for each test's start symbol and the D_RULE_
   constants for d_get_production. */

/* A typed language: a block declares variables visible to everything in
   it, including nested blocks; each expression has a type. */
program: block ;
block: '{' decl* stmt* '}' ;
decl: 'var' name ':' tname ';' ;
stmt: expr ';' | block ;
expr: expr '+' expr $left 10
    | expr '==' expr $left 5
    | name
    | number
    | 'true' ;
tname: 'int' | 'bool' ;
name: "[a-z]+" $term -1 ;
number: "[0-9]+" ;

/* One empty node shared by two parents' children. */
pair: 'p' opt opt ;
opt: ;

/* Attributes that depend on each other in a cycle. */
cyc: 'c' ;
