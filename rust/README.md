# DParser for Rust

A native Rust runtime for [DParser](https://github.com/jplevyak/dparser), the
scannerless GLR parser generator.

Grammars are compiled by DParser's `make_dparser` (built by this crate) into
binary tables, and their actions, written in Rust, are compiled into your
crate. The runtime is a port of the C parsing engine and parses exactly as it
does: the same trees, disambiguation, error recovery and statistics on the C
test suite. It supports speculative and final actions, passes, the symbol
table, external scanners and whitespace functions, and all of the C parser's
options.

## Usage

`build.rs`:

```rust
use std::{env, path::PathBuf, process::Command};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=src/my_grammar.g");
    let out = PathBuf::from(env::var("OUT_DIR")?);
    let grammar = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?).join("src/my_grammar.g");
    let make_dparser = PathBuf::from(env::var("DEP_DPARSE_BINARY_PATH")?);
    let status = Command::new(make_dparser)
        .arg(&grammar)
        .args(["-B", "-X", "bin", "-o"]).arg(out.join("my_grammar.g.d_parser.bin"))
        .arg("-a").arg(out.join("my_grammar.actions"))
        .status()?;
    if !status.success() {
        return Err("make_dparser failed".into());
    }
    dparser::build_actions(&out.join("my_grammar.actions"), &out.join("actions.rs"),
                           "GlobalsStruct", "NodeStruct")?;
    Ok(())
}
```

`src/my_grammar.g`:

```rust
{
#[derive(Debug, Default)]
pub struct GlobalsStruct { pub sum: i64 }

#[derive(Debug, Default, Clone)]
pub struct NodeStruct { pub value: i64 }
}

list: number+ { for n in $n0* { $g.sum += n.user.value; } };
number: "[0-9]+" { $$.value = $n0.string.parse().unwrap(); };
```

`src/main.rs`:

```rust
use dparser::Parser;

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

fn main() {
    let tables = include_bytes!(concat!(env!("OUT_DIR"), "/my_grammar.g.d_parser.bin"));
    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        Parser::with_actions(tables, actions()).unwrap();
    let mut globals = GlobalsStruct::default();
    match parser.parse("1 2 3", Some(&mut globals)) {
        Some(_) => println!("sum = {}", globals.sum),
        None => eprintln!("syntax error at line {}", parser.loc.line),
    }
}
```

See the [Rust documentation](https://jplevyak.github.io/dparser/reference/rust/)
for the action specifiers, speculative actions, the symbol table, passes,
external scanners and the parser options, and `example/` for a complete crate.

## Testing

```bash
cargo test --workspace      # unit tests, and C test grammars ported to Rust actions
python3 conformance/run.py  # every input of the C test suite, compared with the C results
```
