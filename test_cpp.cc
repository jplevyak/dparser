// test_cpp.cc
#include "dparse.hpp"
#include <iostream>
#include <cassert>

#define SIZEOF_MY_PARSE_NODE 100

extern "C" {
    extern struct D_ParserTables parser_tables_gram;
}

int main(int argc, char* argv[]) {
    std::cout << "Testing C++ wrapper..." << std::endl;
    // We instantiate the wrapper
    dparser::Parser parser(&parser_tables_gram, SIZEOF_MY_PARSE_NODE);
    parser.set_save_parse_tree(true);
    parser.set_loc("<string>");
    
    // sample.g grammar expects standard C-like types or definition syntax.
    // e.g. "x : 10;"
    std::string_view code = "x : 10;"; 
    
    auto tree = parser.parse(code);
    if (tree) {
        std::cout << "Parse successful!" << std::endl;
        std::cout << "Syntax errors: " << parser.syntax_errors() << std::endl;
        
        dparser::ParseNode root = tree.root();
        std::cout << "Root node valid: " << (root.is_valid() ? "yes" : "no") << std::endl;
        std::cout << "Root node symbol: " << root.symbol() << std::endl;
        std::cout << "Root node text: " << root.text() << std::endl;
        std::cout << "Number of children: " << root.num_children() << std::endl;

        for (auto child : root.children()) {
            std::cout << "Child text: " << child.text() << std::endl;
        }

    } else {
        std::cout << "Parse failed completely." << std::endl;
        return 1;
    }
    
    return parser.syntax_errors() > 0 ? 1 : 0;
}
