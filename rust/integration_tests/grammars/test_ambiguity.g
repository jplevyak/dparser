{
use dparser;

#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
  pub val: i32,
}
}

start: E {
  // Pass the value up natively!
  $$ = $0.clone();
};

E: E '+' E {
  $$ = $0.clone();
  $$.val += $2.val;
}
 | E '*' E {
  $$ = $0.clone();
  $$.val *= $2.val;
}
 | '1' { $$.val = 1; }
 | '2' { $$.val = 2; }
 | '3' { $$.val = 3; };
