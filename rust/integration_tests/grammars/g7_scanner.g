{
// tests/g7.test.g with a Rust tokenizer (a scanner declaration).
#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

pub fn myscanner(
    input: &[u8],
    loc: &mut dparser::Loc,
    symbol: &mut u16,
    _term_priority: &mut i32,
    _op_assoc: &mut u8,
    _op_priority: &mut i32,
) -> i32 {
    let s = match input.get(loc.s) {
        Some(b'a') => A,
        Some(b'b') => BB,
        Some(b'c') => CCC,
        Some(b'd') => DDDD,
        _ => return 0,
    };
    loc.s += 1;
    *symbol = s;
    1
}
}
${scanner myscanner}
${token A BB CCC DDDD}

S: A (BB CCC)+ SS;
SS: DDDD;
