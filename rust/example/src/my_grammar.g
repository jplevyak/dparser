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
  println!("reduce S: A S 'b' A x {} S x {} y {}", $0.x, $2.x, $2.y);
  println!("reduce S: A S 'b' A column {}", $n0.start_loc.column());
  println!("reduce S: A S 'b' global a {} b {}", $g.a, $g.b);
}
 | X
{
  *$$ = $0.clone();
  println!("reduce S: X x {}", $0.x);
  println!("reduce S: X column {}", $n0.start_loc.column());
  println!("reduce S: X global a {}", $g.a);
};

A: 'a' { 
  println!("reduce A x 1 global 11");
  $$.x = 1;
  $g.a = 11;
  println!("reduce A column {}", $n0.start_loc.column());
  println!("reduce A global a {}", $g.a);
};

X: 'x' { 
  println!("reduce X x 2 global 12");
  $$.x = 2;
  $g.a = 12;
  println!("reduce X column {}", $n0.start_loc.column());
  println!("reduce X global a {}", $g.a);
};
