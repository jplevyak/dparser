"""Tests for basic arithmetic parsing, converted from test.py."""

import sys
import pytest


def d_S(t):
    '''S : d '+' d'''
    return t[0] + t[2]


def d_number(t):
    '''d : "[0-9]+" '''
    return int(t[0])


def _skip_hello(loc):
    while (loc.s < len(loc.buf) and
           loc.buf[loc.s:loc.s + len('hello')] == b'hello'):
        loc.s = loc.s + len('hello')


@pytest.fixture
def parser(make_parser):
    return make_parser(sys.modules[__name__])


def test_addition(parser):
    assert parser.parse('87+5').getStructure() == 92


def test_addition_with_skip_space(parser):
    result = parser.parse('87+5', initial_skip_space_fn=_skip_hello)
    assert result.getStructure() == 92


def test_partial_parse_with_offset_and_skip(parser):
    result = parser.parse(
        'hi10hello+3hellohi',
        buf_offset=2,
        partial_parses=1,
        initial_skip_space_fn=_skip_hello,
    )
    assert result.getStructure() == 13
