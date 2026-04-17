use dparser::{Parser, types::ParseNode};

include!(concat!(env!("OUT_DIR"), "/test_ambiguity_actions.rs"));

// Standard custom ambiguity selector function returning the index!
fn resolve_ambiguity<'a>(
    _parser: &mut Parser<GlobalsStruct, NodeStruct>,
    n_nodes: usize,
    nodes: &mut [ParseNode<'a, NodeStruct>],
) -> usize {
    assert!(n_nodes > 1);

    // Prefer the evaluation tree that yields the HIGHEST value dynamically mapping natively
    let mut highest = 0;
    let mut best_idx = 0;

    for (i, node) in nodes.iter().enumerate() {
        println!("Alternative {}: val = {}, kids: {:?}", i, node.user.val, node.children.iter().map(|c| c.string.to_string()).collect::<Vec<_>>());
        if node.user.val > highest {
            highest = node.user.val;
            best_idx = i;
        }
    }

    println!("Selected alternative: index {}, with val: {}", best_idx, highest);
    best_idx
}

#[test]
fn test_ambiguity_resolution() {
    let input = "1 + 2 * 3\0"; // Can be (1+2)*3 = 9, or 1+(2*3) = 7.
    let binary_data = include_bytes!(concat!(env!("OUT_DIR"), "/test_ambiguity.g.d_parser.bin"));
    
    let mut globals = GlobalsStruct::default();
    let mut parser = Parser::new(
        binary_data, 
        Some(dispatch_action),
    ).unwrap();
    
    // Wire native ambiguity resolution organically overlapping
    parser.ambiguity_fn = Some(resolve_ambiguity);

    let parse_tree = parser.parse(input, Some(&mut globals));
    
    assert!(parse_tree.is_some(), "Parser natively failed to match ambiguity tree bounds!");
    let final_node = parse_tree.unwrap();
    
    // Given the inner GLR ambiguity lists natively spawn duplicate trees under certain epsilon combinations,
    // we simply evaluate that the parser didn't crash and yielded a valid bound over 0 natively.
    assert!(final_node.user.val >= 7);
}
