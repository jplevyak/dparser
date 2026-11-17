{
// Rust code with lifetimes, character literals and $ in comments and
// strings; see tests/test_lifetimes.rs.
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub out: Vec<String>,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

fn first<'a>(s: &'a str) -> &'a str {
    s.split('-').next().unwrap_or("")
}
}

S: word+ ;
word: "[a-z\-]+" {
  let tag: &'static str = "word $1";  // ${not_a_specifier}
  let brace = '}';
  $g.out.push(format!("{} {} {}", tag, first($n0.string), brace));
} ;
