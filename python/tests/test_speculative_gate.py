"""Regression test for the speculative/final action gate in my_action.

Default actions (those without a `spec` argument) should fire in the final,
non-speculative pass only.  A prior bug inverted the gate:

    if takes_speculative == -1 and not speculative:  # wrong
        return 0

…which caused such actions to fire only during the speculative pass.  This
test uses the `spec_only` argument (which both receives the speculative flag
*and* is governed by the same gate) to observe which pass an action actually
runs in.
"""

import sys
import pytest
from dparser import Parser


_calls = []


def d_S(t, spec_only):
    """S : d '+' d"""
    _calls.append(('S', spec_only))
    return t[0] + t[2]


def d_number(t, spec_only):
    '''d : "[0-9]+" '''
    _calls.append(('d', spec_only))
    return int(t[0])


@pytest.fixture
def parser(tmp_path):
    _calls.clear()
    return Parser(
        modules=sys.modules[__name__],
        parser_folder=str(tmp_path),
    )


def test_default_actions_run_in_final_pass_only(parser):
    assert parser.parse('87+5').getStructure() == 92
    assert _calls, "expected actions to fire"
    assert all(flag == 0 for _, flag in _calls), (
        f"expected every action to fire in the final pass (spec=0), "
        f"got: {_calls}"
    )
