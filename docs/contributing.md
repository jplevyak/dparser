# Contributing

DParser is developed on GitHub at
[jplevyak/dparser](https://github.com/jplevyak/dparser). Bug reports and
pull requests are welcome.

## Building and testing

```bash
make
make test            # grammar tests and C++ wrapper tests
make test-dsymtab    # symbol table unit tests
(cd python && make && make test)
(cd rust && cargo test --workspace)
```

Grammar tests live in `tests/`. Each `gNN.test.g` comes with inputs
(`gNN.test.g.1`, ...) and expected outputs (`gNN.test.g.1.check`). To add
a test, add a grammar and inputs, run `./parser_tests`, check the
resulting `.out` files, and copy them to `.check`.

The source is formatted with `clang-format` (see `.clang-format`).

## Documentation

This site is built with [MkDocs](https://www.mkdocs.org/) and the
[Material](https://squidfunk.github.io/mkdocs-material/) theme from the
`docs/` directory, and published by GitHub Actions. To preview it:

```bash
pip install mkdocs-material
mkdocs serve
```

then open <http://127.0.0.1:8000/>.

--8<-- "CONTRIBUTING.md"
