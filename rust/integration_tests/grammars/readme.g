{
// The example in rust/README.md.
#[derive(Debug, Default)]
pub struct GlobalsStruct { pub sum: i64 }

#[derive(Debug, Default, Clone)]
pub struct NodeStruct { pub value: i64 }
}

list: number+ { for n in $n0* { $g.sum += n.user.value; } };
number: "[0-9]+" { $$.value = $n0.string.parse().unwrap(); };
