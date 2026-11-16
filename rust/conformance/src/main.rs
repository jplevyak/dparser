//! Parse a file with binary tables and print the result in the format of the
//! C `sample_parser -v`, so the Rust runtime can be checked against the C
//! test suite (see run.sh).
//!
//! usage: conformance [-S state] [-N name] [-p] [-c] [-f] [-e] [-G] [-H] [-P] [-s] [-i n] tables.bin input

use dparser::{ParseNode, Parser};

fn print_paren(n: &ParseNode<'_, ()>, out: &mut String) {
    if n.error_recovery {
        return;
    }
    if !n.children.is_empty() {
        if n.children.len() > 1 {
            out.push('(');
        }
        for c in &n.children {
            print_paren(c, out);
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

// sample_parser counts ambiguities and picks the first alternative
fn first(_p: &mut Parser<(), ()>, _n: usize, _v: &mut [ParseNode<'_, ()>]) -> usize {
    0
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut files = Vec::new();
    let (mut start_state, mut start_name) = (None, None);
    let (mut partial, mut compare_stacks, mut fixup, mut fixup_ebnf) = (false, true, true, false);
    let (mut nogreedy, mut noheight, mut nopri, mut save) = (false, false, false, true);
    let mut interval = 100;
    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        if let Some(flags) = a.strip_prefix('-') {
            let mut chars = flags.chars();
            while let Some(c) = chars.next() {
                match c {
                    'S' | 'N' | 'i' => {
                        let rest: String = chars.by_ref().collect();
                        let v = if rest.is_empty() {
                            i += 1;
                            args[i].clone()
                        } else {
                            rest
                        };
                        match c {
                            'S' => start_state = Some(v.parse::<usize>().unwrap()),
                            'N' => start_name = Some(v),
                            _ => interval = v.parse().unwrap(),
                        }
                    }
                    'p' => partial = !partial,
                    'c' => compare_stacks = !compare_stacks,
                    'f' => fixup = !fixup,
                    'e' => fixup_ebnf = !fixup_ebnf,
                    'G' => nogreedy = !nogreedy,
                    'H' => noheight = !noheight,
                    'P' => nopri = !nopri,
                    's' => save = !save,
                    'v' => {}
                    _ => panic!("unknown flag -{}", c),
                }
            }
        } else {
            files.push(a.clone());
        }
        i += 1;
    }
    let tables = std::fs::read(&files[0]).expect("tables");
    let mut p: Parser<(), ()> = Parser::new(&tables, None).expect("load tables");
    p.ambiguity_fn = Some(first);
    p.save_parse_tree = save;
    p.partial_parses = partial;
    p.dont_fixup_internal_productions = !fixup;
    p.fixup_ebnf_productions = fixup_ebnf;
    p.dont_compare_stacks = !compare_stacks;
    p.commit_actions_interval = interval;
    p.dont_use_greediness_for_disambiguation = nogreedy;
    p.dont_use_height_for_disambiguation = noheight;
    p.dont_use_deep_priorities_for_disambiguation = nopri;
    if let Some(s) = start_state {
        p.start_state = s;
    }
    if let Some(n) = start_name {
        p.set_start_symbol(&n).unwrap();
    }
    for f in &files[1..] {
        let bytes = std::fs::read(f).expect("input");
        let input = String::from_utf8_lossy(&bytes).into_owned();
        p.set_loc(f, 1);
        match p.parse(&input, None) {
            Some(root) => {
                let s = p.stats;
                println!(
                    "{} states {} scans {} shifts {} reductions {} compares {} ambiguities",
                    s.states, s.scans, s.shifts, s.reductions, s.compares, s.ambiguities
                );
                if save {
                    let mut out = String::new();
                    print_paren(&root, &mut out);
                    println!("{}", out);
                }
            }
            None => eprintln!("fatal error, '{}' line {}", f, p.loc.line),
        }
    }
}
