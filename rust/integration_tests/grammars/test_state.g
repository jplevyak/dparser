{
// Threaded state with Rust actions; see tests/test_state.rs.
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub trace: String,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

fn depth<G, N: Default + Clone>(p: &dparser::Parser<G, N>, s: dparser::StateId) -> i32 {
    p.state::<i32>(s).copied().unwrap_or(0)
}
}

${declare subparser loop_program}
${declare subparser alt_s}
${declare subparser top_s}
${declare subparser child_s}
${declare subparser ws_s}

/* break is legal only inside a loop: the state is the loop depth. */
loop_program: stmt* ;
stmt: 'while' enter stmt leave
    | 'break' [ if depth(${parser}, ${state}) == 0 { ${reject}; } ]
    | 'x' ;
enter: [ let d = depth(${parser}, ${state}); ${state} = ${parser}.make_state(d + 1); ] ;
leave: [ let d = depth(${parser}, ${state}); ${state} = ${parser}.make_state(d - 1); ] ;

/* Two alternatives of one production that differ only in their actions'
   resulting state: only the one whose mode matches the tail survives. */
alt_s: alt_a alt_tail ;
alt_a: 'a' [ ${state} = ${parser}.make_state(1i32); ] { $g.trace.push('x'); }
     | 'a' [ ${state} = ${parser}.make_state(2i32); ] { $g.trace.push('y'); } ;
alt_tail: 'p' [ if depth(${parser}, ${state}) != 1 { ${reject}; } ]
        | 'q' [ if depth(${parser}, ${state}) != 2 { ${reject}; } ] ;

/* Two complete parses that end with different states. */
top_s: 'b' [ ${state} = ${parser}.make_state(1i32); ] { $g.trace.push('x'); }
     | 'b' [ ${state} = ${parser}.make_state(2i32); ] { $g.trace.push('y'); } ;

/* ${state N} is the state before child N; ${state} in a final action is
   the state after the node. */
child_s: 'd' child_set 'e'
  {
    let ok = ${state 0}.is_none() && ${state 1}.is_none()
        && depth(${parser}, ${state 2}) == 7 && depth(${parser}, ${state}) == 7;
    $g.trace.push_str(if ok { "ok" } else { "bad" });
  } ;
child_set: [ ${state} = ${parser}.make_state(7i32); ] ;

/* '#' comments are whitespace only after 'hash' (see the test's
   whitespace function). */
ws_s: ws_item* ;
ws_item: HASH | 'w' ;
HASH ::= 'hash' [ ${state} = ${parser}.make_state(1i32); ] ;
