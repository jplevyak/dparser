#include "dparse.hpp"
#include <iostream>

extern "C" {
    extern struct D_ParserTables parser_tables_gram;
}

int main(int argc, char* argv[]) {
    std::cout << "Testing C++ grammar actions..." << std::endl;
    dparser::Parser parser(&parser_tables_gram, 0);
    parser.set_save_parse_tree(true);
    
    std::string_view code = "a b";
    auto tree = parser.parse(code);
    if (!tree) {
        std::cout << "Parse failed completely." << std::endl;
        return 1;
    }
    if (parser.syntax_errors() > 0) {
        std::cout << "Parse had syntax errors." << std::endl;
        return 1;
    }
    
    std::cout << "Parse successful with C++ actions!" << std::endl;
    return 0;
}
