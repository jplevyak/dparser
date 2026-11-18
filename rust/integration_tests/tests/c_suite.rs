//! Grammars from the C test suite (../../tests) whose C actions decide the
//! parse, ported to Rust actions.  Each must print exactly what the C runtime
//! does: the actions' output, the parse statistics and the tree.

use dparser::Parser;
use integration_tests::{run_like_sample_parser, test_file};

macro_rules! grammar {
    ($m:ident, $name:literal) => {
        mod $m {
            include!(concat!(env!("OUT_DIR"), "/", $name, "_actions.rs"));
            pub const TABLES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/", $name, ".g.d_parser.bin"));
        }
    };
}

grammar!(g4, "g4_scan");
grammar!(g7, "g7_scanner");
grammar!(g25, "g25_whitespace");
grammar!(g26, "g26_terminal_actions");
grammar!(g28, "g28_symtab");
grammar!(g31, "g31_passes");
grammar!(g33, "g33_default_passes");
grammar!(g40, "g40_scopes");
grammar!(g53, "g53_speculative");
grammar!(python2, "python2_indent");
grammar!(ansic, "ansic_typedef");

fn expected(input: &str) -> String {
    test_file(&format!("{}.check", input))
}

#[test]
fn g26_terminal_speculative_actions() {
    let mut p = Parser::new(g26::TABLES, Some(g26::dispatch_action)).unwrap();
    let mut g = g26::GlobalsStruct::default();
    let got = run_like_sample_parser(&mut p, &mut g, "g26.test.g.1", |g| g.out.clone());
    assert_eq!(got, expected("g26.test.g.1"));
}

#[test]
fn g28_symbol_table_scopes_updates_and_commit() {
    for input in ["g28.test.g.1", "g28.test.g.2"] {
        let mut p = Parser::new(g28::TABLES, Some(g28::dispatch_action)).unwrap();
        let mut g = g28::GlobalsStruct::default();
        let got = run_like_sample_parser(&mut p, &mut g, input, |g| g.out.clone());
        assert_eq!(got, expected(input), "{}", input);
    }
}

#[test]
fn g31_passes() {
    let mut p = Parser::new(g31::TABLES, Some(g31::dispatch_action)).unwrap();
    let mut g = g31::GlobalsStruct::default();
    let got = run_like_sample_parser(&mut p, &mut g, "g31.test.g.1", |g| g.out.clone());
    assert_eq!(got, expected("g31.test.g.1"));
}

#[test]
fn g33_default_pass_code() {
    let mut p = Parser::new(g33::TABLES, Some(g33::dispatch_action)).unwrap();
    let mut g = g33::GlobalsStruct::default();
    let got = run_like_sample_parser(&mut p, &mut g, "g33.test.g.1", |g| g.out.clone());
    assert_eq!(got, expected("g33.test.g.1"));
}

#[test]
fn g40_saved_and_reentered_scopes() {
    let mut p = Parser::new(g40::TABLES, Some(g40::dispatch_action)).unwrap();
    let mut g = g40::GlobalsStruct::default();
    let got = run_like_sample_parser(&mut p, &mut g, "g40.test.g.1", |_| Vec::new());
    assert_eq!(got, expected("g40.test.g.1"));
}

#[test]
fn g53_speculative_declarations_decide_the_parse() {
    for input in ["g53.test.g.1", "g53.test.g.2"] {
        let mut p = Parser::new(g53::TABLES, Some(g53::dispatch_action)).unwrap();
        let mut g = g53::GlobalsStruct::default();
        let got = run_like_sample_parser(&mut p, &mut g, input, |g| g.out.clone());
        assert_eq!(got, expected(input), "{}", input);
    }
}

#[test]
fn commit_interval_does_not_change_results() {
    // Committing actions every shift (rather than at the end) must give the
    // same actions, in the same order, and the same tree.
    let mut p = Parser::new(g28::TABLES, Some(g28::dispatch_action)).unwrap();
    let mut g = g28::GlobalsStruct::default();
    p.commit_actions_interval = 0;
    let got = run_like_sample_parser(&mut p, &mut g, "g28.test.g.1", |g| g.out.clone());
    assert_eq!(got, expected("g28.test.g.1"));
}

#[test]
fn g4_external_scanner() {
    let mut p = Parser::with_actions(g4::TABLES, g4::actions()).unwrap();
    let got = run_like_sample_parser(&mut p, &mut g4::GlobalsStruct::default(), "g4.test.g.1", |_| Vec::new());
    assert_eq!(got, expected("g4.test.g.1"));
    // without the scanner, the parser can't be made
    assert!(Parser::new(g4::TABLES, Some(g4::dispatch_action)).is_err());
}

#[test]
fn g7_external_tokenizer() {
    for input in ["g7.test.g.1", "g7.test.g.2"] {
        let mut p = Parser::with_actions(g7::TABLES, g7::actions()).unwrap();
        let got = run_like_sample_parser(&mut p, &mut g7::GlobalsStruct::default(), input, |_| Vec::new());
        assert_eq!(got, expected(input), "{}", input);
    }
}

#[test]
fn g25_whitespace_function() {
    let mut p = Parser::with_actions(g25::TABLES, g25::actions()).unwrap();
    let got = run_like_sample_parser(&mut p, &mut g25::GlobalsStruct::default(), "g25.test.g.1", |_| Vec::new());
    assert_eq!(got, expected("g25.test.g.1"));
    assert!(Parser::new(g25::TABLES, Some(g25::dispatch_action)).is_err());
}

#[test]
fn python2_indentation_from_threaded_state() {
    let mut p = Parser::with_actions(python2::TABLES, python2::actions()).unwrap();
    p.white_space_state_fn = Some(python2::python_whitespace);
    let mut g = python2::GlobalsStruct { input: test_file("python2.test.g.1") };
    let got = run_like_sample_parser(&mut p, &mut g, "python2.test.g.1", |_| Vec::new());
    assert_eq!(got, expected("python2.test.g.1"));
}

#[test]
fn ansic_typedef_names_and_error_recovery() {
    // The input has a syntax error, which is reported (on stderr) and recovered from.
    let mut p = Parser::new(ansic::TABLES, Some(ansic::dispatch_action)).unwrap();
    let mut g = ansic::GlobalsStruct::default();
    let got = run_like_sample_parser(&mut p, &mut g, "ansic.test.g.1", |_| Vec::new());
    let want: String = expected("ansic.test.g.1")
        .lines()
        .filter(|l| !l.contains("syntax error"))
        .map(|l| l.to_string() + "\n")
        .collect();
    assert_eq!(got, want);
    assert_eq!(p.syntax_errors, 1);
    assert_eq!(p.loc.line, 2);
}

#[test]
fn ansic_typedef_decides_the_parse() {
    // `T * x;` declares x as a pointer if T is a typedef name, and is a
    // multiplication otherwise.
    fn parse(src: &str) -> String {
        let mut p = Parser::new(ansic::TABLES, Some(ansic::dispatch_action)).unwrap();
        integration_tests::like_sample_parser(&mut p);
        let tree = p.parse(src, Some(&mut ansic::GlobalsStruct::default())).expect("parse");
        assert_eq!(p.syntax_errors, 0);
        integration_tests::print_paren(&tree)
    }
    let as_decl = parse("typedef int T; void f() { T * x; }");
    let as_expr = parse("int T; void f() { T * x; }");
    assert_ne!(as_decl, as_expr);
    assert!(as_decl.contains("( T ((( * ( x )))) ; )"), "{}", as_decl);
    assert!(as_expr.contains("( T )( * ( x ))"), "{}", as_expr); // a multiplication
}
