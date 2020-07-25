# DParser FAQ


## 1. How do I access the subnodes for expressions like `S: A*;`?

In this case, `A*` is `$n0` of type `D_ParseNode`.  In `dparse.h` the functions
`d_get_number_of_children(D_ParseNode *)` and `d_get_child(D_ParseNode *, int)`
allow you to get the number of children (**A's**) by calling
`d_get_number_of_children(&$n0)` and individual children by calling
`d_get_child(&$n0, x)`.

See the example in `tests/g27.test.g`.


## 2. Why doesn't `$n0.end_skip` include the trailing whitespace when `$n0` is a string / regex?

Whitespace is not skipped as part of the scan of a string / regex but is done
later (when the new parse state is created).  This makes it possible to change
the whitespace parser as a result of recognition of a particular string /
regex.  This is used in the python grammar to handle implicit line joining.

See the regex-productions `LP` `RP` `LB` `RB` `LC` `RC` in
`test/python.test.g`.


## 3. What is the difference between DParser and ANTLR?

The basic syntax of DParser and ANTLR grammars is very similar.  In fact, the
DParser example ANSI-C grammar was ported from ANTLR in less than an hour.
Beyond that there are a number of differences:
* ANTLR has been developed for over a decade while DParser is relatively young.
* Internally, DParser is a table-driven parser while ANTLR generates directly
  executable parsers.
* DParser is a `GLR` parser based on the Tomita algorithm while ANTLR is
  modified `LL(k)`.
* DParser is scannerless while ANTLR uses token streams.

In terms of power, both DParser and ANTLR are very powerful.  In theory DParser
can handle any context free grammar, though not necessarily in linear time.  In
practice ANTLR is likely to be faster (mostly because it is more mature).

Beyond that you would really have to ask Terence Parr who is more of a hard
core parsing theory guru than I am.
