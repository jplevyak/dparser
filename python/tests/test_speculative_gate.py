"""Which pass each kind of action runs in.

- An action without `spec` or `spec_only` runs in the final pass only, so
  it never sees parse paths that are abandoned.
- `spec` runs in both passes, with `spec` true in the speculative one.
- `spec_only` runs in the speculative pass only, and the node keeps the
  value it returned.  (It used to behave like a plain action.)
"""

import types


def _module(name, **fns):
    mod = types.ModuleType(name)
    for k, v in fns.items():
        setattr(mod, k, v)
    return mod


def test_plain_actions_never_see_abandoned_paths(make_parser):
    calls = []

    def d_S(t):
        """S : P 'y' | Q 'z'"""

    def d_P(t):
        """P : 'x'"""
        calls.append('P')  # reduced on the 'y' path, which dies at 'z'

    def d_Q(t):
        """Q : 'x'"""
        calls.append('Q')

    parser = make_parser(_module('_gate_plain', d_S=d_S, d_P=d_P, d_Q=d_Q))
    parser.parse('x z')
    assert calls == ['Q']


def test_spec_runs_in_both_passes(make_parser):
    calls = []

    def d_S(t, spec):
        """S : d '+' d"""
        calls.append(('S', spec))
        return t[0] + t[2]

    def d_number(t, spec):
        '''d : "[0-9]+" '''
        calls.append(('d', spec))
        return int(t[0])

    parser = make_parser(_module('_gate_spec', d_S=d_S, d_number=d_number))
    assert parser.parse('87+5').getStructure() == 92
    assert {flag for _, flag in calls} == {0, 1}


def test_spec_only_runs_speculatively_and_keeps_its_value(make_parser):
    calls = []

    def d_S(t):
        """S : d '+' d"""
        calls.append(('S', 'final'))
        return t[0] + t[2]

    def d_number(t, spec_only):
        '''d : "[0-9]+" '''
        calls.append(('d', spec_only))
        return int(t[0])

    parser = make_parser(_module('_gate_spec_only', d_S=d_S, d_number=d_number))
    assert parser.parse('87+5').getStructure() == 92
    assert sorted(flag for name, flag in calls if name == 'd') == [1, 1]
