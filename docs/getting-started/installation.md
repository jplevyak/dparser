# Installation

DParser is distributed as source. It builds with any C compiler that
supports C99 or later and GNU `make`.

## Build and install the C library and tools

```bash
git clone https://github.com/jplevyak/dparser.git
cd dparser
make            # use gmake on BSD systems
make test       # optional: run the test suite
sudo make install
```

`make install` copies files under `PREFIX`, which defaults to `/usr/local`:

| Installed file | Location |
|---|---|
| `make_dparser` (the parser generator) | `$PREFIX/bin` |
| `libdparse.a` (the runtime library) | `$PREFIX/lib` |
| `dparse.h`, `dparse_tables.h`, `dsymtab.h`, `dparse_tree.h`, `read_binary.h`, `dparse.hpp` | `$PREFIX/include` |
| `make_dparser.1` (man page) | `$PREFIX/man/man1` |

To install somewhere else, for example into your home directory:

```bash
make install PREFIX=$HOME/.local
```

### Build options

These `make` variables change how the library is compiled:

| Variable | Default | Effect |
|---|---|---|
| `D_OPTIMIZE` | `1` | Compile with `-O3`. |
| `D_DEBUG` | `0` | Compile with `-g` and `D_DEBUG`. |
| `D_PROFILE` | `0` | Compile with `-pg` for profiling. |
| `D_USE_GC` | `0` | Use the Boehm garbage collector. The library is then called `libdparse_gc.a`. |
| `D_LEAK_DETECT` | `0` | Build with leak detection (`-DLEAK_DETECT`). |
| `D_USE_FREELISTS` | `1` | Reuse freed parser nodes through free lists. Set it to an empty value (`make D_USE_FREELISTS=`) to use plain `malloc`/`free`, which gives cleaner results under valgrind. |

For example, a debug build: `make D_DEBUG=1 D_OPTIMIZE=0`.

## Python

The Python binding is a Cython extension. It needs Python 3.10 or later and
a C compiler. From the top of the source tree:

```bash
pip install .
```

To build it in place for development instead, run `make` in the `python/`
directory; this builds the extension module next to `python/dparser.pyx`.
The tests run with `make test` in the same directory. See the
[Python tutorial](../tutorial/python.md) to get started.

## Rust

The Rust crate lives in `rust/`. It contains a native Rust parsing runtime
and a build-time helper that runs `make_dparser` for you. Build and test it
with Cargo:

```bash
cd rust
cargo build --workspace
cargo test --workspace
```

See the [Rust page](../reference/rust.md) for how to use it from your own
crate.

## CMake

A `CMakeLists.txt` is also provided, along with a `dparse_generate()`
helper for running `make_dparser` from CMake builds. See
[Building and Integrating](../reference/building.md#cmake).

## Check the installation

```bash
make_dparser --help
```

prints the generator's options. Continue with
[Your First Parser](first-parser.md).
