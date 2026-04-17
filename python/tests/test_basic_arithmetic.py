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


def test_buf_offset_skips_prefix_bytes(parser):
    # buf_offset skips arbitrary bytes, not just whitespace
    assert parser.parse('xx10+3', buf_offset=2).getStructure() == 13


def test_partial_parses_stops_at_first_complete_parse(parser):
    # trailing content that the grammar can't consume is silently ignored
    assert parser.parse('10+3junk', partial_parses=1).getStructure() == 13


def test_partial_parse_with_offset_and_skip(parser):
    # combined: buf_offset skips prefix, initial_skip_space_fn treats 'hello'
    # as inter-token whitespace, partial_parses=1 tolerates the trailing 'hi'
    result = parser.parse(
        'hi10hello+3hellohi',
        buf_offset=2,
        partial_parses=1,
        initial_skip_space_fn=_skip_hello,
    )
    assert result.getStructure() == 13
