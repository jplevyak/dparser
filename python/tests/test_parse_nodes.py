"""Tests for nodes/this argument access and parse node attributes, converted from test7.py."""

import types
import pytest


@pytest.fixture
def parser_with_captures(make_parser):
    captured = {}

    def d_start(t, nodes, this):
        'start : noun verb'
        del t
        captured['noun'] = nodes[0]
        captured['this'] = this

    def d_noun(t, this):
        "noun : 'cat'"
        del this
        return t[0]

    def d_verb(t, this):
        "verb : 'flies'"
        del this
        return t[0]

    mod = types.ModuleType('_parse_nodes_grammar')
    mod.d_start = d_start
    mod.d_noun = d_noun
    mod.d_verb = d_verb
    return make_parser(mod), captured


def test_parse_node_buf_slices(parser_with_captures):
    parser, captured = parser_with_captures
    parser.parse('cat flies')

    noun = captured['noun']
    this = captured['this']
    buf = noun.buf

    assert buf[noun.start_loc.s:noun.end] == b'cat'
    assert buf[noun.end:noun.end + 1] == b' '
    assert buf[noun.end_skip:noun.end_skip + 5] == b'flies'
    assert buf[this.start_loc.s:this.end] == b'cat flies'


def test_parse_node_location(parser_with_captures):
    parser, captured = parser_with_captures
    parser.parse('cat flies')

    noun = captured['noun']
    assert isinstance(noun.start_loc.line, int)
    assert isinstance(noun.start_loc.col, int)


def test_this_node_spans_full_input(parser_with_captures):
    parser, captured = parser_with_captures
    parser.parse('cat flies')

    this = captured['this']
    buf = this.buf
    assert buf[this.start_loc.s:this.end] == b'cat flies'
