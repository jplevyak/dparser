{
// tests/python.test.g with Rust actions.  The threaded state of a parse path
// holds the depth of open brackets (inside which newlines are whitespace) and
// the stack of indentation columns.  The whitespace function reads it; INDENT,
// DEDENT and LINE (at the start of a statement) check and change it.  Actions
// find a line's column in the input, which the test puts in the globals.
#[derive(Debug, Default)]
pub struct GlobalsStruct {
    pub input: String,
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct PyState {
    pub joining: i32,
    pub indent: Vec<i32>,
}

impl Default for PyState {
    fn default() -> Self {
        PyState { joining: 0, indent: vec![0] }
    }
}

type P = dparser::Parser<GlobalsStruct, NodeStruct>;

fn py_get(p: &P, s: dparser::StateId) -> PyState {
    p.state::<PyState>(s).cloned().unwrap_or_default()
}

/// The state with the bracket depth changed by `d`.
fn py_with(p: &mut P, s: dparser::StateId, d: i32) -> dparser::StateId {
    let mut x = py_get(p, s);
    x.joining = (x.joining + d).max(0);
    p.make_state(x)
}

/// The column of `s` if it starts its line (tabs to multiples of 8).
fn py_column(input: &str, s: usize) -> Option<i32> {
    let b = input.as_bytes();
    let mut start = s;
    while start > 0 && (b[start - 1] == b' ' || b[start - 1] == b'\t') {
        start -= 1;
    }
    if start > 0 && (b[start - 1] != b'\n' || (start > 1 && b[start - 2] == b'\\')) {
        return None;
    }
    Some(b[start..s].iter().fold(0, |c, &x| if x == b'\t' { (c / 8 + 1) * 8 } else { c + 1 }))
}

fn py_indent(p: &mut P, input: &str, s: dparser::StateId, at: usize) -> Option<dparser::StateId> {
    let mut x = py_get(p, s);
    let col = py_column(input, at)?;
    if col <= *x.indent.last().unwrap() {
        return None;
    }
    x.indent.push(col);
    Some(p.make_state(x))
}

/// Close one level; the column must match an enclosing level.
fn py_dedent(p: &mut P, input: &str, s: dparser::StateId, at: usize) -> Option<dparser::StateId> {
    let mut x = py_get(p, s);
    let col = py_column(input, at)?;
    let n = x.indent.len();
    if col >= x.indent[n - 1] || !x.indent[..n - 1].contains(&col) {
        return None;
    }
    x.indent.pop();
    Some(p.make_state(x))
}

fn py_line(p: &P, input: &str, s: dparser::StateId, at: usize) -> bool {
    py_column(input, at) == py_get(p, s).indent.last().copied()
}

pub fn python_whitespace(
    input: &[u8],
    loc: &mut dparser::Loc,
    _globals: Option<&mut GlobalsStruct>,
    states: &dparser::States,
    state: dparser::StateId,
) {
    let joining = states.get::<PyState>(state).map_or(0, |x| x.joining);
    let mut p = loc.s;
    let ch = |p: usize| input.get(p).copied().unwrap_or(0);
    let mut at_line_start = p == 0 || ch(p - 1) == b'\n';
    loop {
        match ch(p) {
            b'#' => {
                p += 1;
                while ch(p) != 0 && ch(p) != b'\n' {
                    p += 1;
                }
            }
            b' ' | b'\t' => p += 1,
            b'\n' if at_line_start || joining != 0 => {
                loc.line += 1;
                p += 1;
                at_line_start = true;
            }
            _ => break,
        }
    }
    loc.s = p;
}
}

${declare longest_match}
${declare subparser single_input}
${declare subparser eval_input}

file_input: (NL | stmt)*;
single_input: NL | simple_stmt | compound_stmt NL;
eval_input: testlist NL*;

decorator: '@' dotted_name ( LP arglist? RP )? NL;
decorators: decorator+;
decorated: decorators (classdef | funcdef);
funcdef: 'def' NAME parameters ':' suite;
parameters: LP varargslist? RP;
varargslist: (fpdef ('=' test)? ',')* ('*' NAME (',' '**' NAME) | '**' NAME) | fpdef ('=' test)? (',' fpdef ('=' test)?)* ','?;
fpdef: NAME | LP fplist RP;
fplist: fpdef (',' fpdef)* ','?;

stmt: LINE (simple_stmt | compound_stmt);
simple_stmt: small_stmt (';' small_stmt)* ';'? NL;
small_stmt: expr_stmt | print_stmt  | 'del' exprlist | 'pass' | flow_stmt | import_stmt | global_stmt | exec_stmt | assert_stmt;
expr_stmt: testlist (augassign testlist | ('=' testlist)*);
augassign: '+=' | '-=' | '*=' | '/=' | '%=' | '&=' | '|=' | '^=' | '<<=' | '>>=' | '**=' | '//=';
print_stmt: 'print' ( ( test (',' test)* ','? )? | '>>' test ( (',' test)+ ','? )? );
pass_stmt: 'pass';
flow_stmt: 'break' | 'continue' | 'return' testlist? | raise_stmt | 'yiled' testlist;
raise_stmt: 'raise' (test (',' test (',' test)?)?)?;
import_stmt: import_name | import_from;
import_name: 'import' dotted_as_names;
import_from: ('from' ('.'* dotted_name | '.'+)
              'import' ('*' | '(' import_as_names ')' | import_as_names));
import_as_name: NAME ('as' NAME)?;
dotted_as_name: dotted_name ('as' NAME)?;
import_as_names: import_as_name (',' import_as_name)* ','?;
dotted_as_names: dotted_as_name (',' dotted_as_name)*;
dotted_name: NAME ('.' NAME)*;
global_stmt: 'global' NAME (',' NAME)*;
exec_stmt: 'exec' expr ('in' test (',' test)?)?;
assert_stmt: 'assert' test (',' test)?;

compound_stmt: if_stmt | while_stmt | for_stmt | try_stmt | with_stmt | funcdef | classdef | decorated;
if_stmt: 'if' test ':' suite ('elif' test ':' suite)* ('else' ':' suite)?;
while_stmt: 'while' test ':' suite ('else' ':' suite)?;
for_stmt: 'for' exprlist 'in' testlist ':' suite ('else' ':' suite)?;
try_stmt: ('try' ':' suite
           ((except_clause ':' suite)+
            ('else' ':' suite)?
            ('finally' ':' suite)? |
            'finally' ':' suite));
with_stmt: 'with' with_item (',' with_item)*  ':' suite;
with_item: test ('as' expr)?;
except_clause: 'except' (test (',' test)?)?;
suite: simple_stmt | NL INDENT stmt+ DEDENT;

testlist_safe: old_test ((',' old_test)+ ','?)?;
old_test: or_test | old_lambdef;
old_lambdef: 'lambda' varargslist? ':' old_test;

test: or_test ('if' or_test 'else' test)? | lambdef;
or_test: and_test ('or' and_test)*;
and_test: not_test ('and' not_test)*;
not_test: 'not' not_test | comparison;
comparison: expr (comp_op expr)*;
comp_op: '<'|'>'|'=='|'>='|'<='|'<>'|'!='|'in'|'not' 'in'|'is'|'is' 'not';
expr: xor_expr ('|' xor_expr)*;
xor_expr: and_expr ('^' and_expr)*;
and_expr: shift_expr ('&' shift_expr)*;
shift_expr: arith_expr (('<<'|'>>') arith_expr)*;
arith_expr: term (('+'|'-') term)*;
term: factor (('*'|'/'|'%'|'//') factor)*;
factor: ('+'|'-'|'~') factor | power;
power: atom trailer* ('**' factor)*;
atom: (LP (yield_expr|testlist_comp)? RP |
       LB listmaker? RB |
       LC dictorsetmaker? RC |
       '`' testlist1 '`' |
       NAME | NUMBER | STRING+);
listmaker: test ( list_for | (',' test)* ','? );
testlist_comp: test ( comp_for | (',' test)* ','? );
lambdef: 'lambda' varargslist? ':' test;
trailer: LP arglist? RP | LB subscriptlist RB | '.' NAME;
subscriptlist: subscript (',' subscript)* ','?;
subscript: '.' '.' '.' | test | test? ':' test? sliceop?;
sliceop: ':' test?;
exprlist: expr (',' expr)* ','?;
testlist: test (',' test)* ','?;
dictorsetmaker: ( (test ':' test (comp_for | (',' test ':' test)* ','?)) |
                  (test (comp_for | (',' test)* ','?)) );

classdef: 'class' NAME (LP testlist? RP)? ':' suite;

arglist: (argument ',')* (argument ','?
             | '*' test (',' argument)* (',' '**' test)?
             | '**' test);
argument: test comp_for? | test '=' test;

list_iter: list_for | list_if;
list_for: 'for' exprlist 'in' testlist_safe list_iter?;
list_if: 'if' test list_iter?;

comp_iter: comp_for | comp_if;
comp_for: 'for' exprlist 'in' or_test comp_iter?;
comp_if: 'if' old_test comp_iter?;

testlist1: test (',' test)*;
encoding_decl: NAME;
yield_expr: 'yield' testlist?;


/* additional material from http://www.python.org/doc/current/ref/grammar.txt */

NL: '\n';
INDENT: [ match py_indent(${parser}, &$g.input, ${state}, $n.start_loc.s) { Some(s) => ${state} = s, None => ${reject} } ] ;
DEDENT: [ match py_dedent(${parser}, &$g.input, ${state}, $n.start_loc.s) { Some(s) => ${state} = s, None => ${reject} } ] ;
LINE: [ if !py_line(${parser}, &$g.input, ${state}, $n.start_loc.s) { ${reject}; } ] ;
NAME ::= (letter|'_') (letter | digit | '_')*;
letter ::= "[a-zA-Z]";
digit ::= "[0-9]";
STRING ::= stringprefix?(shortstring | longstring);
shortstring ::= "'" shortstringsingleitem* "'"
| '"' shortstringdoubleitem* '"';
longstring ::= "'''" longstringitem* "'''"
| '"""' longstringitem* '"""';
shortstringsingleitem ::= shortstringsinglechar | escapeseq;
shortstringdoubleitem ::= shortstringdoublechar | escapeseq;
longstringitem ::= longstringchar | escapeseq;
shortstringsinglechar ::= "[^\\\n\']";
shortstringdoublechar ::= "[^\\\n\"]";
longstringchar ::= "[^\\]";
stringprefix ::= 'r' | 'u' | 'ur' | 'R' | 'U' | 'UR' | 'Ur' | 'uR';
escapeseq ::= "\\[^]";
NUMBER ::= integer | longinteger | floatnumber | imagnumber;
integer ::= decimalinteger | octinteger | hexinteger;
decimalinteger ::= nonzerodigit digit* | '0';
octinteger ::= '0' octdigit+;
hexinteger ::= '0' ('x' | 'X') hexdigit+;
floatnumber ::= pointfloat | exponentfloat;
pointfloat ::= intpart? fraction | intpart '.';
exponentfloat ::= (intpart | pointfloat) exponent;
intpart ::= digit+;
fraction ::= "." digit+;
exponent ::= ("e" | "E") ("+" | "-")? digit+;
imagnumber ::= (floatnumber | intpart) ("j" | "J");
longinteger ::= integer ("l" | "L");
nonzerodigit ::= "[1-9]";
digit ::= "[0-9]";
octdigit ::= "[0-7]";
hexdigit ::= digit | "[a-fA-F]";

LP ::= '(' [ ${state} = py_with(${parser}, ${state}, 1); ];
RP ::= ')' [ ${state} = py_with(${parser}, ${state}, -1); ];
LB ::= '[' [ ${state} = py_with(${parser}, ${state}, 1); ];
RB ::= ']' [ ${state} = py_with(${parser}, ${state}, -1); ];
LC ::= '{' [ ${state} = py_with(${parser}, ${state}, 1); ];
RC ::= '}' [ ${state} = py_with(${parser}, ${state}, -1); ];
