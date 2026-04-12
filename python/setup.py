try:
    from setuptools import setup, Extension
except ImportError:
    from distutils.core import setup, Extension

module_swigc = Extension(
        '_dparser_swigc',
        sources=['dparser_wrap.c', 'pydparser.c', 'make_tables.c'],
        define_macros=[('SWIG_GLOBAL', None), ('SWIG_PYTHON_STRICT_BYTE_CHAR', None)],
        libraries=['mkdparse', 'dparse'],
        library_dirs=['../'],
        extra_compile_args=['-Wall', '-ggdb3'])

setup(
        name="dparser",
        version="1.31",
        description='DParser for Python',
        py_modules=["dparser", "dparser_swigc"],
        url='https://github.com/jplevyak/dparser',
        ext_modules=[module_swigc],
)
