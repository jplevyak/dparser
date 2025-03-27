use dparser_lib::{D_ParserTables, ParseNodeWrapper, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

unsafe extern "C" {
    unsafe static mut parser_tables_gram: D_ParserTables;
}

fn main() {
    let input_string = "a x  b";

    println!("Parsing input: '{}'", input_string);

    // Instantiate the parser
    let parser: Parser<GlobalsStruct, NodeStruct> = { Parser::new(&raw mut parser_tables_gram) };

    let result: Option<ParseNodeWrapper<'_, Parser<GlobalsStruct, NodeStruct>>> =
        parser.parse(input_string);

    // Process the result
    unsafe {
        match result {
            Some(root_node) => {
                println!("Parsing successful!");
                println!("Root node '{:?}'", root_node.node.as_ref().unwrap().str());
                println!(
                    "Root node x {}",
                    d_user::<NodeStruct>(root_node.node.as_mut().unwrap())
                        .as_ref()
                        .unwrap()
                        .x
                );
            }
            None => {
                eprintln!("Parsing failed.");
            }
        }
    }
}
