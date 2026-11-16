{
// tests/g26.test.g with Rust actions: speculative actions on a terminal.
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub out: Vec<String>,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}
}

${declare mutable_speculative_globals}

S: a [ $g.out.push("S".into()); ];
a ::= 'a' [ $g.out.push("a".into()); ];
