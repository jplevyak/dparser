//! Helpers for checking the Rust runtime against the C test suite in `../../tests`.

use dparser::{ParseNode, Parser, Stats};
use std::path::PathBuf;

/// The C test suite.
pub fn tests_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests")
}

/// The contents of a file in the C test suite.
pub fn test_file(name: &str) -> String {
    let path = tests_dir().join(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{}: {}", path.display(), e))
}

/// The tree as printed by the C runtime's `print_paren`.
pub fn print_paren<N>(n: &ParseNode<'_, N>) -> String {
    fn rec<N>(n: &ParseNode<'_, N>, out: &mut String) {
        if n.error_recovery {
            return;
        }
        if !n.children.is_empty() {
            if n.children.len() > 1 {
                out.push('(');
            }
            for c in &n.children {
                rec(c, out);
            }
            if n.children.len() > 1 {
                out.push(')');
            }
        } else if !n.string.is_empty() || !n.end_skip_string.is_empty() {
            out.push(' ');
            out.push_str(n.string);
            out.push_str(n.end_skip_string);
            out.push(' ');
        }
    }
    let mut out = String::new();
    rec(n, &mut out);
    out
}

/// The statistics line printed by `sample_parser -v`.
pub fn stats_line(s: &Stats) -> String {
    format!(
        "{} states {} scans {} shifts {} reductions {} compares {} ambiguities",
        s.states, s.scans, s.shifts, s.reductions, s.compares, s.ambiguities
    )
}

fn first<G, N>(_p: &mut Parser<G, N>, _n: usize, _v: &mut [ParseNode<'_, N>]) -> usize {
    0
}

/// Configure a parser as the C test driver (`sample_parser`) does.
pub fn like_sample_parser<G: 'static, N: 'static + Default + Clone>(p: &mut Parser<G, N>) {
    p.ambiguity_fn = Some(first::<G, N>);
    p.save_parse_tree = true;
}

/// Parse C test input `name` and return what `sample_parser -v` prints: the
/// lines `output` returns (what the actions recorded), the statistics, and
/// the tree.
pub fn run_like_sample_parser<G: 'static, N: 'static + Default + Clone>(
    p: &mut Parser<G, N>,
    globals: &mut G,
    name: &str,
    output: impl Fn(&G) -> Vec<String>,
) -> String {
    like_sample_parser(p);
    let input = test_file(name);
    p.set_loc(name, 1);
    let tree = p.parse(&input, Some(globals));
    let mut out: Vec<String> = output(globals);
    match tree {
        Some(t) => {
            out.push(stats_line(&p.stats));
            out.push(print_paren(&t));
        }
        None => out.push(format!("fatal error, '{}' line {}", name, p.loc.line)),
    }
    out.join("\n") + "\n"
}
