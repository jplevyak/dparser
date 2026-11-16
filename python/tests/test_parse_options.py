"""Tests for parse() options restored from the original C binding:
start_symbol, make_token, print_debug_info, and the g (globals) argument."""

import sys
import pytest


def d_program(t):
    "program : stmt+"
    return t[0]


def d_stmt(t):
    "stmt : expr ';'"
    return t[0]


def d_add(t, g):
    "expr : expr '+' expr $left 10"
    g[0] = (g[0] or 0) + 1   # count additions across the whole parse
    return t[0] + t[2]


def d_num(t):
    'expr : "[0-9]+"'
    return int(t[0])


@pytest.fixture
def parser(make_parser):
    return make_parser(sys.modules[__name__])


def test_start_symbol(parser):
    # Parse a bare expression instead of a program.
    assert parser.parse('1 + 2', start_symbol='expr').getStructure() == 3
    assert parser.parse('1 + 2;').getStructure() == [3]


def test_unknown_start_symbol(parser):
    with pytest.raises(ValueError):
        parser.parse('1', start_symbol='nonexistent')


def test_make_token(parser):
    seen = []

    def make_token(text):
        seen.append(text)
        return text

    assert parser.parse('1 + 2;', make_token=make_token).getStructure() == [3]
    assert seen.count('+') == 1 and seen.count(';') == 1


def test_globals_persist_across_actions(parser):
    assert parser.parse('1 + 2 + 3; 4 + 5;').getStructure() == [6, 9]
    assert parser.globals == 3


def test_print_debug_info(parser, capsys):
    parser.parse('1 + 2;', print_debug_info=1)
    out = capsys.readouterr().out
    assert 'd_add' in out and 'd_num' in out
    assert '???' not in out   # these actions don't run speculatively

    parser.parse('1 + 2;', print_debug_info=0)
    assert capsys.readouterr().out == ''
