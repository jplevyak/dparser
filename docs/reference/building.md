# Building and Integrating

## Compiling a parser

A DParser-based program has three parts: the generated tables, your driver
and the runtime library.

```bash
make_dparser my.g                     # writes my.g.d_parser.c
cc -c my.g.d_parser.c                 # the tables and actions
cc -c main.c                          # your driver
cc -o my main.o my.g.d_parser.o -ldparse
```

If DParser is installed under a non-default prefix, add
`-I$PREFIX/include` when compiling and `-L$PREFIX/lib` when linking.

If DParser was built with the Boehm garbage collector (`D_USE_GC=1`), link
with `-ldparse_gc -lgc` instead.

## With make

```make
CFLAGS += -I/usr/local/include
LDLIBS += -L/usr/local/lib -ldparse

my: main.o my.g.d_parser.o

%.g.d_parser.c: %.g
	make_dparser $<
```

## Several grammars in one program

Give each grammar its own identifier so their tables don't collide:

```bash
make_dparser -i expr expr.g     # defines parser_tables_expr
make_dparser -i config config.g # defines parser_tables_config
```

```c
extern D_ParserTables parser_tables_expr, parser_tables_config;
```

Each generated file also defines its action functions with the
identifier in their names, so the files can be linked together.

## C++

Generated files can be compiled as C++ when the actions are C++: name them
with `make_dparser -X cpp`, or compile the `.c` file with `-x c++`. All
DParser headers have `extern "C"` guards. See [C++ Wrapper](cpp.md).

## CMake

The source tree includes a `CMakeLists.txt`, which builds `make_dparser`,
the `dparse` and `mkdparse` libraries and some test programs, and
installs a CMake package under `lib/cmake/dparser`.

```bash
cmake -S . -B build
cmake --build build
cmake --install build --prefix /usr/local
```

The package provides a `dparse_generate()` function for running
`make_dparser` as a build step:

```cmake
dparse_generate(${CMAKE_CURRENT_SOURCE_DIR}/calc.g
                ${CMAKE_CURRENT_BINARY_DIR}/calc.g.d_parser.c)
add_executable(calc main.c ${CMAKE_CURRENT_BINARY_DIR}/calc.g.d_parser.c)
```

!!! note
    The Makefile is the primary, best-tested build. The CMake package is
    less complete: its install step currently copies only `d.h` and
    `dparse.h` (not `dparse_tables.h` and `dsymtab.h`, which `dparse.h`
    includes), and the generated `dparser-config.cmake` does not import
    the `dparser::` targets. Until that is fixed, you may need to add the
    DParser source directory to your include path and refer to
    `make_dparser` and `libdparse` directly.

## Python and Rust

- Python: `pip install .` from the source tree. See
  [Python API](python.md).
- Rust: depend on the `dparser` crate in `rust/`. See [Rust](rust.md).

## Running the tests

```bash
make test            # grammar tests, C++ wrapper tests
make test-dsymtab    # symbol table unit tests
cd python && make test
cd rust && cargo test --workspace
```

The grammar tests are in `tests/`. Each `gNN.test.g` has inputs
`gNN.test.g.1`, `.2`, ... and expected outputs in `.check` files.
`./parser_tests` runs them all; `./parser_tests "g28.test.g"` runs one.
