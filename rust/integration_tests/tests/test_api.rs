//! The Parser API: options and hooks not covered by the C test suite.

use dparser::{Loc, Parser};
use integration_tests::print_paren;
use std::sync::atomic::{AtomicUsize, Ordering};

include!(concat!(env!("OUT_DIR"), "/api_actions.rs"));
const TABLES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/api.g.d_parser.bin"));

fn parser() -> Parser<GlobalsStruct, NodeStruct> {
    let mut p = Parser::new(TABLES, Some(dispatch_action)).unwrap();
    p.save_parse_tree = true;
    p
}

fn parse(p: &mut Parser<GlobalsStruct, NodeStruct>, input: &str) -> Option<String> {
    p.parse(input, Some(&mut GlobalsStruct::default())).map(|t| print_paren(&t))
}

const DANGLING_ELSE: &str = "if (a) if (b) x; else y;";

#[test]
fn greedy_disambiguation_attaches_else_to_the_inner_if() {
    let tree = parse(&mut parser(), DANGLING_ELSE).unwrap();
    // the inner if has the else
    assert_eq!(tree, "( if ( (  a  ) )( if ( (  b  ) )( x  ; ) else ( y  ; )))");
}

#[test]
fn resolve_amb_greedy_chooses_as_greedy_disambiguation_does() {
    let mut p = parser();
    p.dont_use_greediness_for_disambiguation = true;
    p.dont_use_height_for_disambiguation = true;
    p.ambiguity_fn = Some(dparser::resolve_amb_greedy);
    assert_eq!(parse(&mut p, DANGLING_ELSE), parse(&mut parser(), DANGLING_ELSE));
    assert!(p.stats.ambiguities > 0);
}

#[test]
fn unresolved_ambiguity_fails_the_parse() {
    let mut p = parser();
    p.dont_use_greediness_for_disambiguation = true;
    p.dont_use_height_for_disambiguation = true;
    assert!(parse(&mut p, DANGLING_ELSE).is_none());
}

#[test]
fn start_symbol_and_partial_parses() {
    let mut p = parser();
    p.set_start_symbol("stmt").unwrap();
    assert!(parse(&mut p, "x;").is_some());
    p.error_recovery = false;
    assert!(parse(&mut p, "x; y;").is_none());
    p.partial_parses = true;
    assert_eq!(parse(&mut p, "x; y;").unwrap(), "( x  ; )");
    assert!(p.set_start_symbol("cond").is_err()); // no start state
    assert!(p.set_start_symbol("nonsense").is_err());
}

static ERRORS: AtomicUsize = AtomicUsize::new(0);

#[test]
fn error_recovery_reports_and_continues() {
    fn on_error(p: &mut Parser<GlobalsStruct, NodeStruct>) {
        assert_eq!(p.loc.line, 2);
        ERRORS.fetch_add(1, Ordering::SeqCst);
    }
    let mut p = parser();
    p.syntax_error_fn = Some(on_error);
    let tree = parse(&mut p, "x;\nx 1;\ny;").expect("recovered");
    assert_eq!(p.syntax_errors, 1);
    assert_eq!(ERRORS.load(Ordering::SeqCst), 1);
    assert!(tree.contains(" y "), "{}", tree);
}

#[test]
fn white_space_function() {
    // '#' starts a comment to the end of the line
    fn ws(input: &[u8], loc: &mut Loc, _g: Option<&mut GlobalsStruct>) {
        while let Some(&c) = input.get(loc.s) {
            match c {
                b' ' | b'\t' => loc.s += 1,
                b'\n' => {
                    loc.s += 1;
                    loc.line += 1;
                }
                b'#' => {
                    while input.get(loc.s).is_some_and(|&c| c != b'\n') {
                        loc.s += 1;
                    }
                }
                _ => break,
            }
        }
    }
    let mut p = parser();
    p.error_recovery = false;
    p.syntax_error_fn = Some(|_| {});
    assert!(parse(&mut p, "x; # comment\ny;").is_none());
    p.white_space_fn = Some(ws);
    assert!(parse(&mut p, "x; # comment\ny;").is_some());
}

#[test]
fn find_in_tree_in_final_actions() {
    let mut p = parser();
    let mut g = GlobalsStruct::default();
    p.parse("{ if (c) { d; } e; }", Some(&mut g)).unwrap();
    // inner block first; each block finds its first name
    assert_eq!(g.found, vec!["d", "c"]);
}

#[test]
fn without_save_parse_tree_actions_run_but_children_are_dropped() {
    // As in C, once a node's final action has run its children are dropped,
    // so the block's action no longer sees the name inside `a;`.
    let mut p = parser();
    p.save_parse_tree = false;
    let mut g = GlobalsStruct::default();
    let root = p.parse("{ a; } { b; }", Some(&mut g)).unwrap();
    assert!(root.children.is_empty());
    assert!(g.found.is_empty());
    p.save_parse_tree = true;
    let mut g = GlobalsStruct::default();
    let root = p.parse("{ a; } { b; }", Some(&mut g)).unwrap();
    assert_eq!(root.children[0].children.len(), 2);
    assert_eq!(g.found, vec!["a", "b"]);
}

#[test]
fn trailing_nul_and_locations() {
    let mut p = parser();
    let root = p.parse("x;\n  yy;\0", None).unwrap();
    // prog has one child, the stmt+ list
    let second = &root.children[0].children[1];
    assert_eq!(second.string, "yy;");
    assert_eq!((second.start_loc.line, second.start_loc.col), (2, 2));
}
