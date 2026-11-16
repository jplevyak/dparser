{
// tests/python.test.g with Rust actions and a Rust whitespace function: the
// whitespace function and speculative actions share indentation state in the
// globals (which needs mutable_speculative_globals).
#[derive(Debug)]
pub struct GlobalsStruct {
    pub indent_stack: Vec<i32>,
    pub current_indent: usize,
    pub implicit_line_joining: i32,
}

impl Default for GlobalsStruct {
    fn default() -> Self {
        GlobalsStruct { indent_stack: vec![0; 1024], current_indent: 2, implicit_line_joining: 0 }
    }
}

#[derive(Debug, Default, Clone)]
pub struct NodeStruct {}

impl GlobalsStruct {
    fn at(&self, offset: isize) -> i32 {
        self.indent_stack[(self.current_indent as isize + offset) as usize]
    }
}

pub fn python_whitespace(input: &[u8], loc: &mut dparser::Loc, globals: Option<&mut GlobalsStruct>) {
    let pg = globals.expect("python_whitespace needs the globals");
    let mut p = loc.s;
    let ch = |p: usize| input.get(p).copied().unwrap_or(0);
    let mut i: i32 = if p == 0 || ch(p - 1) == b'\n' { 0 } else { -1 };
    loop {
        match ch(p) {
            b'#' => {
                p += 1;
                while ch(p) != 0 && ch(p) != b'\n' {
                    p += 1;
                }
            }
            b' ' => {
                p += 1;
                if i >= 0 {
                    i += 1;
                }
            }
            b'\t' => {
                p += 1;
                if i >= 0 {
                    i = (i + 7) & !7;
                }
            }
            b'\n' if i >= 0 || pg.implicit_line_joining != 0 => {
                loc.line += 1;
                p += 1;
                i = 0;
            }
            _ => break,
        }
    }
    if i >= 0 && pg.implicit_line_joining == 0 && ch(p) != b'\n' && i != pg.at(-1) {
        let c = pg.current_indent;
        pg.indent_stack[c] = i;
        pg.current_indent += 1;
    }
    loc.s = p;
}

fn python_indent(pg: &mut GlobalsStruct) -> bool {
    if pg.at(-1) > pg.at(-2) {
        return true;
    }
    if pg.at(-1) != 0 && pg.at(-1) == pg.at(-2) && pg.at(-2) > pg.at(-3) {
        pg.current_indent -= 1;
        return true;
    }
    false
}

fn python_dedent(pg: &mut GlobalsStruct) -> bool {
    if pg.at(-1) < pg.at(-2) {
        pg.current_indent -= 1;
        let x = pg.at(0);
        let c = pg.current_indent;
        pg.indent_stack[c - 1] = x;
        while x == pg.at(-2) {
            pg.current_indent -= 1;
        }
        return true;
    }
    false
}
}

${declare longest_match}
${declare mutable_speculative_globals}
${declare subparser single_input}
${declare subparser eval_input}
${declare whitespace python_whitespace}

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

stmt: simple_stmt | compound_stmt;
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
INDENT: [ if !python_indent($g) { ${reject}; } ] ;
DEDENT: [ if !python_dedent($g) { ${reject}; } ] ;
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

LP ::= '(' [ $g.implicit_line_joining += 1; ];
RP ::= ')' [ $g.implicit_line_joining -= 1; ];
LB ::= '[' [ $g.implicit_line_joining += 1; ];
RB ::= ']' [ $g.implicit_line_joining -= 1; ];
LC ::= '{' [ $g.implicit_line_joining += 1; ];
RC ::= '}' [ $g.implicit_line_joining -= 1; ];
