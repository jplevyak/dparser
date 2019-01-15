from distutils.core import setup, Extension


module_swigc = Extension(
        '_dparser_swigc',
        sources=['python/dparser.i', 'python/pydparser.c',
                 'python/make_tables.c', 'arg.c', 'lex.c', 'parse.c',
                 'dparse_tree.c', 'lr.c', 'read_binary.c',
                 'util.c', 'gram.c', 'mkdparse.c', 'scan.c',
                 'write_tables.c', 'grammar.g.c', 'symtab.c'],
        include_dirs=[".", 'python'],
        define_macros=[('SWIG_GLOBAL', None)],
        extra_compile_args=['-ggdb3', '-O3'])

setup(
        name="dparser",
        version="1.31.2",
        description='DParser for Python',
        py_modules=["dparser", "dparser_swigc"],
        package_dir={"": 'python', 'dparser_swigc': 'python'},
        url='https://github.com/jplevyak/dparser',
        ext_modules=[module_swigc],
)
