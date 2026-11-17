// Threaded state through the C++ wrapper: dparser::Parser::set_state<T>,
// dparser::make_state and ParseNode::state<T>.
#include "dparse.hpp"
#include <iostream>

extern "C" {
extern struct D_ParserTables parser_tables_cpp_state;
}

std::string cpp_state_trace;

struct PreferLarger {
    int operator()(const int& a, const int& b) const { return a - b; }
};

static void quiet(D_Parser*) {}

static int failed = 0;

static void expect(const char* name, bool ok) {
    std::cout << name << (ok ? " ok" : " FAILED") << std::endl;
    if (!ok) failed++;
}

static bool parses(const char* text, bool prefer = false) {
    cpp_state_trace.clear();
    dparser::Parser parser(&parser_tables_cpp_state);
    parser.set_syntax_error_fn(quiet);
    if (prefer)
        parser.set_state<int, PreferLarger>(0);
    else
        parser.set_state<int>(0);
    auto tree = parser.parse(std::string_view(text));
    bool ok = tree && parser.syntax_errors() == 0;
    if (ok && std::string_view(text) == "while x") {
        const int* end = tree.root().state<int>();
        expect("final state is 0", end && *end == 0);
    }
    return ok;
}

int main() {
    expect("while break", parses("while break"));
    expect("break outside a loop", !parses("break"));
    expect("while x break", !parses("while x break"));
    expect("while while break", parses("while while break"));
    expect("while while break break", !parses("while while break break"));
    expect("while x", parses("while x"));
    expect("prefer picks the larger state", parses("b c", true) && cpp_state_trace == "two");
    if (failed) return 1;
    std::cout << "all C++ threaded state tests passed" << std::endl;
    return 0;
}
