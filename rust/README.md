# DParser for Rust

A **100% pure, native Rust** implementation of the [DParser](https://github.com/jplevyak/dparser) GLR (Generalized Left-to-Right Rightmost derivation) parser.

This crate provides a scannerless GLR parser generator and runtime runtime entirely decoupled from the original C runtime dependencies. It guarantees complete memory safety, leveraging native Rust memory constructs, slices, and arena allocation for parse tree execution instead of raw pointers.

## Features at a Glance
- **Pure Rust Runtime**: Eliminates the need for traditional FFI bindings and C-extensions. Generates cross-platform, warning-free syntax matching seamlessly.
- **Embedded Static Grammar**: Safely embeds statically compiled parser properties directly into your compiled binaries using `binrw`, bypassing dynamic linkage errors.
- **Arena-Backed AST Trees**: Dynamically builds high-performance syntax trees (PNode, SNode, ZNode abstractions) structurally bounded correctly without heap thrashing or dangling pointers.
- **Dynamic Syntax Dispatching**: Automatically structures reduction closures (`$$`, `$1`, `$g`) through idiomatic generic macros avoiding `unsafe` boundaries.
- **Zero-Copy Scanning**: Maps characters and whitespaces purely sequentially over the original `&str`/`&[u8]` buffers natively avoiding extra redundant string allocation dynamically.

## Quick Start & Usage

This library seamlessly splits grammar initialization bounds and parsing logic via `build.rs` processing. 
Here is an example setup leveraging global contexts, structural nodes, and custom structural behaviors directly in pure Rust via your custom `<grammar>.g` configuration.

### 1. Define your grammar mappings in `my_grammar.g`
```rust
{
// Natively inject context imports for dynamically evaluated elements 
use dparser_lib;

#[derive(Debug, Default)]
pub struct GlobalsStruct {
    a: i32,
    b: i32,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {
    pub x: i32,
    pub y: i32,
}
}

// Map root reduction rules cleanly interacting with states:
start: S T {
    println!("start globally evaluated: a={}, x={}", $g.a, $0.x);
    $$ = $0.clone();
};

S: A S 'b' 
{
    // Modify dynamic node tree recursively
    $$ = $1.clone();
    $$.x = $0.x + $1.x;
    $g.a += 10;
}
 | X
{
    $$ = $0.clone();
};

A: 'a' { $$.x = 1; };
X: 'x' { $$.x = 10; };

T: U* {
    // Navigate iteration sequences implicitly safely
    for n in $n0* {
        print!("({})", n.string);
    }
};

U: 'u' | 'v';
```

### 2. Configure `build.rs` to pre-generate mappings
Use the bundled builder to precompile configurations cleanly via `make_dparser` producing binaries native bindings statically load safely:
```rust
use std::env;
use std::path::PathBuf;

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Execute standard DParser compiler bridging
    let _ = std::process::Command::new("../../make_dparser")
        .args(&["-B", "-o", out_dir.to_str().unwrap(), "src/my_grammar.g"])
        .status()
        .unwrap();

    // Map the built C-macro string replacements native to Rust!
    dparser_lib::builder::build_actions(
        &PathBuf::from("src/my_grammar.g"),
        &out_dir.join("actions.rs"),
        "GlobalsStruct",
        "NodeStruct",
    ).expect("Failed mapping actions");
}
```

### 3. Parse Execution locally! (`main.rs`)

```rust
// include natively exported structures from the .g grammar file seamlessly
include!(concat!(env!("OUT_DIR"), "/actions.rs"));

fn main() {
    let input = "a x  b uvu\0"; // Requires explicit EOF terminator dynamically

    let binary_data = include_bytes!(concat!(env!("OUT_DIR"), "/my_grammar.g.d_parser.bin"));
    
    // Instantiates parsing structural trees statically
    let mut globals = GlobalsStruct::default();
    let mut parser = dparser_lib::Parser::new(
        binary_data, 
        dispatch_action, // Passes static pointer maps securely
    );

    // Dynamic execution! 
    let parse_tree = parser.parse(input, Some(&mut globals));

    match parse_tree {
        Some(tree) => println!("Parsing successful: {:?}", tree.user),
        None => println!("Parsing failed dynamically."),
    }
}
```

## Internal Architecture
- `dparser_lib/src/binary_format.rs`: Maps pure struct padding sizes corresponding functionally identical to the generic compiler definitions securely without invoking C APIs!
- `dparser_lib/src/parse.rs`: Houses the primary Tomita scanning loop iterating sequential mapping across boundaries cleanly.
- `dparser_lib/src/scan.rs`: Defines character block bitmapping DFA traversal.
- `dparser_lib/src/builder.rs`: Manages native Rust variable binding macro swaps natively formatting string elements mapped reliably matching `$X` inputs cleanly via slice indexing.
