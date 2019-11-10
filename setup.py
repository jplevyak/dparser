from setuptools import setup, Extension
from distutils.command.build import build


# Sadly setuptools has a nasty bug whereby it doesn't swig
# the extension module before trying to install the generated
# .py file.
class build_alt_order(build, object):
    def __init__(self, *args):
        super(build_alt_order, self).__init__(*args)
        self.sub_commands = [('build_ext', build.has_ext_modules),
                             ('build_py', build.has_pure_modules)]


module_swigc = Extension(
        '_dparser_swigc',
        sources=['python/dparser.i', 'python/pydparser.c',
                 'python/make_tables.c', 'arg.c', 'lex.c', 'parse.c',
                 'dparse_tree.c', 'lr.c', 'read_binary.c',
                 'util.c', 'gram.c', 'mkdparse.c', 'scan.c',
                 'write_tables.c', 'grammar.g.c', 'symtab.c'],
        swig_opts=['-modern', '-I..'],
        include_dirs=[".", 'python'],
        define_macros=[('SWIG_GLOBAL', None),
                       ('SWIG_PYTHON_STRICT_BYTE_CHAR', None)],
        extra_compile_args=['-ggdb3', '-O3'])

setup(
        name="dparser",
        version="1.31.8",
        description='DParser for Python',
        url='https://github.com/jplevyak/dparser',
        author='John Plevyak',
        author_email='jplevyak@gmail.com',
        cmdclass={'build': build_alt_order},
        ext_modules=[module_swigc],
        py_modules=["dparser", 'dparser_swigc'],
        package_dir={'': 'python'},
)
