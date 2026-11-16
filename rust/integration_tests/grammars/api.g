{
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub found: Vec<String>,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}
}

${declare subparser stmt}

prog: stmt+ ;

stmt
  : 'if' cond stmt
  | 'if' cond stmt 'else' stmt
  | name ';'
  | '{' stmt* '}'
    { if let Some(n) = ${parser}.find_in_tree($n, ${nterm name}) { $g.found.push(n.string.to_string()); } }
  ;

cond: '(' name ')' ;
name: "[a-z]+" ;
