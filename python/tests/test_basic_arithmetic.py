"""Tests for basic arithmetic parsing, converted from test.py."""

import sys
import pytest
from dparser import Parser


def d_S(t):
    '''S : d '+' d'''
    return t[0] + t[2]


def d_number(t):
    '''d : "[0-9]+" '''
    return int(t[0])


def _skip_hello(loc):
    while loc.buf.startswith(b'hello', loc.s):
        loc.s += len(b'hello')


@pytest.fixture
def parser(tmp_path):
    return Parser(
        modules=sys.modules[__name__],
        parser_folder=str(tmp_path),
    )


def test_addition(parser):
    assert parser.parse('87+5').getStructure() == 92


def test_addition_with_skip_space(parser):
    result = parser.parse('87hello+5', initial_skip_space_fn=_skip_hello)
    assert result.getStructure() == 92


def test_partial_parse_with_offset_and_skip(parser):
    result = parser.parse(
        'hi10hello+3hellohi',
        buf_offset=2,
        partial_parses=1,
        initial_skip_space_fn=_skip_hello,
    )
    assert result.getStructure() == 13
