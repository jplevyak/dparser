use dparser_lib::{D_ParserTables, ParseNodeWrapper, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

extern "C" {
    static mut parser_tables_gram: D_ParserTables;
}

fn main() {
    let input_string = "a x  b";

    println!("Parsing input: '{}'", input_string);

    // Instantiate the parser
    let parser: Parser<GrammarActions, NodeData> = unsafe {
        // Get a mutable pointer to the C parser tables
        let tables_ptr = &mut parser_tables_gram as *mut D_ParserTables;
        // Create the parser instance using the C tables
        Parser::new(tables_ptr) // `new` itself is marked unsafe
    };

    let result: Option<ParseNodeWrapper<'_, Parser<GrammarActions, NodeData>>> =
        parser.parse(input_string);

    // Process the result
    match result {
        Some(root_node) => {
            println!("Parsing successful!");
            println!("Root node '{:?}'", root_node.str());
            println!("Root node x {}", d_user<NodeStruct>(root_node.node).x);
        }
        None => {
            eprintln!("Parsing failed.");
        }
    }
}
