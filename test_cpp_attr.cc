// Attributes after parsing through the C++ wrapper (dattr.hpp), on the typed
// language of test_attr.g: env is inherited, type is synthesized.
#include "dattr.hpp"

#include <iostream>
#include <map>
#include <memory>
#include <string>

extern "C" {
extern struct D_ParserTables parser_tables_attr;
}
#include "test_attr.g.d_parser.h"

using Env = std::shared_ptr<const std::map<std::string, std::string>>;

static int failed = 0;

static void expect(const char* name, bool ok) {
    std::cout << name << (ok ? " ok" : " FAILED") << std::endl;
    if (!ok) failed++;
}

static void collect_decls(dparser::AttrNode n, std::map<std::string, std::string>& vars) {
    if (n.symbol_name() == "block") return;
    if (n.symbol_name() == "decl") {
        vars[std::string(n.child(1).text())] = std::string(n.child(3).text());
        return;
    }
    for (size_t i = 0; i < n.num_children(); i++) collect_decls(n.child(i), vars);
}

int main() {
    dparser::Parser parser(&parser_tables_attr);
    auto tree = parser.parse(std::string_view("{ var x : int; x + 1; { var b : bool; b == x; b; } y; }"));
    expect("parses", tree && parser.syntax_errors() == 0);

    dparser::Attr<Env> env = dparser::inh<Env>("env", [&](dparser::AttrNode n, int child) -> std::optional<Env> {
        if (child < 0) return std::make_shared<const std::map<std::string, std::string>>();
        if (n.symbol_name() != "block") return std::nullopt;  // copy down
        auto vars = **env.get(n);
        for (size_t i = 0; i < n.num_children(); i++) collect_decls(n.child(i), vars);
        return std::make_shared<const std::map<std::string, std::string>>(std::move(vars));
    });

    dparser::Attr<std::string> type =
        dparser::syn<std::string>("type", [&](dparser::AttrNode n, int) -> std::optional<std::string> {
            if (n.symbol_name() == "number") return "int";
            if (n.symbol_name() == "name") {
                const Env& e = *env.get(n);
                auto it = e->find(std::string(n.text()));
                return it == e->end() ? "undefined" : it->second;
            }
            if (n.symbol_name() != "expr") return std::nullopt;
            int p = n.production();
            if (p == D_RULE_expr_0 || p == D_RULE_expr_1) {
                const std::string &a = *type(n.child(0)), &b = *type(n.child(2));
                if (p == D_RULE_expr_0) return a == "int" && b == "int" ? "int" : "error";
                return a == b ? "bool" : "error";
            }
            dparser::AttrNode c = n.child(0);
            return c.symbol_name() == "name" || c.symbol_name() == "number" ? *type(c) : "bool";
        });

    dparser::AttrTree attrs(parser, tree, env, type);
    std::string types;
    std::function<void(dparser::AttrNode)> walk = [&](dparser::AttrNode n) {
        if (n.symbol_name() == "stmt" && n.child(0).symbol_name() == "expr")
            types += (types.empty() ? "" : " ") + *type(n.child(0));
        for (size_t i = 0; i < n.num_children(); i++) walk(n.child(i));
    };
    walk(attrs.root());
    expect("types", types == "int error bool undefined");
    if (types != "int error bool undefined") std::cout << "  got: " << types << std::endl;
    expect("undefined synthesized attribute is nullptr", type(attrs.root()) == nullptr);
    expect("no cycles", attrs.cycles() == 0);

    if (failed) return 1;
    std::cout << "all C++ attribute tests passed" << std::endl;
    return 0;
}
