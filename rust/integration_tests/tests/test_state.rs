//! Threaded state (${state}) in the Rust runtime.
use dparser::{Loc, Parser, StateId, States};

include!(concat!(env!("OUT_DIR"), "/test_state_actions.rs"));
const TABLES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/test_state.g.d_parser.bin"));

fn parser(start: &str) -> Parser<GlobalsStruct, NodeStruct> {
    let mut p = Parser::new(TABLES, Some(dispatch_action)).unwrap();
    p.set_start_symbol(start).unwrap();
    p.error_recovery = false;
    p.syntax_error_fn = Some(|_| {});
    p
}

fn parse(p: &mut Parser<GlobalsStruct, NodeStruct>, input: &str) -> Option<String> {
    let mut g = GlobalsStruct::default();
    let ok = p.parse(input, Some(&mut g)).is_some() && p.syntax_errors == 0;
    ok.then_some(g.trace)
}

#[test]
fn break_in_loop() {
    for (input, ok) in [
        ("while break", true),
        ("break", false),
        ("while x break", false),
        ("while while break", true),
        ("while while break break", false),
    ] {
        let mut p = parser("loop_program");
        assert_eq!(parse(&mut p, input).is_some(), ok, "{}", input);
    }
}

#[test]
fn alternatives_with_different_results_stay_apart() {
    let mut p = parser("alt_s");
    assert_eq!(parse(&mut p, "a p").as_deref(), Some("x"));
    assert_eq!(parse(&mut p, "a q").as_deref(), Some("y"));
}

#[test]
fn different_final_states_reach_ambiguity_fn() {
    let mut p = parser("top_s");
    p.ambiguity_fn = Some(|p, n, v| {
        let mut states: Vec<i32> = v[..n].iter().map(|x| *p.state::<i32>(x.state).unwrap()).collect();
        states.sort();
        assert_eq!(states, [1, 2]);
        0
    });
    assert!(parse(&mut p, "b").is_some());
}

#[test]
fn prefer_state_chooses() {
    let mut p = parser("top_s");
    p.ambiguity_fn = Some(|_, _, _| panic!("prefer_state should have chosen"));
    p.prefer_state = Some(|s: &States, a: StateId, b: StateId| s.get::<i32>(a).unwrap() - s.get::<i32>(b).unwrap());
    assert_eq!(parse(&mut p, "b").as_deref(), Some("y"));
}

#[test]
fn child_states() {
    let mut p = parser("child_s");
    assert_eq!(parse(&mut p, "d e").as_deref(), Some("ok"));
}

fn ws_by_state(input: &[u8], loc: &mut Loc, _g: Option<&mut GlobalsStruct>, states: &States, state: StateId) {
    let comments = states.get::<i32>(state) == Some(&1);
    let mut s = loc.s;
    loop {
        match input.get(s) {
            Some(b'\n') => {
                loc.line += 1;
                s += 1;
            }
            Some(b' ') => s += 1,
            Some(b'#') if comments => {
                while s < input.len() && input[s] != b'\n' {
                    s += 1;
                }
            }
            _ => break,
        }
    }
    loc.s = s;
}

#[test]
fn whitespace_reads_state() {
    let mut p = parser("ws_s");
    p.white_space_state_fn = Some(ws_by_state);
    assert!(parse(&mut p, "w hash # comment\n w").is_some());
    assert!(parse(&mut p, "w # comment\n hash w").is_none());
}

#[test]
fn initial_state() {
    let mut p = parser("loop_program");
    p.initial_state = p.make_state(1i32);
    assert!(parse(&mut p, "break").is_some());
}
