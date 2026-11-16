{
// tests/g53.test.g with Rust actions: speculative declarations decide the parse.
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub out: Vec<String>,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}
}

S: decl ';' use ';';

decl
  : 'd' a1 [ ${parser}.symtab.speculative_new_sym(&mut ${scope}, "p"); ] { $g.out.push("declared p".into()); }
  | 'd' a2 [ ${parser}.symtab.speculative_new_sym(&mut ${scope}, "q"); ] { $g.out.push("declared q".into()); }
  ;
a1: 'a';
a2: 'a';

use: identifier [ if ${parser}.symtab.find_sym(${scope}, $n0.string).is_none() { ${reject}; } ]
  { $g.out.push(format!("used {}", $n0.string)); }
  ;

identifier: "[a-z]+";
