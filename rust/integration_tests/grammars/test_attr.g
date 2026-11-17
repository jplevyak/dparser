{
// test_attr.g with Rust types; see tests/test_attr.rs.
#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}
}

${declare subparser program}
${declare subparser pair}
${declare subparser cyc}

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
