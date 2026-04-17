"""Tests for ambiguity resolution via ambiguity_fn.

When a grammar has two rules that match the same input, dparser calls
ambiguity_fn with a list of DParseNode alternatives and uses whichever node
the function returns to continue the parse.  User values (action return values)
are not yet populated at call time, so disambiguation must be done by selecting
among the node objects themselves.
"""

import types
import pytest
import dparser


# Grammar where h1 and h2 both match 'a', creating an unresolved ambiguity
# unless ambiguity_fn is provided.

def _d_h(t):
    'h : h1 | h2'
    return t[0]


def _d_h1(t):
    "h1 : 'a'"
    return 1


def _d_h2(t):
    "h2 : 'a'"
    return 2


@pytest.fixture
def parser_ambig(make_parser):
    mod = types.ModuleType('_ambig_grammar')
    for attr, fn in [('d_h', _d_h), ('d_h1', _d_h1), ('d_h2', _d_h2)]:
        setattr(mod, attr, fn)
    return make_parser(mod)


def test_ambiguity_fn_receives_both_alternatives(parser_ambig):
    seen = []
    def capture(v):
        seen.extend(v)
        return v[0]
    parser_ambig.parse('a', ambiguity_fn=capture)
    assert len(seen) == 2


def test_ambiguity_fn_nodes_are_distinct_objects(parser_ambig):
    nodes = []
    def capture(v):
        nodes.extend(v)
        return v[0]
    parser_ambig.parse('a', ambiguity_fn=capture)
    assert nodes[0] is not nodes[1]


def test_ambiguity_fn_selection_affects_result(parser_ambig):
    # The two alternatives produce different final values; choosing different
    # nodes should yield different getStructure() results.
    results = {
        parser_ambig.parse('a', ambiguity_fn=lambda v: v[0]).getStructure(),
        parser_ambig.parse('a', ambiguity_fn=lambda v: v[-1]).getStructure(),
    }
    assert results == {1, 2}
