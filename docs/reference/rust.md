# Rust

The `dparser` crate in the `rust/` directory is a native Rust
implementation of the DParser runtime. Grammars are still compiled by
`make_dparser`, which the crate builds for you. Your actions are written
in Rust, in the same `.g` grammar syntax, and are compiled into your crate.

!!! note
    The Rust runtime is newer than the C runtime. Its API may change.

## How it fits together

1. **At build time**, your `build.rs` runs `make_dparser` with `-B` (binary
   tables) and `-a` (write the actions to a separate file). It then calls
   `dparser::build_actions` to turn those actions into Rust code,
   `actions.rs`, in `OUT_DIR`.
2. **In your crate**, you `include!` the generated `actions.rs`, embed the
   binary tables with `include_bytes!`, and create a `dparser::Parser`.

## Cargo setup

```toml
[dependencies]
dparser = { git = "https://github.com/jplevyak/dparser" }

[build-dependencies]
dparser = { git = "https://github.com/jplevyak/dparser" }
```

The crate's build script compiles the C `make_dparser` tool and exposes
its path to dependent build scripts as `DEP_DPARSE_BINARY_PATH`.

## `build.rs`

```rust
use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=src/my_grammar.g");

    let out_dir = PathBuf::from(env::var("OUT_DIR")?);
    let grammar = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?)
        .join("src").join("my_grammar.g");
    let tables = out_dir.join("my_grammar.g.d_parser.bin");
    let actions = out_dir.join("my_grammar.actions");

    let make_dparser = PathBuf::from(env::var("DEP_DPARSE_BINARY_PATH")?);
    let status = Command::new(&make_dparser)
        .arg(&grammar)
        .args(["-B", "-X", "bin", "-o"]).arg(&tables)
        .arg("-a").arg(&actions)
        .status()?;
    if !status.success() {
        return Err("make_dparser failed".into());
    }

    // Generate actions.rs; the last two arguments name your global and node types.
    dparser::build_actions(&actions, &out_dir.join("actions.rs"),
                           "GlobalsStruct", "NodeStruct")?;
    Ok(())
}
```

## The grammar

Global code is Rust. It must define the global and node types you named in
`build.rs`; the node type must implement `Default` and `Clone`.

```rust
{
#[derive(Debug, Default)]
pub struct GlobalsStruct {
  count: i32,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
  x: i32,
}
}

start: S T {
  println!("start: count {} x {}", $g.count, $0.x);
  $$ = $0.clone();
};

S: A S 'b' { $$ = $1.clone(); $$.x = $0.x + $1.x; $g.count += 1; }
 | X       { $$ = $0.clone(); };

A: 'a' { $$.x = 1; };
X: 'x' { $$.x = 10; };

T: U* {
  for n in $n0* {
    print!("({})", n.string);
  }
  println!();
};

U: 'u' | 'v';
```

The specifiers have the same meaning as in C: `$$` and `$0`, `$1`, ...
are node values, `$n0`, ... are nodes (with `start_loc`, `string`, and
so on), and `$g` is the global state. `for n in $n0* { ... }` iterates
over the repetitions of a starred element.

## Parsing

```rust
use dparser::{types::ParseNode, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

fn main() {
    let tables = include_bytes!(concat!(env!("OUT_DIR"), "/my_grammar.g.d_parser.bin"));
    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        Parser::new(tables, Some(dispatch_action)).unwrap();
    parser.set_save_parse_tree(true);

    let mut globals = GlobalsStruct::default();
    let result: Option<ParseNode<'_, NodeStruct>> =
        parser.parse("a x b uvu", Some(&mut globals));

    match result {
        Some(root) => println!("parsed, x = {}", root.user.x),
        None => eprintln!("parse failed"),
    }
}
```

`dispatch_action` is generated in `actions.rs`. `Parser` also has public
`syntax_error_fn` and `ambiguity_fn` fields for callbacks, and
`dont_fixup_internal_productions` and `fixup_ebnf_productions` fields with
the same meaning as the [C options](c-api.md#options).

As in C, a node's `string` is its text without trailing whitespace, and a
repeated element such as `$n0` for `U*` has one child per repetition.

## Complete example

A complete, buildable example is in
[`rust/example`](https://github.com/jplevyak/dparser/tree/main/rust/example).
Run it with:

```bash
cd rust
cargo run -p example
```

More grammars are in `rust/integration_tests`.
