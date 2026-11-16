# C++ Wrapper

`dparse.hpp` is a header-only C++17 wrapper around the C API, in namespace
`dparser`. It provides RAII ownership of the parser and tree, and
iterators over children. `make install` installs it alongside `dparse.h`.

## Example

Grammar `words.g`, with actions written in C++:

```cpp
{
#include "dparse.hpp"
#include <iostream>
}

list: word+ { std::cout << $#0 << " words, first is " << $c0.child(0).text() << "\n"; } ;
word: "[a-z]+" ;
```

Driver `main.cc`:

```cpp
#include "dparse.hpp"
#include <iostream>

extern "C" D_ParserTables parser_tables_gram;

int main() {
  dparser::Parser parser(&parser_tables_gram);
  parser.set_loc("<input>");
  auto tree = parser.parse(std::string_view("alpha beta gamma"));
  if (!tree || parser.syntax_errors()) return 1;
  for (auto w : tree.root().child(0).children())
    std::cout << w.text() << "\n";
  return 0;
}
```

Build. The generated file has a `.c` name but must be compiled as C++
because its actions are C++; alternatively generate it with
`make_dparser -X cpp`.

```bash
make_dparser words.g
g++ -std=c++17 -x c++ -c words.g.d_parser.c -o words.o
g++ -std=c++17 main.cc words.o -ldparse -o words
```

```console
$ ./words
3 words, first is alpha
alpha
beta
gamma
```

## `dparser::Parser`

Owns a `D_Parser`. Move-only. Unlike the C API, the wrapper keeps the
parse tree by default (`save_parse_tree` is on).

| Member | Description |
|---|---|
| `Parser(D_ParserTables *tables, int sizeof_user = 0)` | Create a parser. Throws `std::runtime_error` on failure. |
| `ParseTree parse(std::string_view)`, `parse(const std::string &)`, `parse(const char *, int)` | Parse a buffer. The buffer must outlive the tree. |
| `void set_save_parse_tree(bool)` | Whether to keep the tree (default `true`). With `false`, final actions still run but `ParseTree` holds no tree. |
| `void set_loc(const char *pathname, int line = 1, int col = 0)` | Set the starting location and file name. |
| `void set_syntax_error_fn(D_SyntaxErrorFn)` | Install a syntax error callback. |
| `void set_ambiguity_fn(D_AmbiguityFn)` | Install an ambiguity callback. |
| `int syntax_errors() const` | The number of syntax errors. |
| `D_Parser *c_parser() const` | The underlying C parser, for options without a wrapper. |

## `dparser::ParseTree`

Owns the tree returned by a parse, and frees it when destroyed. Move-only.
It must not outlive the `Parser` that produced it. Converts to `bool`:
false if the parse failed.

| Member | Description |
|---|---|
| `bool has_tree() const` | True if the parse succeeded and the tree was kept. |
| `ParseNode root() const` | The root node, or an invalid node if no tree was kept. |
| `D_ParseNode *c_root() const` | The underlying C node, or `nullptr`. |

## `dparser::ParseNode`

A lightweight, non-owning view of a `D_ParseNode`.

| Member | Description |
|---|---|
| `int symbol() const` | The node's symbol number. |
| `std::string_view text() const` | The node's text. |
| `std::string_view text_skip() const` | The text including trailing whitespace. |
| `template <class T> T *user_data() const` | A pointer to the node's user data as `T`. |
| `size_t num_children() const` | The number of children. |
| `ParseNode child(size_t i) const` | Child `i`. |
| `children() const` | A range for `for (auto c : node.children())`. |
| `std::optional<ParseNode> find_in_tree(int symbol) const` | Depth-first search for a symbol. |
| `D_ParseNode *c_node() const` | The underlying C node. |

## In actions

In grammar actions, `$c0`, `$c1`, ... are `dparser::ParseNode` views of the
rule's elements, and `$c` is the node being built. See
[Actions](actions.md#node-data).
