"""Threaded state: actions taking a `state` argument get a one-element list
holding the current state.  Speculative actions may replace state[0]; the
new value is seen by everything to the right on that parse path only, and
paths whose states differ are kept apart."""

import dataclasses
import sys
import types

import pytest

from dparser import Reject, SyntaxErr


def _module(name, **fns):
    mod = types.ModuleType(name)
    for k, v in fns.items():
        setattr(mod, k, v)
    return mod


# break is legal only inside a loop: the state is the loop depth.

def d_program(t):
    '''program : stmt*'''
    return t[0]


def d_while(t):
    '''stmt : 'while' enter stmt leave'''
    return ['while', t[2]]


def d_break(t, spec, state):
    '''stmt : 'break' '''
    if spec and not state[0]:
        return Reject
    return 'break'


def d_x(t):
    '''stmt : 'x' '''
    return 'x'


def d_enter(t, spec, state):
    '''enter : '''
    if spec:
        state[0] = (state[0] or 0) + 1


def d_leave(t, spec, state):
    '''leave : '''
    if spec:
        state[0] = state[0] - 1


@pytest.fixture
def loop_parser(make_parser):
    return make_parser(_module('_state_loop', d_program=d_program, d_while=d_while, d_break=d_break,
                               d_x=d_x, d_enter=d_enter, d_leave=d_leave))


@pytest.mark.parametrize('text,ok', [
    ('while break', True),
    ('break', False),
    ('while x break', False),
    ('while while break', True),
    ('while while break break', False),
])
def test_break_in_loop(loop_parser, text, ok):
    if ok:
        loop_parser.parse(text, initial_state=0)
    else:
        with pytest.raises(SyntaxErr):
            loop_parser.parse(text, initial_state=0)


def test_initial_state_is_released(loop_parser):
    initial = ('initial', object())
    before = sys.getrefcount(initial)
    for _ in range(3):
        loop_parser.parse('x', initial_state=initial)
    assert sys.getrefcount(initial) == before


@dataclasses.dataclass(frozen=True)
class Mode:
    name: str


# Two readings of 'b' that end with different states.

def d_top(t):
    '''top : alt'''
    return t[0]


def d_one(t, spec, state):
    '''alt : 'b' '''
    if spec:
        state[0] = Mode('one')  # a new, equal object each time: interned
    return 'one'


def d_two(t, spec, state):
    '''alt : 'b' '''
    if spec:
        state[0] = Mode('two')
    return 'two'


@pytest.fixture
def top_parser(make_parser):
    return make_parser(_module('_state_top', d_top=d_top, d_one=d_one, d_two=d_two))


def test_different_final_states_reach_ambiguity_fn(top_parser):
    seen = []

    def ambiguity(nodes):
        seen.append(sorted(n.state.name for n in nodes))
        return nodes[0]

    top_parser.parse('b', ambiguity_fn=ambiguity)
    assert seen == [['one', 'two']]


def test_prefer_state_chooses(top_parser):
    rank = {'one': 1, 'two': 2}

    def ambiguity(nodes):
        raise AssertionError('prefer_state should have chosen')

    def prefer(a, b):
        return rank[a.name] - rank[b.name]

    r = top_parser.parse('b', ambiguity_fn=ambiguity, prefer_state=prefer)
    assert r.getStructure() == 'two'


# A whitespace function that reads the state: '#' comments are allowed only
# once a 'hash' item has been reduced.

def d_items(t):
    '''items : item*'''
    return t[0]


def d_item(t, spec, state):
    '''item : 'hash' | 'w' '''
    if spec and t[0] == 'hash':
        state[0] = 'hash'
    return t[0]


def skip(loc, state):
    buf, i = loc.buf, loc.s
    while i < len(buf):
        c = buf[i:i + 1]
        if c in (b' ', b'\n'):
            i += 1
        elif c == b'#' and state == 'hash':
            while i < len(buf) and buf[i:i + 1] != b'\n':
                i += 1
        else:
            break
    loc.s = i


@pytest.fixture
def ws_parser(make_parser):
    return make_parser(_module('_state_ws', d_items=d_items, d_item=d_item))


def test_whitespace_reads_state(ws_parser):
    ws_parser.parse('hash w # comment\n w', initial_skip_space_fn=skip)
    with pytest.raises(SyntaxErr):
        ws_parser.parse('w # comment\n hash w', initial_skip_space_fn=skip)


def test_unhashable_state_rejects(make_parser):
    def d_s(t, spec, state):
        '''s : 'u' '''
        if spec:
            state[0] = ['not', 'hashable']

    p = make_parser(_module('_state_unhashable', d_s=d_s))
    with pytest.raises(SyntaxErr):
        p.parse('u')
