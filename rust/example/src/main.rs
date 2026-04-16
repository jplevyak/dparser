use dparser_lib::{types::ParseNode, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

fn main() {
    let input_string = "a x  b uvu\0";

    println!("Parsing input: '{}'", input_string);

    // Instantiate the parser
    let tables_buf = include_bytes!(concat!(env!("OUT_DIR"), "/my_grammar.g.d_parser.bin"));

    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        { Parser::new(tables_buf, Some(dispatch_action)).unwrap() };
    parser.set_save_parse_tree(true);
    let mut initial_globals = GlobalsStruct { a: 0, b: 0 };
    let result: Option<ParseNode<'_, NodeStruct>> =
        parser.parse(input_string, Some(&mut initial_globals));

    // Process the result
    match result {
        Some(root_node) => {
            println!("Parsing successful!");
            println!("Root node x {}", root_node.user.x);
        }
        None => {
            eprintln!("Parsing failed.");
        }
    }
}
