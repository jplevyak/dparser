# Internals

These pages describe how DParser works inside: how the tables are built
and how the runtime uses them. You don't need any of this to use DParser,
but it helps when tuning a grammar, debugging surprising behavior, or
working on DParser itself.

## Architecture

``` mermaid
flowchart TB
  subgraph gen ["make_dparser (build time)"]
    direction LR
    A["grammar.g"] --> B["grammar reader<br/>grammar.g.c, gram.c"]
    B --> C["LR(0) states<br/>lr.c"]
    C --> D["per-state scanners<br/>lex.c"]
    D --> E["table writer<br/>write_tables.c"]
  end
  subgraph run ["libdparse (run time)"]
    direction LR
    F["GLR driver<br/>parse.c"] <--> G["scanner<br/>scan.c"]
    F --> H["actions, trees,<br/>disambiguation"]
    F <--> I["symbol table<br/>dsymtab.c"]
  end
  gen -->|"C tables or binary tables"| run
```

## Source map

| File | Role |
|---|---|
| `make_dparser.c` | The command-line tool: options, then calls `mkdparse`. |
| `mkdparse.c` | Drives table construction. |
| `grammar.g`, `grammar.g.c` | The grammar of grammars, and the parser generated from it (DParser is self-hosting). |
| `gram.c`, `gram.h` | The grammar data structures: productions, rules, elements, terminals. Expands EBNF into internal productions. |
| `lr.c` | Builds the LR(0) item sets, the actions and the hints used at run time. |
| `lex.c` | Builds a scanner (DFA) for each parse state. |
| `write_tables.c` | Writes the tables and actions as C or binary. |
| `dparse_tables.h` | The table format shared by generator and runtime. |
| `parse.c`, `parse.h` | The GLR runtime. |
| `scan.c` | Runs the per-state scanners. |
| `dsymtab.c` | The speculative symbol table. |
| `read_binary.c` | Loads binary tables. |
| `arg.c`, `util.c` | Argument parsing, vectors, hash sets and other utilities. |

## Pages

- **[Table Construction](tables.md)**: from grammar to LR(0) states,
  EBNF expansion, and the hints computed for the runtime.
- **[Scanning](scanning.md)**: per-state scanners, terminal priorities,
  longest match and trailing context.
- **[The GLR Runtime](glr.md)**: the graph-structured stack, the main
  loop, shifts and reductions, and node sharing.
- **[Disambiguation](disambiguation.md)**: priority checks while parsing,
  comparing ambiguous nodes, and stack pruning.
- **[Actions and Commit](actions.md)**: when speculative and final actions
  run, and how the tree is committed.
- **[Symbol Table](symbol-table.md)**: how scopes and symbol versions give
  each parse path its own view.
- **[Error Recovery](error-recovery.md)**: recovery hints and epsilon
  hints.
- **[Binary Tables](binary-tables.md)**: the relocatable table format used
  by the Python and Rust bindings.
