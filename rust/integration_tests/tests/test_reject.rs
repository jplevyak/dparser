use dparser_lib::{Parser, types::ParseNode};

include!(concat!(env!("OUT_DIR"), "/test_reject_actions.rs"));

#[test]
fn test_reject_rule() {
    let input = "a b c\0"; 
    let binary_data = include_bytes!(concat!(env!("OUT_DIR"), "/test_reject.g.d_parser.bin"));
    
    let mut globals = GlobalsStruct::default();
    let mut parser = Parser::new(
        binary_data, 
        Some(dispatch_action),
    ).unwrap();

    let parse_tree = parser.parse(input, Some(&mut globals));
    
    assert!(parse_tree.is_some(), "Parser dynamically failed matching target bounds!");
    let final_node = parse_tree.unwrap();
    
    // Since the first rule uses the `reject` macro returning -1 inside `dispatch_action`.
    // DParser inherently rolls bounds mappings properly over and leverages the fallback alternative effectively mapping!
    assert!(final_node.user.valid_match, "Rejection fallback natively missed resolving overlapping bounds seamlessly!");
}
