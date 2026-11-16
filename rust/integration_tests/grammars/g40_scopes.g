{
// tests/g40.test.g with Rust actions: scopes saved and re-entered.
#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
    pub sym: Option<dparser::SymId>,
    pub saved_scope: Option<dparser::ScopeId>,
}
}

statement: expression ';' ;

expression
 : identifier
 | def_identifier expression $unary_right 5100 /* define variable */
 | def_function expression $unary_right 5100 /* define function */
   [ ${scope} = ${parser}.symtab.enter_scope(${scope}, $0.saved_scope.unwrap()); ]
 | pre_operator expression
 | expression binary_operator expression
 ;

def_identifier: identifier ':'
    [
      ${scope} = ${parser}.symtab.enter_scope(${scope}, ${scope});
      $$.sym = Some(${parser}.symtab.new_sym(${scope}, $n0.string));
    ]
  ;

def_function: identifier identifier+ ':'
    [
      ${scope} = ${parser}.symtab.enter_scope(${scope}, ${scope});
      $$.sym = Some(${parser}.symtab.new_sym(${scope}, $n0.string));
      $$.saved_scope = Some(${scope});
      ${scope} = ${parser}.symtab.new_scope(Some(${scope}));
    ]
  ;

binary_operator
  : '+'         $binary_op_left 9500
  |             $binary_op_left 7000
  ;

pre_operator
  : '+'         $unary_op_right 9800
  ;

identifier: "[a-zA-Z_][a-zA-Z0-9_]*" $term -1;
