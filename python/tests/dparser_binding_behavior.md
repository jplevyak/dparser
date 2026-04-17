# dparser Python Binding — Interesting Findings

Notes from writing the pytest suite. These are non-obvious behaviors that
aren't documented elsewhere.

---

## `partial_parses=1` silently ignores trailing content

`partial_parses=1` stops after the first complete parse and leaves the rest of
the buffer unconsumed — no error, no skip function required.

```python
parser.parse('10+3junk', partial_parses=1).getStructure()  # 13, not an error
```

This is distinct from needing `initial_skip_space_fn` to handle trailing
content: `partial_parses` doesn't attempt to consume the remainder at all.

---

## `buf_offset` skips arbitrary bytes, not just whitespace

`buf_offset=N` tells the parser to start reading from byte N of the buffer.
The skipped prefix doesn't need to be whitespace or otherwise valid grammar
input.

```python
parser.parse('xx10+3', buf_offset=2).getStructure()  # 13
```

The combined test in `test_basic_arithmetic.py` uses `initial_skip_space_fn`
alongside `buf_offset`, which obscures this: the skip function is only needed
to handle `hello` sequences **between tokens**, not to justify the prefix.

---

## `ambiguity_fn` receives `DParseNode` objects, not action return values

When two grammar rules match the same input, dparser calls `ambiguity_fn` with
a list of `DParseNode` alternatives. The function must return one of those
exact node objects (identity check, not equality) to select the parse to keep.

Action return values (`user.t`) are **not yet populated** at call time — they
are `None` for all nodes. Disambiguation must be done by choosing among the
node objects themselves.

```python
def pick_first(v):
    return v[0]   # v is a list of DParseNode; return one of them by identity

parser.parse('a', ambiguity_fn=pick_first).getStructure()
```

Selecting different nodes produces different final `getStructure()` values,
because the chosen node determines which subtree's actions run:

```python
results = {
    parser.parse('a', ambiguity_fn=lambda v: v[0]).getStructure(),
    parser.parse('a', ambiguity_fn=lambda v: v[-1]).getStructure(),
}
assert results == {1, 2}   # the two alternatives really do differ
```

---

## `dparser.AmbiguityException` does not propagate from `ambiguity_fn`

`dparser.my_ambiguity_func` is documented as raising `AmbiguityException` to
signal unresolved ambiguity. In practice it is swallowed: the Cython callback
(`my_ambiguity_fn` in `dparser.pyx`) wraps the call in `try/except Exception`
and falls back to returning `v[0]` on any exception.

```python
# This does NOT raise — the exception is caught inside the Cython callback
parser.parse('a', ambiguity_fn=dparser.my_ambiguity_func).getStructure()  # returns a value
```

To raise on ambiguity, raise from outside the callback:

```python
result = [None]

def detecting_fn(v):
    result[0] = 'ambiguous'
    return v[0]

parser.parse('a', ambiguity_fn=detecting_fn)
if result[0] == 'ambiguous':
    raise RuntimeError('ambiguous parse')
```

---

## Without `ambiguity_fn`, an ambiguous grammar loops indefinitely

If `ambiguity_fn` is not provided and the grammar is ambiguous for the given
input, the C parser loops at the native level. There is no timeout and no
Python exception — the process simply hangs.

Always supply an `ambiguity_fn` when parsing with a grammar that can produce
ambiguous parses.

---

## `dparser.SyntaxErr` is the exception for invalid input

Parse failure raises `dparser.SyntaxErr` (not `SyntaxError`). It is not a
subclass of `dparser.ParsingException` — the two exception classes are
independent. Empty and incomplete input both raise it too.

```python
with pytest.raises(dparser.SyntaxErr):
    parser.parse('not valid input for this grammar')
```

---

## `syntax_error_fn` is only called when `error_recovery=True`

Without `error_recovery=True`, the C parser exits immediately on failure
without invoking the callback at all. Passing `syntax_error_fn` alone does
nothing observable.

```python
# callback is never called without error_recovery=True
parser.parse('5+x', syntax_error_fn=lambda loc: ...)  # callback silently ignored
```

With `error_recovery=True`, the callback fires with a `DLoc` that has `s`,
`line`, `col`, and `buf` attributes pointing to the error position:

```python
locs = []
try:
    parser.parse('5+x', syntax_error_fn=locs.append, error_recovery=True)
except dparser.SyntaxErr:
    pass
# locs[0].s == 2, locs[0].col == 2, locs[0].buf == b'5+x'
```

`SyntaxErr` is still raised after the callback returns — the callback is for
observation only, not suppression.

---

## Exceptions raised from `syntax_error_fn` are swallowed (unraisable)

Unlike `ambiguity_fn` (which wraps the user callback in an explicit
`try/except Exception` and falls back to `v[0]`), `syntax_error_fn`'s wrapper
`my_syntax_error_fn` in `dparser.pyx` is declared `cdef void … noexcept with
gil` and has no try/except.  Cython's `noexcept` contract means any Python
exception raised from inside is routed through `sys.unraisablehook` — by
default printing `Exception ignored in: 'dparser.my_syntax_error_fn'` to
stderr — and the C caller continues as if the callback had returned
normally.  The exception does **not** surface as the exception raised by
`parse()`; `SyntaxErr` still raises from the native parse failure.

```python
def cb(loc):
    raise RuntimeError('boom')   # never propagates to the parse() caller

try:
    parser.parse('5+x', syntax_error_fn=cb, error_recovery=True)
except dparser.SyntaxErr:
    pass    # this is the exception that surfaces; RuntimeError is lost
```

Use list-capture or flag-setting patterns to signal from these callbacks,
not raised exceptions.
