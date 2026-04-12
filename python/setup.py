try:
    from setuptools import setup, Extension
except ImportError:
    from distutils.core import setup, Extension

try:
    from Cython.Build import cythonize
except ImportError:
    import sys
    print("Error: Cython is required to build dparser python bindings.")
    print("Please install it using: python3 -m pip install cython")
    sys.exit(1)

module_cython = Extension(
    'dparser',
    sources=['dparser.pyx'],
    libraries=['mkdparse', 'dparse'],
    library_dirs=['../'],
    extra_compile_args=['-Wall', '-O3', '-g']
)

setup(
    name="dparser",
    version="1.31",
    description='DParser for Python',
    url='https://github.com/jplevyak/dparser',
    ext_modules=cythonize(module_cython, language_level="3")
)
