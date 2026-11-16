{
// tests/g25.test.g with a Rust whitespace function (declared whitespace).
#[derive(Debug, Default)]
pub struct GlobalsStruct {}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

pub fn mywhite(input: &[u8], loc: &mut dparser::Loc, _globals: Option<&mut GlobalsStruct>) {
    while input.get(loc.s) == Some(&b' ') {
        loc.s += 1;
    }
}
}

${declare whitespace mywhite}
S: '\n' '\t' '\n';
