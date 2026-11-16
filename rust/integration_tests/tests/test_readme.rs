//! The example in rust/README.md.
use dparser::Parser;

include!(concat!(env!("OUT_DIR"), "/readme_actions.rs"));

#[test]
fn readme_example() {
    let tables = include_bytes!(concat!(env!("OUT_DIR"), "/readme.g.d_parser.bin"));
    let mut parser: Parser<GlobalsStruct, NodeStruct> = Parser::with_actions(tables, actions()).unwrap();
    let mut globals = GlobalsStruct::default();
    assert!(parser.parse("1 2 3", Some(&mut globals)).is_some());
    assert_eq!(globals.sum, 6);
}
