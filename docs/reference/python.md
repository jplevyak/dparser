# Python API

The `dparser` module builds parsers from grammar rules written in the
docstrings of Python functions. For an introduction see the
[Python tutorial](../tutorial/python.md).

```python
import dparser
from dparser import Parser, Reject
```

## Writing actions

Any module-level function whose name starts with `d_` is an action. Its
docstring contains one or more rules, in the [grammar syntax](grammar.md)
without action code. Several rules can be separated by `|`, and several
productions by `;`:

```python
def d_grammar(t):
    '''sentence : noun verb ;
       noun : 'dog' | 'cat' ;
       verb : 'runs'
    '''
```

The first rule (in source order) is the start symbol. Declarations such as
`${declare longest_match}` can appear in docstrings too. Use raw strings
(`r'...'`) for docstrings with backslashes.

### Arguments

The first parameter receives the list of the rule's element values: the
return value of each nonterminal's action, or the matched text of each
terminal. EBNF elements such as `x*` give a list. Additional parameters
are recognized **by name**:

| Name | Value |
|---|---|
| `spec` | The action also runs speculatively. `spec` is true when it does. Return `Reject` to reject the parse. |
| `spec_only` | The action runs only speculatively; its speculative return value is kept as the final value. |
| `g` | A one-element list holding the global state. Assign `g[0]` to change it; the value carries over to later actions in the same parse and starts as `None`. |
| `s` | The element texts, as a nested list, including whitespace. |
| `nodes` | A list of `DParseNode` objects for the elements. |
| `this` | The `DParseNode` for the node being built. |
| `parser` | The `Parser` object. |
| `state` | A one-element list holding the [threaded state](#threaded-state). Speculative actions may replace `state[0]`. Makes the action run speculatively too, like `spec`. |

Without `spec`, `spec_only` or `state`, an action runs only on the final parse.

## `Parser`

```python
Parser(modules=None, parser_folder=None,
       file_prefix="d_parser_mach_gen", make_grammar_file=False)
```

| Argument | Description |
|---|---|
| `modules` | Where to find `d_` functions: a module, a list of modules or a dictionary. Defaults to the caller's module. |
| `parser_folder` | Directory for the cached tables. Defaults to the directory of the running script. |
| `file_prefix` | Name prefix for the cache files. |
| `make_grammar_file` | Also write the assembled grammar to `<prefix>.g`, which helps when debugging. |

Building the tables takes time, so they are cached in
`<parser_folder>/<file_prefix>.g.d_parser.dat`, with a checksum in
`<file_prefix>.g.md5`. They are rebuilt when the grammar changes.

Raises `dparser.NoActionsFound` if there are no `d_` functions.

### `Parser.parse`

```python
parser.parse(buf, buf_offset=0, initial_skip_space_fn=None,
             syntax_error_fn=None, ambiguity_fn=None, make_token=None,
             dont_fixup_internal_productions=False, fixup_EBNF_productions=False,
             dont_merge_epsilon_trees=False, commit_actions_interval=100,
             error_recovery=False, print_debug_info=0, partial_parses=False,
             dont_compare_stacks=False,
             dont_use_greediness_for_disambiguation=False,
             dont_use_height_for_disambiguation=False, start_symbol='',
             initial_state=None, prefer_state=None, keep_tree=False)
```

| Argument | Description |
|---|---|
| `buf` | The text to parse, `str` or `bytes`. |
| `buf_offset` | Start parsing at this byte offset. |
| `initial_skip_space_fn` | A whitespace function. It receives a `DLoc` and should advance `loc.s`. If it takes a second argument, it also receives the [threaded state](#threaded-state). |
| `syntax_error_fn` | Called with a `DLoc` on each syntax error. `dparser.my_syntax_error_func` raises a `SyntaxErr` showing the error in context. |
| `ambiguity_fn` | Called with a list of `DParseNode` alternatives; must return one of them (the same object). If it raises, the first alternative is used. |
| `make_token` | A function applied to the text of every terminal; its result is what actions see in `t` instead of the string. |
| `start_symbol` | The name of the nonterminal to parse, instead of the first rule. Raises `ValueError` for an unknown name. |
| `initial_state` | The [threaded state](#threaded-state) at the start: any hashable object, or `None`. |
| `prefer_state` | `prefer_state(a, b)` returns >0 to prefer state `a`, <0 to prefer `b` and 0 for neither; it chooses between parses that end with different states. |
| `keep_tree` | Keep the parse tree, as [`Node`](#node)s, for `getTree()`. |
| `print_debug_info` | `1` prints a line for every action call (marked `???` when speculative); `2` prints final actions only. |
| `error_recovery` | Recover from syntax errors and continue. Off by default in Python. |
| `partial_parses` | Accept a parse of a prefix of the input. |
| other options | As the [C parser options](c-api.md#options). |

Returns a `ParsedStructure`:

| Method | Returns |
|---|---|
| `getStructure()` | The value of the root node: the start rule's action result. |
| `getStringLeft()` | The input after the end of the parse: empty unless `partial_parses` stopped early. |
| `getTree()` | With `keep_tree=True`, the root [`Node`](#node) of the parse tree; otherwise `None`. |
| `getString()` | The parsed text as a nested list, as actions see it in `s`, including any edits actions made to it. Use this to rewrite text. |

After a parse, `parser.globals` holds the final global state (see the `g`
argument).

Raises `dparser.SyntaxErr` if the parse fails.

## Classes

### `DParseNode`

| Attribute | Description |
|---|---|
| `symbol` | The symbol number. |
| `start_loc` | A `DLoc` for the start of the node. |
| `end`, `end_skip` | Byte offsets of the end of the text, without and with trailing whitespace. |
| `buf` | The input as `bytes`. |
| `user.t`, `user.s` | The node's value and text structure, once its action has run. |
| `state`, `state_before` | The [threaded state](#threaded-state) after and before the node. |
| `str(node)` | The node's text. |

### `Node`

A node of a tree kept with `keep_tree=True`. It outlives the parse, unlike
`DParseNode`, and is what [attributes](attributes.md#python-dparser_attrs)
work on.

| Attribute | Description |
|---|---|
| `symbol`, `name` | The symbol number and name. |
| `text` | The node's text. |
| `start`, `end`, `line` | Byte offsets of the text, and the line it starts on. |
| `children` | The child `Node`s, flattened as actions see them. |
| `value` | What the node's action returned (for a terminal, its text). |
| `action` | The `d_` function whose rule built the node, or `None`. |
| `alternative` | Which of that function's rules built it (from 0), or -1. |

### `DLoc`

| Attribute | Description |
|---|---|
| `s` | Byte offset in the buffer. Assignable, in whitespace functions. |
| `line`, `col` | Line (from 1) and column (from 0). |
| `buf` | The input as `bytes`. |

## Exceptions and markers

| Name | Meaning |
|---|---|
| `Reject` | Return it from a speculative action to reject the parse. |
| `SyntaxErr` | The parse failed. |
| `AmbiguityException` | Raised by `my_ambiguity_func`. |
| `NoActionsFound` | `Parser()` found no `d_` functions. |
| `ParsingException` | Base class for parsing errors. |

## Threaded state

[Threaded state](threaded-state.md) can be any hashable Python object (a
number, a tuple, a frozen dataclass); `None` means no state. An action
that takes a `state` argument gets a one-element list. In the speculative
run (`spec` true) it holds the current state, and assigning `state[0]`
changes the state seen by everything to the right on this parse path. In
the final run it holds the state after the node, and must not be changed.

```python
def d_while(t):
    '''stmt : 'while' enter stmt leave'''

def d_break(t, spec, state):
    '''stmt : 'break' '''
    if spec and not state[0]:
        return Reject

def d_enter(t, spec, state):
    '''enter : '''
    if spec:
        state[0] = (state[0] or 0) + 1

def d_leave(t, spec, state):
    '''leave : '''
    if spec:
        state[0] -= 1
```

States are compared with `==` and `hash()`, so don't change a state object
in place; make a new one. An unhashable state rejects the parse path.

## Whitespace

By default the C-like whitespace handler is used, which treats `#`
at the start of a line as a possible `#line` directive. To handle
whitespace yourself, define a `whitespace` production:

```python
def d_whitespace(t):
    'whitespace : "[ \\t\\n]*"'
```

or pass `initial_skip_space_fn`:

```python
def skip(loc):
    while loc.s < len(loc.buf) and loc.buf[loc.s:loc.s+1] in b' \t\n':
        loc.s += 1

parser.parse(text, initial_skip_space_fn=skip)
```
