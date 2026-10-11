from setuptools import setup, Extension
from Cython.Build import cythonize

# The dparser C sources live in the repo root; compile them straight into the
# extension so the wheel is self-contained (no prebuilt libdparse/libmkdparse).
# Keep in sync with LIB_SRCS/MK_LIB_SRCS in the Makefile and with MANIFEST.in.
LIB_SRCS = [
    'arg.c', 'parse.c', 'scan.c', 'dsymtab.c', 'util.c', 'read_binary.c',
    'dparse_tree.c',
]
MK_LIB_SRCS = [
    'mkdparse.c', 'write_tables.c', 'grammar.g.c', 'gram.c', 'lex.c', 'lr.c',
]

module = Extension(
    'dparser',
    sources=['python/dparser.pyx'] + LIB_SRCS + MK_LIB_SRCS,
    include_dirs=['.'],
    define_macros=[('USE_FREELISTS', None)],  # matches Makefile default
    extra_compile_args=[
        '-Wall',
        '-O3',
        '-g',                      # retain debug symbols for stack traces from .so crashes
    ]
)

setup(
    ext_modules=cythonize(module, language_level="3"),
    package_dir={'': 'python'},    # build_ext --inplace drops the .so in python/
)
