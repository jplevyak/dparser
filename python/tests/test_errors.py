"""Tests for parse error behavior: SyntaxErr and syntax_error_fn.

Key findings:
- Invalid input always raises dparser.SyntaxErr.
- syntax_error_fn is only invoked when error_recovery=True is passed to parse();
  without it the C parser fails immediately without calling the callback.
- Even with error_recovery=True and a syntax_error_fn, SyntaxErr is still raised
  after the callback returns — the callback is for observing/logging, not suppressing.
- The DLoc passed to the callback has s/line/col/buf attributes pinpointing the
  error position in the input buffer.
- Exceptions raised from syntax_error_fn do not propagate: Cython's noexcept
  declaration routes them through sys.unraisablehook instead.
"""

import sys
import pytest
import dparser


def d_S(t):
    '''S : d '+' d'''
    return t[0] + t[2]


def d_number(t):
    '''d : "[0-9]+" '''
    return int(t[0])


@pytest.fixture
def parser(make_parser):
    return make_parser(sys.modules[__name__])


def test_invalid_input_raises_syntax_err(parser):
    with pytest.raises(dparser.SyntaxErr):
        parser.parse('not valid')


def test_empty_input_raises_syntax_err(parser):
    with pytest.raises(dparser.SyntaxErr):
        parser.parse('')


def test_incomplete_input_raises_syntax_err(parser):
    with pytest.raises(dparser.SyntaxErr):
        parser.parse('5+')


def test_syntax_error_fn_not_called_without_error_recovery(parser):
    called = []
    try:
        parser.parse('5+x', syntax_error_fn=lambda loc: called.append(loc))
    except dparser.SyntaxErr:
        pass
    assert not called


def test_syntax_error_fn_called_with_error_recovery(parser):
    called = []
    try:
        parser.parse('5+x', syntax_error_fn=lambda loc: called.append(loc),
                     error_recovery=True)
    except dparser.SyntaxErr:
        pass
    assert len(called) == 1


def test_syntax_error_fn_still_raises_with_error_recovery(parser):
    with pytest.raises(dparser.SyntaxErr):
        parser.parse('5+x', syntax_error_fn=lambda loc: None,
                     error_recovery=True)


def test_syntax_error_fn_loc_points_to_error_position(parser):
    locs = []
    try:
        parser.parse('5+x', syntax_error_fn=locs.append, error_recovery=True)
    except dparser.SyntaxErr:
        pass
    loc = locs[0]
    assert loc.buf == b'5+x'
    assert loc.s == 2       # 'x' is at index 2
    assert loc.line == 1
    assert loc.col == 2


def test_syntax_error_fn_exception_does_not_propagate(parser):
    # my_syntax_error_fn is declared `noexcept` in dparser.pyx, so any exception
    # raised from the callback is reported via sys.unraisablehook instead of
    # propagating.  SyntaxErr still raises from the native parse failure.
    unraised = []
    original_hook = sys.unraisablehook
    sys.unraisablehook = unraised.append
    try:
        def cb(loc):
            raise RuntimeError('should not propagate')
        with pytest.raises(dparser.SyntaxErr):
            parser.parse('5+x', syntax_error_fn=cb, error_recovery=True)
    finally:
        sys.unraisablehook = original_hook

    assert unraised, "expected callback exception to reach sys.unraisablehook"
    assert isinstance(unraised[0].exc_value, RuntimeError)
