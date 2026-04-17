"""Tests for string replacement via the s argument, converted from test6.py."""

import sys
import pytest


def stringify(s):
    if not isinstance(s, str):
        return ''.join(map(stringify, s))
    return s


def d_add1(t, s):
    "add : add '%' exp"
    s[1] = '+ '
    del t


def d_add2(t, s):
    "add : exp"
    del t, s


def d_exp(t):
    'exp : "[0-9]+" '
    del t


@pytest.fixture
def parser(make_parser):
    return make_parser(sys.modules[__name__])


def test_percent_replaced_with_plus(parser):
    result = parser.parse('1 % 2 % 3')
    assert stringify(result.getStringLeft()) == '1 + 2 + 3'


def test_single_replacement(parser):
    result = parser.parse('1 % 2')
    assert stringify(result.getStringLeft()) == '1 + 2'


def test_no_replacement(parser):
    result = parser.parse('42')
    assert stringify(result.getStringLeft()) == '42'
