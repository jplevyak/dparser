{
use dparser_lib;

#[derive(Debug, Default)]
pub struct GlobalsStruct {
  a: i32,
  b: i32,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
  x: i32,
  y: i32,
}

pub const INDEX_OF_A:u32 = ${nterm A};

}

start: S {
  println!("start: S global a {}", $g.a);
};

S: A S 'b' 
{
  println!("reduce S: a {} b {} x {} y {}", $g.a, $g.b, $$.x, $$.y);
  println!("reduce S: A S 'b', A x {} S x {} y {}", $0.x, $2.x, $2.y);
  *$$ = $1.clone();
  $$.x = $0.x + $1.x;
  $g.a += 10;
}
 | X
{
  println!("reduce S: X before column {} global a {} x {} x0 {}", $n0.start_loc.column(), $$.x, $g.a, $0.x);
  *$$ = $0.clone();
  println!("reduce S: X after column {} global a {} x {} x0 {}", $n.start_loc.column(), $$.x, $g.a, $0.x);
};

A: 'a' { 
  $$.x = 1;
  $$.y = 2;
  $g.a = 11;
  $g.b = 101;
  println!("reduce A column {} global a {} x {}", $n0.start_loc.column(), $g.a, $$.x);
};

X: 'x' { 
  $$.x += 1;
  $$.y += 1;
  $g.a += 1;
  $g.b += 1;
  println!("reduce X column {} global a {} x {}", $n0.start_loc.column(), $g.a, $$.x);
};
