# Rust

The `dparser` crate in the `rust/` directory is a native Rust
implementation of the DParser runtime: a port of the C parsing engine,
with actions written in Rust. Grammars are still compiled by
`make_dparser`, which the crate builds for you.

The Rust runtime parses exactly as the C runtime does. It gives the same
parse trees, ambiguity resolution, error recovery, and even the same
statistics on the C test suite (see [Testing](#testing)).

The [Rust tutorial](../tutorial/rust.md) builds a parser step by step.

!!! note
    The Rust runtime's API may still change.

## How it fits together

1. **At build time**, your `build.rs` runs `make_dparser` with `-B` (binary
   tables) and `-a` (write the actions to a separate file). It then calls
   `dparser::build_actions`, which turns those actions into Rust code,
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
`build.rs`. The node type must implement `Default` and `Clone`.

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

All three kinds of action work as in C: speculative `[ ]`, final `{ }`,
and pass code (`name: { }`, see [Passes](#passes)). Default actions on the
`_` production apply to every rule without its own. As in C, `${...}`
escapes are expanded in global code too, so don't write them in comments
there.

### Specifiers

An action is the body of a function that receives the node being built,
`_ps`, whose `children` are the rule's elements.

| Specifier | Rust | Meaning |
|---|---|---|
| `$$` | `_ps.user` | Your data for the node being built. |
| `$0`, `$1`, ... | `_ps.children[N].user` | Your data for element *N*. |
| `$n` | `_ps` | The node being built (a `ParseNode`). |
| `$n0`, `$n1`, ... | `_ps.children[N]` | Element *N*. |
| `$n0*`, `$0*` | `&mut _ps.children[N].children` | The repetitions of a starred element (`for n in $n0* { ... }`). |
| `$#`, `$#0` | `_ps.children.len()`, ... | The number of elements, or of repetitions. |
| `${child 0, 2, 1}` | `_ps.children[0].children[2].children[1]` | A path into the tree. |
| `$g` | `&mut G`, or `&G` | The globals passed to `parse`. Read-only in speculative actions; see below. |
| `${scope}` | `_ps.scope` | The symbol table scope (a `ScopeId`). Speculative actions may assign it. |
| `${state}` | `_ps.state` | The [threaded state](#threaded-state) (a `StateId`). Speculative actions may assign it; elsewhere it is read-only. |
| `${state N}` | `_ps.children[N].state_before` | The threaded state before element *N*. |
| `${parser}` | `&mut Parser` | The parser, for example `${parser}.symtab`. |
| `${reject}` | `return -1` | In a speculative action, reject this parse path. |
| `${nterm name}`, `${string 'x'}` | an `i32` | The symbol number of a nonterminal or string. |
| `${pass name}` | a `usize` | A pass number, for `Parser::pass`. |

A `ParseNode` has `symbol`, `string` (the text, without trailing
whitespace), `end_skip_string` (the whitespace after it), `start_loc` (a
`Loc` with byte offset, line and column), `end`, `children`, `user`,
`scope`, `state`, `state_before` and `action_index`. `production()`
gives the rule that built the node, one of the `D_RULE_<production>_<n>`
constants generated by `build_actions` (see
[Attributes](attributes.md#which-rule-built-a-node)).

`dparser::attrs` evaluates synthesized and inherited attributes on a
parse tree; see [Attributes](attributes.md#rust-dparserattrs).

### Speculative actions and `$g`

Speculative actions run during parsing, possibly for parse paths that are
later abandoned. Anything they store in `$$` stays with the node; final
actions see it. Rejecting a path (`${reject}`, or returning nonzero)
removes it from the parse.

A speculative action's children have their data, but not their own
children. To look deeper, use `${parser}.find_in_tree(&$n0, symbol)` (the
first node with that symbol under `$n0`, as `d_find_in_tree`) or
`${parser}.children(&node)`. These see the whole derivation, without
copying it.

`$g` is `&G` in speculative actions, so they can't write to the globals: a
write wouldn't be undone if the parse path fails. Keep path-specific state
in [`${state}`](#threaded-state) instead, or add
[`${declare mutable_speculative_globals}`](declarations.md#mutable-speculative-globals)
to the grammar to make it `&mut G`.

### Symbol tables

`${parser}.symtab` is the [symbol table](symbol-table.md), a port of the C
one. Scopes and symbols are referred to by `ScopeId` and `SymId`, and each
symbol has a `u64` of user data:

```rust
typeID: ident [
  match ${parser}.symtab.find_sym(${scope}, $n0.string) {
    Some(s) if ${parser}.symtab.sym(s).user != 0 => {}
    _ => { ${reject}; }
  }
];

declaration: 'typedef' type ident ';' [
  let s = ${parser}.symtab.speculative_new_sym(&mut ${scope}, $n2.string);
  ${parser}.symtab.sym_mut(s).user = 1;
];
```

The methods correspond to the C functions: `new_scope` (`new_D_Scope`),
`enter_scope`, `global_scope`, `scope_scope`, `commit_scope`,
`equiv_scope`, `new_sym` (`NEW_D_SYM`), `speculative_new_sym`
(`SPECULATIVE_NEW_D_SYM`), `update_sym` (`UPDATE_D_SYM`),
`update_additional_sym`, `current_sym`, `find_sym`, `find_global_sym`,
`find_sym_in_scope` and `syms_in_scope`. As in C, the parser keeps parse
paths whose scopes differ apart.

A new symbol table is made for each parse, unless you set
`parser.initial_scope` (and `parser.symtab`) first.

### Threaded state

[Threaded state](threaded-state.md) values can be of any `Eq + Hash`
type. The parser interns them and actions handle them as `StateId`s
(`StateId::NONE` is no state). `${parser}.make_state(value)` returns the
id of a value, and `${parser}.state::<T>(id)` the value:

```rust
{
fn depth<G, N: Default + Clone>(p: &dparser::Parser<G, N>, s: dparser::StateId) -> i32 {
    p.state::<i32>(s).copied().unwrap_or(0)
}
}

stmt: 'while' enter stmt leave
    | 'break' [ if depth(${parser}, ${state}) == 0 { ${reject}; } ]
    | 'x' ;
enter: [ let d = depth(${parser}, ${state}); ${state} = ${parser}.make_state(d + 1); ] ;
leave: [ let d = depth(${parser}, ${state}); ${state} = ${parser}.make_state(d - 1); ] ;
```

`Parser::initial_state` is the state at the start, and
`Parser::prefer_state`, a `fn(&States, StateId, StateId) -> i32`, chooses
between parses that end with different states. Values live as long as the
parser (`Parser::states`). A whitespace function that needs the state is
set as `white_space_state_fn` (see below).

### Passes

```rust
${pass sym for_all postorder}

statement: expression ';' {
  ${parser}.pass_with_globals($n, ${pass sym}, $g);
};

expression: integer
  sym: { $g.out.push(format!("integer {}", $n.string)); }
  ;
```

`Parser::pass(&mut node, pass_number)` runs a pass over a tree, and
`pass_with_globals` makes the globals available to its actions.
`Parser::pass_number(name)` finds a pass by name.

### External scanners and whitespace functions

`${scan f}` terminals, a `${scanner f}` tokenizer and
`${declare whitespace f}` work with Rust functions. Create the parser with
`Parser::with_actions(tables, actions())`, which passes them in
(`actions()` is generated along with `dispatch_action`). The functions
have these signatures:

```rust
// ${scan f}, or ${scan f(a, b)}, which calls f(a, b, input, loc, ...)
fn f(input: &[u8], loc: &mut dparser::Loc, op_assoc: &mut u8, op_priority: &mut i32) -> i32;

// ${scanner f}; ${token A B} names are generated as u16 constants
fn f(input: &[u8], loc: &mut dparser::Loc, symbol: &mut u16, term_priority: &mut i32,
     op_assoc: &mut u8, op_priority: &mut i32) -> i32;

// ${declare whitespace f}
fn f(input: &[u8], loc: &mut dparser::Loc, globals: Option<&mut GlobalsStruct>);

// Parser::white_space_state_fn: also reads the threaded state
fn f(input: &[u8], loc: &mut dparser::Loc, globals: Option<&mut GlobalsStruct>,
     states: &dparser::States, state: dparser::StateId);
```

A scanner that matches advances `loc.s` and returns nonzero.
`dparser::grammar::D_ASSOC_*` are the values for `op_assoc`.

## Parsing

```rust
use dparser::{ParseNode, Parser};

include!(concat!(env!("OUT_DIR"), "/actions.rs"));

fn main() {
    let tables = include_bytes!(concat!(env!("OUT_DIR"), "/my_grammar.g.d_parser.bin"));
    let mut parser: Parser<GlobalsStruct, NodeStruct> =
        Parser::with_actions(tables, actions()).unwrap();
    parser.set_save_parse_tree(true);
    parser.set_loc("input.txt", 1);

    let mut globals = GlobalsStruct::default();
    let result: Option<ParseNode<'_, NodeStruct>> =
        parser.parse("a x b uvu", Some(&mut globals));

    match result {
        Some(root) if parser.syntax_errors == 0 => println!("parsed, x = {}", root.user.x),
        Some(_) => eprintln!("{} syntax errors (recovered)", parser.syntax_errors),
        None => eprintln!("parse failed at line {}", parser.loc.line),
    }
}
```

`Parser::new(tables, Some(dispatch_action))` also works for grammars
without external scanners or a whitespace function.

`parse` returns `None` if the input could not be parsed. Syntax errors are
reported on stderr as `file:line: syntax error after '...'`; set
`syntax_error_fn` to handle them yourself. If error recovery succeeds, a
tree is returned and `syntax_errors` is nonzero. Trailing NUL characters
in the input are ignored.

### Options

`Parser` has the same options as the [C parser](c-api.md#options):

| Field | Default | Meaning |
|---|---|---|
| `save_parse_tree` | from the grammar | Keep the tree. Without it, final actions still run, but nodes drop their children once their actions have run. |
| `start_state` | `0` | The state to start in. `set_start_symbol(name)` sets it for a nonterminal with `${declare subparser name}`. |
| `partial_parses` | `false` | Accept a parse of a prefix of the input. |
| `error_recovery` | `true` | Recover from syntax errors using the grammar's error recovery hints. |
| `commit_actions_interval` | `100` | Run final actions once the parse has been unambiguous for this many shifts. |
| `dont_fixup_internal_productions` | `false` | Keep the nodes for `*`, `+` and groups. |
| `fixup_ebnf_productions` | `false` | Also splice EBNF nodes into their parents. |
| `dont_compare_stacks`, `dont_merge_epsilon_trees` | `false` | As in C. |
| `dont_use_greediness_for_disambiguation`, `dont_use_height_for_disambiguation`, `dont_use_deep_priorities_for_disambiguation` | `false` | Turn off disambiguation rules. |
| `syntax_error_fn` | report on stderr | Called on each syntax error, with `loc` set. |
| `ambiguity_fn` | report and fail | Chooses among ambiguous parses. `dparser::resolve_amb_greedy` chooses as C's `resolve_amb_greedy`. |
| `white_space_fn` | the default | Replaces whitespace handling. |
| `white_space_state_fn` | `None` | Replaces whitespace handling with a function that also reads the [threaded state](#threaded-state); used instead of `white_space_fn` when set. |
| `initial_state`, `prefer_state` | `StateId::NONE`, `None` | The [threaded state](#threaded-state) at the start, and the preference between final states. |
| `pathname`, `start_line` | | The file name and first line, for locations and messages (`set_loc`). |

After a parse, `loc` is the location of the last syntax error,
`syntax_errors` is their number, and `stats` has the parse statistics.

An `ambiguity_fn` receives the alternatives as trees whose final actions
have not run. It returns the index of the one to keep; only that one's
final actions then run.

## Complete example

A complete, buildable example is in
[`rust/example`](https://github.com/jplevyak/dparser/tree/main/rust/example).
Run it with:

```bash
cd rust
cargo run -p example
```

## Testing

```bash
cd rust
cargo test --workspace
python3 conformance/run.py
```

`rust/integration_tests` ports grammars from the C test suite whose
actions matter, such as the symbol table, passes, external scanners and the
Python and C grammars. Their output must match the C runtime's expected
output exactly. `conformance/run.py` parses every input of the C test
suite with the Rust runtime and compares the trees, statistics and syntax
errors with the C results.
