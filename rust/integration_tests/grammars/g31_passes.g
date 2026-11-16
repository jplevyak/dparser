{
// tests/g31.test.g with Rust actions: passes run from a final action.
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
  sym: { $g.out.push("sym =".into()); }
  gen: { $g.out.push("gen =".into()); }
  | integer
  gen: { $g.out.push("gen integer".into()); }
  sym: { $g.out.push("sym integer".into()); }
  | expression '+' expression $binary_right 2
  sym: { $g.out.push("sym +".into()); }
  ;

integer: "-?([0-9]|0(x|X))[0-9]*(u|U|b|B|w|W|L|l)*" $term -1;
identifier: "[a-zA-Z_][a-zA-Z_0-9]*";
