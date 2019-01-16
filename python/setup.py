from distutils.core import setup, Extension
from distutils.command.install_data import install_data

# Pete Shinner's distutils data file fix... from distutils-sig
# data installer with improved intelligence over distutils
# data files are copied into the project directory instead
# of willy-nilly


class smart_install_data(install_data):
    def __init__(self):
        super(install_data).__init__()
        self.install_dir = None

    def run(self):
        # need to change self.install_dir to the library dir
        install_cmd = self.get_finalized_command('install')
        self.install_dir = getattr(install_cmd, 'install_lib')
        return install_data.run(self)


module_swigc = Extension(
        '_dparser_swigc',
        sources=['dparser_wrap.c', 'pydparser.c', 'make_tables.c'],
        define_macros=[('SWIG_GLOBAL', None), ('SWIG_PYTHON_STRICT_BYTE_CHAR', None)],
        libraries=['mkdparse', 'dparse'],
        library_dirs=['../'],
        extra_compile_args=['-Wall', '-ggdb3'])

setup(
        name="dparser",
        cmdclass={"install_data": smart_install_data},
        version="1.31",
        description='DParser for Python',
        py_modules=["dparser", "dparser_swigc"],
        url='https://github.com/jplevyak/dparser',
        ext_modules=[module_swigc],
)
