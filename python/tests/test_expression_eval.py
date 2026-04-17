"""Tests for expression evaluation with precedence and ambiguity, converted from test2.py and test3.py."""

import sys
import types
import pytest


# --- test2 grammar: operator precedence with ambiguity resolution ---

def d_add(t):
    '''add : add '+' mul
           | mul'''
    if len(t) == 1:
        return t[0]
    return t[0] + t[2]


def d_mul(t):
    '''mul : mul '*' exp
           | exp'''
    if len(t) == 1:
        return t[0]
    return t[0] * t[2]


def d_exp(t):
    '''exp : number1
           | number2
           | '(' add ')' '''
    if len(t) == 1:
        return int(t[0])
    return t[1]


def d_number1(t):
    '''number1 : number'''
    return t[0]


def d_number2(t):
    '''number2 : number'''
    return t[0]


def d_number(t):
    '''number : "[0-9]+"'''
    return t[0]


def ambiguity_func(v):
    return v[0]


def d_whitespace(t, spec):
    "whitespace : ( ' ' | '\\t' )*"
    del t, spec


@pytest.fixture
def parser(make_parser):
    return make_parser(sys.modules[__name__], make_grammar_file=True)


def test_precedence_and_parens(parser):
    result = parser.parse('1  +2* (3+ 4+5)', ambiguity_fn=ambiguity_func)
    assert result.getStructure() == 25


def test_addition(parser):
    result = parser.parse('1+2', ambiguity_fn=ambiguity_func)
    assert result.getStructure() == 3


def test_multiplication(parser):
    result = parser.parse('2*3', ambiguity_fn=ambiguity_func)
    assert result.getStructure() == 6


# --- test3 grammar: nodes argument; isolated module to avoid rule name conflicts ---

def _t3_add1(t):
    "add : add '+' mul"
    return t[0] + t[2]


def _t3_add2(t, nodes):
    "add : mul"
    del t
    return nodes[0].user.t


def _t3_mul1(t):
    "mul : mul '*' exp"
    return t[0] * t[2]


def _t3_mul2(t):
    "mul : exp"
    return t[0]


def _t3_exp1(t):
    'exp : "[0-9]+"'
    return int(t[0])


def _t3_exp2(t):
    "exp : '(' add ')' "
    return t[1]


@pytest.fixture
def parser_nodes(make_parser):
    mod = types.ModuleType('_t3_grammar')
    for attr, fn in [
        ('d_add1', _t3_add1), ('d_add2', _t3_add2),
        ('d_mul1', _t3_mul1), ('d_mul2', _t3_mul2),
        ('d_exp1', _t3_exp1), ('d_exp2', _t3_exp2),
    ]:
        setattr(mod, attr, fn)
    return make_parser(mod)


def test_nodes_argument(parser_nodes):
    assert parser_nodes.parse('3*(3+4)').getStructure() == 21
