{
// tests/g33.test.g with Rust actions: default pass code for every rule (`_`).
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub out: Vec<String>,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}
}

${pass sym for_all postorder}
${pass gen for_all postorder}

translation_unit: statement*;

_:
  sym: {
    let name = ${parser}.tables().symbol_name($n.symbol as usize).to_string();
    $g.out.push(format!("default sym({} : \"{}\")", name, $n.string));
  }
  gen: {
    let name = ${parser}.tables().symbol_name($n.symbol as usize).to_string();
    $g.out.push(format!("default gen({} : \"{}\")", name, $n.string));
  }
 ;

statement
  : expression ';'
  {
    $g.out.push("final expression".into());
    ${parser}.pass_with_globals($n, ${pass sym}, $g);
    ${parser}.pass_with_globals($n, ${pass gen}, $g);
  }
  ;

expression
  : identifier '=' expression $unary_right 1
  sym: { $g.out.push("sym expression: =".into()); }
  | integer
  gen: { $g.out.push("gen expression: integer".into()); }
  sym: { $g.out.push("sym expression: integer".into()); }
  | expression '+' expression $binary_right 2
  sym: { $g.out.push("sym +".into()); }
  ;

integer: "-?([0-9]|0(x|X))[0-9]*(u|U|b|B|w|W|L|l)*" $term -1
  sym: { $g.out.push("sym integer".into()); }
  ;
identifier: "[a-zA-Z_][a-zA-Z_0-9]*";
