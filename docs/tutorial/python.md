# 7. Python

The Python binding lets you write a whole parser in Python. There is no
separate grammar file and no C compiler step. Each grammar rule lives in
the docstring of the Python function that is its action.

Install it with `pip install .` from the top of the DParser source tree;
see [Installation](../getting-started/installation.md#python).

## A calculator

```python
from dparser import Parser

def d_add(t):
    "expr : expr '+' expr $left 10 | expr '-' expr $left 10"
    return t[0] + t[2] if t[1] == '+' else t[0] - t[2]

def d_mul(t):
    "expr : expr '*' expr $left 20 | expr '/' expr $left 20"
    return t[0] * t[2] if t[1] == '*' else t[0] / t[2]

def d_paren(t):
    "expr : '(' expr ')'"
    return t[1]

def d_number(t):
    'expr : "[0-9]+"'
    return int(t[0])

parser = Parser()
for text in ["1 + 2 * 3", "(1 + 2) * 3", "10 - 4 - 3"]:
    print(text, "=", parser.parse(text).getStructure())
```

```text
1 + 2 * 3 = 7
(1 + 2) * 3 = 9
10 - 4 - 3 = 3
```

The rules:

- **Every function whose name starts with `d_` is an action.** Its
  docstring holds one or more grammar rules, in the same syntax as a
  `.g` file but without the action code. The function is the action for
  all of them.
- **The first argument, `t`, is a list** with one entry per element of the
  rule: the value an action returned for a nonterminal, or the matched
  text for a terminal. So `t[1]` is `'+'` or `'-'` above.
- **The return value** becomes the value of the node, and so the entry in
  the parent's `t`.
- **`Parser()`** collects the `d_` functions from the calling module, in
  source order. The first rule is the start symbol.
- **`parse(text)`** returns a result object. `getStructure()` gives the
  value of the root.

Use raw strings (`r"..."`) for docstrings that contain backslashes, such as
regular expressions with escapes.

!!! note "Table caching"
    The first time a grammar is used, DParser builds the parse tables and
    caches them in files named `d_parser_mach_gen.g.*` next to your script.
    Later runs reuse them until the grammar changes. Pass
    `Parser(parser_folder=..., file_prefix=...)` to put them elsewhere.

## Extra action arguments

An action can ask for more information by naming extra parameters. The
binding looks at the parameter *names*:

| Parameter | Value |
|---|---|
| `spec` | Makes the action run speculatively too. `spec` is true during speculative runs and false for the final run. |
| `spec_only` | Run only speculatively. The final value is whatever the speculative run returned. |
| `g` | The global state, as a one-element list so the action can replace it. |
| `s` | The text of each element, as a nested list. |
| `nodes` | A list of node objects for the elements, with locations. |
| `this` | The node object for the rule itself. |
| `parser` | The `Parser` object. |

For example, `nodes` gives line and column information:

```python
def d_pair(t, nodes):
    "pair : word '=' word"
    n = nodes[2]
    print("value at line", n.start_loc.line, "col", n.start_loc.col)
    return (t[0], t[2])

def d_word(t):
    'word : "[a-z]+"'
    return t[0]

print(Parser().parse("key =\n  value").getStructure())
```

```text
value at line 2 col 2
('key', 'value')
```

`str(node)` is the node's text. `node.start_loc.s` and `node.end` are byte
offsets into `node.buf`.

## Rejecting a parse

An action that takes `spec` runs speculatively, and can return
`dparser.Reject` to abandon the current parse path, just like `${reject}`
in C. This grammar refuses to accept keywords as names:

```python
import dparser
from dparser import Parser, Reject

KEYWORDS = {"if", "while"}

def d_program(t):
    "program : name+"
    return t[0]

def d_name(t, spec):
    'name : "[a-z]+"'
    if spec and t[0] in KEYWORDS:
        return Reject          # this parse path is abandoned
    return t[0]

p = Parser()
print(p.parse("alpha beta").getStructure())
try:
    p.parse("alpha while")
except dparser.SyntaxErr as e:
    print("SyntaxErr:", e)
```

```text
['alpha', 'beta']
SyntaxErr: syntax error during parse
```

## Errors and ambiguity

- A failed parse raises `dparser.SyntaxErr`. Pass
  `syntax_error_fn=f` to `parse()` to be called with the error location
  first.
- Error recovery is **off** by default in Python. Pass
  `error_recovery=True` to turn it on.
- `ambiguity_fn=f` is called with a list of node objects for the
  alternatives, and must return one of them.

All the `parse()` options are listed in the
[Python API reference](../reference/python.md).

## What you learned

- In Python, grammar rules live in the docstrings of `d_` functions, and
  each function is the action for its rules.
- `t` holds the elements' values, and the return value is the node's value.
- Name extra parameters (`spec`, `nodes`, `s`, ...) to get more
  information, and return `Reject` from a speculative action to abandon a
  parse.

Next: [Attributes after Parsing](attributes.md).
