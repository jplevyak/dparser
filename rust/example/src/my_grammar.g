{
use dparser_lib;

pub struct GlobalsStruct {
  a: i32,
  b: i32,
};

pub struct NodeStruct {
  x: i32,
  y: i32,
};

pub const index_of_A:u32 = ${nterm A};

}

start: S {
  writeln!("start: S global a {}\n", $g.a);
};

S: A S 'b' 
{
  writeln!("reduce S: A S 'b' A x {} S x {}\n", $0.x, $2.x);
  writeln!("reduce S: A S 'b' A column {}\n", $n0.start_loc.column());
  writeln!("reduce S: A S 'b' global a {}\n", $g.a); 
}
 | X
{
  $$ = $0;
  writeln!("reduce S: X x {}\n", $0.x);
  writeln!("reduce S: X column {}\n", $n0.start_loc.column());
  writeln!("reduce S: X global a {}\n", $g.a);
};

A: 'a' { 
  writeln!("reduce A x 1 global 11\n");
  $$.x = 1;
  $g.a = 11;
  writeln!("reduce A column {}\n", $n0.start_loc.column());
  writeln!("reduce A global a {}\n", $g.a); 
};

X: 'x' { 
  writeln!("reduce X x 2 global 12\n");
  $$.x = 2;
  $g.a = 12;
  writeln!("reduce X column {}\n", $n0.start_loc.column());
  writeln!("reduce X global a {}\n", $g.a); 
};
