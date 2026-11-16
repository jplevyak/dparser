{
// tests/g28.test.g with Rust actions: nested scopes, updates and commit.
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub out: Vec<String>,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
    pub value: i64,
}
}

translation_unit: statement*;

statement
  : expression ';'
  { $g.out.push(format!("{}", $0.value)); }
  | '{' statement* '}'
  [ ${scope} = ${parser}.symtab.enter_scope(${scope}, $n0.scope); ]
  { ${scope} = ${parser}.symtab.commit_scope(${scope}); }
  ;

expression
  : identifier ':' expression
  [
    ${scope} = ${parser}.symtab.new_scope(Some(${scope}));
    let s = ${parser}.symtab.new_sym(${scope}, $n0.string);
    ${parser}.symtab.sym_mut(s).user = $2.value as u64;
    $$.value = $2.value;
  ]
  | identifier '=' expression
  [
    if let Some(s) = ${parser}.symtab.find_sym(${scope}, $n0.string) {
      let s = ${parser}.symtab.update_sym(s, &mut ${scope});
      ${parser}.symtab.sym_mut(s).user = $2.value as u64;
    }
    $$.value = $2.value;
  ]
  | integer
  [ $$.value = $n0.string.parse().unwrap_or(0); ]
  | identifier
  [
    if let Some(s) = ${parser}.symtab.find_sym(${scope}, $n0.string) {
      $$.value = ${parser}.symtab.sym(s).user as i64;
    }
  ]
  | expression '+' expression
  [ $$.value = $0.value + $1.value; ]
  ;

integer: "-?([0-9]|0(x|X))[0-9]*(u|U|b|B|w|W|L|l)*" $term -1;
identifier: "[a-zA-Z_][a-zA-Z_0-9]*";
