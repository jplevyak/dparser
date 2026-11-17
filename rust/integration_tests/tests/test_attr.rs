//! Attributes after parsing (dparser::attrs) on the typed language of
//! grammars/test_attr.g: env is inherited, type is synthesized.
use dparser::attrs::{Attr, AttrTree, NodeId};
use dparser::Parser;
use std::collections::HashMap;
use std::rc::Rc;

include!(concat!(env!("OUT_DIR"), "/test_attr_actions.rs"));
const TABLES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/test_attr.g.d_parser.bin"));

type Tree<'t, 'a> = AttrTree<'t, 'a, NodeStruct>;
type Env = Rc<HashMap<String, String>>;

fn declarations(t: &Tree, n: NodeId, vars: &mut HashMap<String, String>) {
    match t.name(n) {
        "block" => {}
        "decl" => {
            vars.insert(t.text(t.child(n, 1)).to_string(), t.text(t.child(n, 3)).to_string());
        }
        _ => {
            for &c in t.children(n) {
                declarations(t, c, vars);
            }
        }
    }
}

fn env_eq(t: &Tree, n: NodeId, child: i32) -> Option<Env> {
    if child < 0 {
        return Some(Env::default());
    }
    if t.name(n) != "block" {
        return None; // copy down
    }
    let mut vars = (*t.get(n, &ENV)?).clone();
    for &c in t.children(n) {
        declarations(t, c, &mut vars);
    }
    Some(Rc::new(vars))
}
const ENV: Attr<Env, NodeStruct> = Attr::inh("env", env_eq);

fn type_eq(t: &Tree, n: NodeId, _: i32) -> Option<String> {
    match t.name(n) {
        "number" => Some("int".into()),
        "name" => Some(t.get(n, &ENV)?.get(t.text(n)).cloned().unwrap_or_else(|| "undefined".into())),
        "expr" => {
            let p = t.production(n);
            if p == D_RULE_expr_0 || p == D_RULE_expr_1 {
                let (a, b) = (t.get(t.child(n, 0), &TYPE)?, t.get(t.child(n, 2), &TYPE)?);
                Some(if p == D_RULE_expr_0 {
                    if a == "int" && b == "int" { "int" } else { "error" }
                } else if a == b {
                    "bool"
                } else {
                    "error"
                }
                .into())
            } else {
                let c = t.child(n, 0);
                if matches!(t.name(c), "name" | "number") { t.get(c, &TYPE) } else { Some("bool".into()) }
            }
        }
        _ => None,
    }
}
const TYPE: Attr<String, NodeStruct> = Attr::syn("type", type_eq);

fn parser(start: &str) -> Parser<GlobalsStruct, NodeStruct> {
    let mut p = Parser::new(TABLES, Some(dispatch_action)).unwrap();
    p.set_start_symbol(start).unwrap();
    p.set_save_parse_tree(true);
    p
}

#[test]
fn typed_language() {
    let mut p = parser("program");
    let src = "{ var x : int; var b : bool; x + 1; x == 2; { var y : int; y + x; } b + 1; z; true == b; }";
    let root = p.parse(src, Some(&mut GlobalsStruct::default())).expect("parses");
    let t = AttrTree::new(&p, &root);
    // the statements' expression types, in source order
    let mut by_pos: Vec<(usize, String)> = t
        .nodes()
        .filter(|&n| t.name(n) == "stmt" && t.name(t.child(n, 0)) == "expr")
        .map(|n| (t.node(n).start_loc.s, t.get(t.child(n, 0), &TYPE).unwrap()))
        .collect();
    by_pos.sort();
    let types: Vec<&str> = by_pos.iter().map(|(_, s)| s.as_str()).collect();
    assert_eq!(types, ["int", "bool", "int", "error", "undefined", "bool"]);
    assert_eq!(t.get(t.root(), &TYPE), None);
    assert!(t.cycles().is_empty());
}

#[test]
fn rule_numbers() {
    let mut p = parser("program");
    let root = p.parse("{ 1 + 2; 3 == 4; }", Some(&mut GlobalsStruct::default())).unwrap();
    let t = AttrTree::new(&p, &root);
    let rules: Vec<i32> = t.nodes().filter(|&n| t.name(n) == "expr").map(|n| t.production(n)).collect();
    assert!(rules.contains(&D_RULE_expr_0) && rules.contains(&D_RULE_expr_1));
    assert_eq!(D_RULE_expr_2, D_RULE_expr_3, "leaf rules share a reduction");
    assert!(t.nodes().filter(|&n| t.name(n) == "+").all(|n| t.production(n) == -1));
}

fn slot_eq(_: &Tree, _: NodeId, child: i32) -> Option<i32> {
    (child >= 0).then_some(child)
}
const SLOT: Attr<i32, NodeStruct> = Attr::inh("slot", slot_eq);

#[test]
fn shared_node_gets_one_attr_node_per_occurrence() {
    let mut p = parser("pair");
    let root = p.parse("p", Some(&mut GlobalsStruct::default())).unwrap();
    let t = AttrTree::new(&p, &root);
    let (a, b) = (t.child(t.root(), 1), t.child(t.root(), 2));
    assert_ne!(a, b);
    assert_eq!((t.get(a, &SLOT), t.get(b, &SLOT), t.get(t.root(), &SLOT)), (Some(1), Some(2), None));
}

fn a_eq(t: &Tree, n: NodeId, _: i32) -> Option<i32> {
    Some(t.get(t.child(n, 0), &B).map_or(0, |b| b + 1))
}
fn b_eq(t: &Tree, n: NodeId, child: i32) -> Option<i32> {
    if child < 0 { None } else { t.get(n, &A) }
}
const A: Attr<i32, NodeStruct> = Attr::syn("a", a_eq);
const B: Attr<i32, NodeStruct> = Attr::inh("b", b_eq);

#[test]
fn cycle_is_reported() {
    let mut p = parser("cyc");
    let root = p.parse("c", Some(&mut GlobalsStruct::default())).unwrap();
    let t = AttrTree::new(&p, &root);
    assert_eq!(t.get(t.root(), &A), Some(0));
    let cycles = t.cycles();
    assert_eq!(cycles.len(), 1);
    let names: Vec<&str> = cycles[0].iter().map(|&(a, _)| a).collect();
    assert_eq!(names, ["a", "b", "a"]);
}
