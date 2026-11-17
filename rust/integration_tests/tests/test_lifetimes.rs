//! Grammar code with Rust lifetimes, character literals holding brackets,
//! and $ in comments and strings.
use dparser::Parser;

include!(concat!(env!("OUT_DIR"), "/test_lifetimes_actions.rs"));
const TABLES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/test_lifetimes.g.d_parser.bin"));

#[test]
fn lifetimes_and_literals() {
    let mut p = Parser::new(TABLES, Some(dispatch_action)).unwrap();
    let mut g = GlobalsStruct::default();
    assert!(p.parse("ab-c de", Some(&mut g)).is_some());
    assert_eq!(g.out, ["word $1 ab }", "word $1 de }"]);
}
