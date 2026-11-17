"""The symbol table from Python: actions taking a `scope` argument."""

import types

import pytest

from dparser import Reject, SymbolTableError, SyntaxErr


def _module(name, *fns):
    mod = types.ModuleType(name)
    for f in fns:
        setattr(mod, f.__name__, f)
    return mod


# The C typedef problem: `a * b;` multiplies, unless a was declared a type.

def test_typedef_problem(make_parser):
    out = []

    def d_program(t):
        '''program : item*'''

    def d_typedef(t, spec, scope):
        '''item : 'typedef' identifier ';' '''
        if spec:
            scope.declare(t[1])
        else:
            out.append('new type ' + t[1])

    def d_declare(t):
        '''item : type_name '*' identifier ';' '''
        out.append('declare %s as pointer to %s' % (t[2], t[0]))

    def d_multiply(t):
        '''item : value '*' value ';' '''
        out.append('multiply %s by %s' % (t[0], t[2]))

    def d_type_name(t, spec, scope):
        '''type_name : identifier'''
        if spec and scope.find(t[0]) is None:
            return Reject
        return t[0]

    def d_value(t, spec, scope):
        '''value : identifier'''
        if spec and scope.find(t[0]) is not None:
            return Reject
        return t[0]

    def d_identifier(t):
        '''identifier : "[a-zA-Z_][a-zA-Z0-9_]*" $term -1'''
        return t[0]

    parser = make_parser(_module('_sym_typedef', d_program, d_typedef, d_declare, d_multiply,
                                 d_type_name, d_value, d_identifier))
    parser.parse('a * b;  typedef a;  a * b;')
    assert out == ['multiply a by b', 'new type a', 'declare b as pointer to a']


# Chapter 6's language: declarations, assignments, blocks, values in symbols.

def d_program(t):
    '''program : statement*'''


def d_declare(t, spec, scope):
    '''statement : identifier ':' expression ';' '''
    if spec:
        scope.declare(t[0], t[2])


def d_assign(t, spec, scope):
    '''statement : identifier '=' expression ';' '''
    if spec:
        sym = scope.find(t[0])
        if sym is None:
            return Reject
        scope.update(sym, t[2])


def d_print(t, g):
    '''statement : expression ';' '''
    g[0] = (g[0] or []) + [t[0]]


def d_block(t, spec, scope, nodes):
    '''statement : '{' new_scope statement* '}' '''
    if spec:
        scope.pop(nodes[0])


def d_new_scope(t, spec, scope):
    '''new_scope : '''
    if spec:
        scope.push()


def d_add(t, spec):
    '''expression : expression '+' expression $left 10'''
    return t[0] + t[2]


def d_integer(t, spec):
    '''expression : "[0-9]+" '''
    return int(t[0])


def d_name(t, spec, scope):
    '''expression : identifier'''
    sym = scope.find(t[0])
    if sym is None:
        return Reject
    return sym.value


def d_identifier(t):
    '''identifier : "[a-z]+" $term -1'''
    return t[0]


@pytest.fixture
def blocks(make_parser):
    return make_parser(_module('_sym_blocks', d_program, d_declare, d_assign, d_print, d_block,
                               d_new_scope, d_add, d_integer, d_name, d_identifier))


def printed(parser, text):
    parser.parse(text)
    return parser.globals


def test_nested_scopes_and_values(blocks):
    text = '''x: 1;
y: 2;
{
  x: 10;      // a new x, only in this block
  x + y;
  y = x + y;  // changes the outer y
}
x;
y;'''
    assert printed(blocks, text) == [12, 1, 12]


def test_undeclared_name_is_a_syntax_error(blocks):
    with pytest.raises(SyntaxErr):
        blocks.parse('x: 1; { z: 2; } z;')


def test_values_can_be_any_object(blocks):
    assert printed(blocks, 'x: 1; { x: 2; x + x; } x + 3;') == [4, 4]


def test_find_local_and_symbol_attributes(make_parser):
    seen = []

    def d_s(t):
        '''s : decl+'''

    def d_decl(t, spec, scope):
        '''decl : "[a-z]+" ';' '''
        if spec:
            dup = scope.find_local(t[0])
            sym = scope.declare(t[0], len(t[0]))
            seen.append((sym.name, sym.value, dup is not None))

    parser = make_parser(_module('_sym_local', d_s, d_decl))
    parser.parse('ab; c; ab;')
    assert ('ab', 2, False) in seen and ('ab', 2, True) in seen


def test_changes_only_in_speculative_actions(make_parser):
    errors = []

    def d_s(t, spec, scope):
        '''s : "[a-z]+" '''
        if not spec:
            try:
                scope.declare(t[0])
            except SymbolTableError as e:
                errors.append(str(e))
            assert scope.find(t[0]) is None  # lookups are fine

    parser = make_parser(_module('_sym_final', d_s))
    parser.parse('x')
    assert errors and 'speculative' in errors[0]


def test_objects_expire_with_the_parse(make_parser):
    kept = []

    def d_s(t, spec, scope):
        '''s : "[a-z]+" '''
        if spec:
            kept.append((scope, scope.declare(t[0], 1)))

    parser = make_parser(_module('_sym_expire', d_s))
    parser.parse('x')
    scope, sym = kept[0]
    with pytest.raises(SymbolTableError):
        scope.find('x')
    with pytest.raises(SymbolTableError):
        sym.value
