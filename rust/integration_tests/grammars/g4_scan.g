{
// tests/g4.test.g with a Rust external scanner (a scan terminal).
#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

pub fn my_ops_scan(input: &[u8], loc: &mut dparser::Loc, op_assoc: &mut u8, op_priority: &mut i32) -> i32 {
    if input.get(loc.s) == Some(&b'+') {
        loc.s += 1;
        *op_assoc = dparser::grammar::D_ASSOC_BINARY_LEFT;
        *op_priority = 9500;
        return 1;
    }
    0
}
}

X: '1' (${scan my_ops_scan} '2')*;
