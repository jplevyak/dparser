use dparser_lib::{ParseNodeWrapper, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));


fn main() {
    let input_string = "a x  b uvu";

    println!("Parsing input: '{}'", input_string);

    // Instantiate the parser
    let tables_buf = include_bytes!(concat!(env!("OUT_DIR"), "/my_grammar.g.d_parser.bin"));

    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        { Parser::new(tables_buf, Some(dispatch_action)).unwrap() };
    parser.set_save_parse_tree(true);
    let mut initial_globals = GlobalsStruct { a: 0, b: 0 };
    let result: Option<ParseNodeWrapper<'_, Parser<GlobalsStruct, NodeStruct>>> =
        parser.parse(input_string, &mut initial_globals);

    // Process the result
    unsafe {
        match result {
            Some(root_node) => {
                println!("Parsing successful!");
                if root_node.node.is_null() {
                    println!("Root node is null.");
                } else {
                    println!(
                        "Root node x {}",
                        d_user::<NodeStruct>(root_node.node.as_mut().unwrap()).x
                    );
                }
            }
            None => {
                eprintln!("Parsing failed.");
            }
        }
    }
}
