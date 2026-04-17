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

import types
import pytest


@pytest.fixture
def parser_with_calls(make_parser):
    calls = []

    def d_S(t, spec_only):
        """S : d '+' d"""
        calls.append(('S', spec_only))
        return t[0] + t[2]

    def d_number(t, spec_only):
        '''d : "[0-9]+" '''
        calls.append(('d', spec_only))
        return int(t[0])

    mod = types.ModuleType('_spec_gate_grammar')
    mod.d_S = d_S
    mod.d_number = d_number
    return make_parser(mod), calls


def test_default_actions_run_in_final_pass_only(parser_with_calls):
    parser, calls = parser_with_calls
    assert parser.parse('87+5').getStructure() == 92
    assert calls, "expected actions to fire"
    assert all(flag == 0 for _, flag in calls), (
        f"expected every action to fire in the final pass (spec=0), "
        f"got: {calls}"
    )
