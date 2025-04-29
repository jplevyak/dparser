use dparser_lib::{D_ParserTables, ParseNodeWrapper, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

unsafe extern "C" {
    unsafe static mut parser_tables_gram: D_ParserTables;
}

fn main() {
    let input_string = "a x  b uvu";

    println!("Parsing input: '{}'", input_string);

    // Instantiate the parser
    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        { Parser::new(&raw mut parser_tables_gram) };
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
