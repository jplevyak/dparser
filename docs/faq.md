# FAQ

## Using DParser

### How do I access the subnodes for expressions like `S: A*;`?

`A*` is a single element, `$n0`, whose children are the `A`s. Use
`d_get_number_of_children(&$n0)` (or `$#0`) to count them, and
`d_get_child(&$n0, i)` to get each one. See
[Parse Trees](tutorial/parse-trees.md#internal-nodes-for-ebnf) and
`tests/g27.test.g`.

### `dparse` returned `0x1`. What is that?

That is `NO_DPN`, returned on success when `save_parse_tree` is off.
There is no tree to return because it was freed as the final actions ran.
Set `parser->save_parse_tree = 1` before parsing if you need the root
node, for example to read its value.

### My calculator computes the right values but the result is always 0.

The result is the value of the **root** node. If the start production has
no action, the value never gets copied up to it. Give it one:
`statement: expr { $$.value = $0.value; };`.

### How do I parse a file?

Read it into a buffer and pass the buffer and its length:

```c
char *buf = malloc(size);
fread(buf, 1, size, fp);
D_ParseNode *pn = dparse(parser, buf, size);
```

The buffer doesn't need a terminating `'\0'` (unless you have written
your own scanner or whitespace functions that rely on one).

Set `parser->loc.pathname` to the file name for error messages, and keep
the buffer until you are done with the tree.

### Why does my parse "succeed" with errors in the input?

Error recovery is on by default, so `dparse` can return a tree after
recovering from errors. Always check `parser->syntax_errors`. Set
`parser->error_recovery = 0` to stop at the first error.

### My keywords are being parsed as identifiers.

Give identifiers a lower terminal priority:
`identifier: "[a-z]+" $term -1;`. When a keyword and an identifier match
exactly the same text, the higher priority wins. If keywords must never be
identifiers anywhere, use a [tokenizer](reference/terminals.md#tokenizers).

### Why do my final actions run later than I expect?

Final actions run when the parser *commits* to part of the parse, in
batches, not as soon as the text is read. See
[Actions and Commit](internals/actions.md). Set
`parser->commit_actions_interval = 0` to run them as early as possible.

### Why do my speculative actions run more than once, or for things that aren't in the final parse?

That is what speculative actions are: they run while alternatives are
still being explored. Only write to `$$` and the symbol table in them. See
[Speculative Actions](tutorial/speculative-actions.md).

### Where do I keep state that changes as parsing proceeds, like nesting depth?

In the [threaded state](reference/threaded-state.md), `${state}`. Each
parse path has its own, so a speculative action can use it to accept or
reject a parse. Don't keep it in `$g`, which every path shares: a
speculative action can run for a path that is later abandoned, and nothing
undoes what it wrote.

### How do I compute scopes or types after parsing, when information flows down the tree?

Use [attributes](reference/attributes.md): write an equation for each
value, synthesized (from the children) or inherited (from the parent), and
ask for the values you need. They are computed in the right order and
cached. See the [tutorial chapter](tutorial/attributes.md).

### How do I find out where my grammar is ambiguous?

Turn off greediness and height disambiguation, set `d_verbose_level = 1`,
and parse a sample. The default ambiguity handler prints the competing
parses. See [Ambiguity](tutorial/ambiguity.md#seeing-the-alternatives).

### Why doesn't `$n0.end_skip` include the trailing whitespace when `$n0` is a string or regex?

Whitespace is not skipped as part of scanning a string or regex. It is
skipped later, when the new parse state is created. This makes it possible
to change the whitespace handling depending on which terminal was
recognized. The Python grammar uses this to handle implicit line joining:
see the productions `LP`, `RP`, `LB`, `RB`, `LC` and `RC` in
`python.g`.

### `.` in my regular expression doesn't match any character.

DParser regexes have no wildcard; `.` is a literal period. Use a class
such as `[^\n]`. See [Regular expressions](reference/terminals.md#regular-expressions).

### Can I have `$` in my global C code?

In comments and in string and character literals, yes: they are copied
as they are. Elsewhere only `${nterm ...}`, `${string ...}` and
`${pass ...}` are allowed, and any other `$` is an error.

## About DParser

### What is the difference between DParser and ANTLR?

The basic syntax of DParser and ANTLR grammars is very similar. In fact,
the DParser example ANSI C grammar was ported from ANTLR in less than an
hour. Beyond that there are a number of differences:

- DParser is a GLR parser based on the Tomita algorithm, while ANTLR is
  a modified LL(k) (now ALL(*)) parser.
- DParser is table driven, while ANTLR generates directly executable
  parsers.
- DParser is scannerless, while ANTLR uses token streams.
- ANTLR has more predictable performance and is generally faster.

In terms of power, both are very powerful. In theory DParser can handle
any context-free grammar, though not necessarily in linear time, and by
eliminating a separate tokenizer, DParser simplifies grammar composition.
In practice DParser explores all parses with minimal lookahead, which can
be expensive if the parse is (temporarily) ambiguous. ANTLR looks ahead to
avoid unnecessary work.

### Is DParser fast?

For unambiguous or locally ambiguous input, parsing is close to linear in
the input size. Heavily ambiguous grammars cost more, because every
alternative is explored. Priorities on operators are the most effective
way to keep expression grammars fast. See
[The GLR Runtime](internals/glr.md#complexity).

### Which languages can I use DParser from?

C and C++ natively, Python through the bundled Cython binding, and Rust
through the native Rust runtime. Other languages can be added; see
[Contributing](contributing.md).
