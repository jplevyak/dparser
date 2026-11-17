"""Attributes after parsing (dparser_attrs) on trees kept with
parse(..., keep_tree=True): a typed language with an inherited env and a
synthesized type, copy-down, a shared node, cycles, and other trees."""

import types as pytypes

import pytest

from dparser_attrs import AttrTree, AttributeCycle, NO_EQUATION, inh, syn


def d_program(t):
    '''program : block'''


def d_block(t):
    '''block : '{' decl* stmt* '}' '''


def d_decl(t):
    '''decl : 'var' name ':' tname ';' '''


def d_stmt(t):
    '''stmt : expr ';' | block'''


def d_expr(t):
    '''expr : expr '+' expr $left 10 | expr '==' expr $left 5 | name | number | 'true' '''


def d_tname(t):
    '''tname : 'int' | 'bool' '''


def d_name(t):
    '''name : "[a-z]+" $term -1'''


def d_number(t):
    '''number : "[0-9]+"'''


@pytest.fixture
def typed(make_parser):
    mod = pytypes.ModuleType('_attr_typed')
    for f in (d_program, d_block, d_decl, d_stmt, d_expr, d_tname, d_name, d_number):
        setattr(mod, f.__name__, f)
    return make_parser(mod)


def declarations(node):
    if node.name == 'block':
        return {}  # nested blocks declare their own
    if node.name == 'decl':
        return {node.children[1].text: node.children[3].text}
    found = {}
    for c in node.children:
        found.update(declarations(c))
    return found


@inh
def env(node, child):
    if child < 0:
        return {}
    if node.name != 'block':
        return NO_EQUATION
    found = dict(env(node))
    for c in node.children:
        found.update(declarations(c))
    return found


@syn
def type_(node):
    if node.name == 'number':
        return 'int'
    if node.name == 'name':
        return env(node).get(node.text, 'undefined')
    if node.name != 'expr':
        return NO_EQUATION
    if node.action is d_expr and node.alternative in (0, 1):
        a, b = type_(node.children[0]), type_(node.children[2])
        if node.alternative == 0:
            return 'int' if a == b == 'int' else 'error'
        return 'bool' if a == b else 'error'
    child = node.children[0]
    return type_(child) if child.name in ('name', 'number') else 'bool'


def stmt_types(tree):
    return [type_(n.children[0]) for n in tree.nodes()
            if n.name == 'stmt' and n.children[0].name == 'expr']


def test_typed_language(typed):
    r = typed.parse('{ var x : int; var b : bool; x + 1; x == 2; { var y : int; y + x; } b + 1; z; true == b; }',
                    keep_tree=True)
    tree = AttrTree(r.getTree())
    assert stmt_types(tree) == ['int', 'bool', 'int', 'error', 'undefined', 'bool']
    assert type_(tree.root) is None  # no equation: undefined


def test_nodes_record_their_rule(typed):
    root = typed.parse('{ 1 + 2; 3 == 4; }', keep_tree=True).getTree()
    exprs = [n for n in AttrTree(root).nodes() if n.name == 'expr']
    assert [(n.action.__name__, n.alternative) for n in exprs[:2]] == [('d_expr', 0), ('d_expr', 3)]
    assert root.name == 'program' and root.text.startswith('{') and root.line == 1


def test_copy_down_reuses_the_ancestors_value(typed):
    tree = AttrTree(typed.parse('{ var x : int; { x; } }', keep_tree=True).getTree())
    name = next(n for n in tree.nodes() if n.name == 'name' and n.parent.name == 'expr')
    owner = name
    while owner.parent.name != 'block':
        owner = owner.parent
    assert env(name) is env(owner)
    assert env(name) == {'x': 'int'}


def test_without_keep_tree_there_is_no_tree(typed):
    assert typed.parse('{ }').getTree() is None


class T:
    """A minimal tree, to show that any tree with children works."""

    def __init__(self, name, *children):
        self.name = name
        self.children = list(children)


def test_shared_node_gets_one_attr_node_per_occurrence():
    leaf = T('leaf')
    root = T('pair', leaf, leaf)

    @inh
    def slot(node, child):
        return NO_EQUATION if child < 0 else child

    tree = AttrTree(root)
    a, b = tree.root.children
    assert a.node is b.node and a is not b
    assert (slot(a), slot(b), slot(tree.root)) == (0, 1, None)


def test_cycle_is_reported_and_can_be_retried():
    root = T('cyc', T('c'))

    @syn
    def a(node):
        return b(node.children[0]) + 1

    @inh
    def b(node, child):
        return a(node)

    tree = AttrTree(root)
    with pytest.raises(AttributeCycle) as e:
        a(tree.root)
    assert [name for name, _ in e.value.chain] == ['a', 'b', 'a']
    with pytest.raises(AttributeCycle):  # nothing was cached in progress
        a(tree.root)


def test_custom_children():
    tree = AttrTree({'n': 1, 'kids': [{'n': 2, 'kids': []}]}, children=lambda d: d['kids'])

    @syn
    def total(node):
        return node.node['n'] + sum(total(c) for c in node.children)

    assert total(tree.root) == 3
