"""Tests for nodes/this argument access and parse node attributes, converted from test7.py."""

import sys
import pytest


_captured = {}


def d_start(t, nodes, this):
    'start : noun verb'
    del t
    _captured['noun'] = nodes[0]
    _captured['this'] = this


def d_noun(t, this):
    "noun : 'cat'"
    del this
    return t[0]


def d_verb(t, this):
    "verb : 'flies'"
    del this
    return t[0]


@pytest.fixture
def parser(make_parser):
    _captured.clear()
    return make_parser(sys.modules[__name__])


def test_parse_node_buf_slices(parser):
    parser.parse('cat flies')

    noun = _captured['noun']
    this = _captured['this']
    buf = noun.buf

    assert buf[noun.start_loc.s:noun.end] == b'cat'
    assert buf[noun.end:noun.end + 1] == b' '
    assert buf[noun.end_skip:noun.end_skip + 5] == b'flies'
    assert buf[this.start_loc.s:this.end] == b'cat flies'


def test_parse_node_location(parser):
    parser.parse('cat flies')

    noun = _captured['noun']
    assert isinstance(noun.start_loc.line, int)
    assert isinstance(noun.start_loc.col, int)


def test_this_node_spans_full_input(parser):
    parser.parse('cat flies')

    this = _captured['this']
    buf = this.buf
    assert buf[this.start_loc.s:this.end] == b'cat flies'
