# Rust support for DParser

This is a Rust binding for the DParser library

It consists of two parts: a library that wraps the DParser library and a binary that can be used to generate Rust code from a DParser grammar file.

## Usage

```rust
{
use dparser_lib;

struct GlobalsType {
  a: i32,
  b: i32,
}

struct NodeType {
  x: i32,
  y: i32,
}
}
start: S
{
    println!("start {} {} {} {}\n", $g.a, $g.b, $$.x, $$.y);
}
;
S: A S 'b' { $$ = $0; $$.a += $1.a; $$.b += $1.b; }
 | X { $$ = $0; }
 ;
A: 'a'
{ 
    $g.a += 1;
    println!("reduce A {}\n", $g.a); 
    $$.x = 1;
};

X: 'x';
{ 
    $g.b += 1;
    println!("reduce X {}\n", $g.b); 
    $$.y = 2;
};
```
