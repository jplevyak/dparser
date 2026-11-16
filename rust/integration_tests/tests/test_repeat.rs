use dparser::{Parser, types::ParseNode};

include!(concat!(env!("OUT_DIR"), "/test_repeat_actions.rs"));

fn parse(input: &str) -> Option<Vec<String>> {
    let tables = include_bytes!(concat!(env!("OUT_DIR"), "/test_repeat.g.d_parser.bin"));
    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        Parser::new(tables, Some(dispatch_action)).unwrap();
    let mut globals = GlobalsStruct::default();
    parser.parse(input, Some(&mut globals)).map(|root| root.user.items)
}

#[test]
fn repetitions_are_flattened() {
    // `item*` must be one node with a child per item, not a nested chain.
    assert_eq!(parse("ab 12 cd ef").unwrap(), vec!["ab", "12", "cd", "ef"]);
}

#[test]
fn last_token_is_not_dropped() {
    // The input used to need a trailing '\0'; without it the last token was lost.
    assert_eq!(parse("ab cd").unwrap(), vec!["ab", "cd"]);
    assert_eq!(parse("ab cd\0").unwrap(), vec!["ab", "cd"]);
    assert_eq!(parse("x").unwrap(), vec!["x"]);
}

#[test]
fn unparseable_input_fails() {
    assert!(parse("ab !!").is_none());
}
