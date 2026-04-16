from setuptools import setup, Extension
from Cython.Build import cythonize

module = Extension(
    'dparser',
    sources=['dparser.pyx'],
    libraries=['mkdparse', 'dparse'],
    library_dirs=['../'],
    extra_compile_args=['-Wall', '-O3', '-g']
)

setup(ext_modules=cythonize(module, language_level="3"))
