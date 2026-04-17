"""Tests for speculative parsing with Reject and spec/spec_only arguments, converted from test4.py and test5.py."""

import types
import pytest
import dparser


# --- test4 grammar: ambiguity resolved by rejecting x2 in speculative pass ---

def _t4_S(t):
    "S: a | b"
    del t
    return 'S'


def _t4_a(t):
    "a : x1 x1 'y'"
    del t


def _t4_b(t):
    "b : x2 x2 'y'"
    del t


def _t4_x1(t, spec):
    "x1 : 'x'"
    del t, spec


def _t4_x2(t, spec):
    "x2 : 'x'"
    del t
    if spec:
        return dparser.Reject


def _syntax_error(t):
    del t
    raise AssertionError("unexpected syntax error")


@pytest.fixture
def parser_reject(make_parser):
    mod = types.ModuleType('_t4_grammar')
    for attr, fn in [
        ('d_S', _t4_S), ('d_a', _t4_a), ('d_b', _t4_b),
        ('d_x1', _t4_x1), ('d_x2', _t4_x2),
    ]:
        setattr(mod, attr, fn)
    return make_parser(mod)


def test_spec_reject_resolves_ambiguity(parser_reject):
    result = parser_reject.parse('xxy', syntax_error_fn=_syntax_error)
    assert result.getStructure() == 'S'


# --- test5 grammar: spec_only action wins over spec-rejecting alternative ---

def _t5_h(t):
    'h : h1 | h2'
    return t[0]


def _t5_h1(t, spec_only):
    "h1 : 'a'"
    del t, spec_only
    return 1


def _t5_h2(t, spec):
    "h2 : 'a'"
    del t
    if spec:
        return dparser.Reject
    return 2


@pytest.fixture
def parser_spec_only(make_parser):
    mod = types.ModuleType('_t5_grammar')
    for attr, fn in [('d_h', _t5_h), ('d_h1', _t5_h1), ('d_h2', _t5_h2)]:
        setattr(mod, attr, fn)
    return make_parser(mod)


def test_spec_only_action_wins(parser_spec_only):
    assert parser_spec_only.parse('a').getStructure() == 1
