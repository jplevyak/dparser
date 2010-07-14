#
# $Id$
#
# $Log$
#
from distutils.core import setup, Extension
import string

#Pete Shinner's distutils data file fix... from distutils-sig
#data installer with improved intelligence over distutils
#data files are copied into the project directory instead
#of willy-nilly
#from distutils.command.install_data import install_data
#import os, sys, string
#class smart_install_data(install_data):
#    def run(self):
#        #need to change self.install_dir to the library dir
#        install_cmd = self.get_finalized_command('install')
#        self.install_dir = getattr(install_cmd, 'install_lib')
#        return install_data.run(self)

module_swigc = Extension('_dparser'
   , sources = ['dparser_wrap.c']
   , include_dirs=['..']
   , extra_link_args = string.split('-lgc  ')
   , extra_compile_args = ['-Wall']
   , library_dirs = ['./.libs', '..', '/usr/local/lib', '${exec_prefix}/lib']
   , libraries = ['pydparser', 'mkdparse', 'dparser']
   #, ['dparser_wrap.c', 'pydparser.c', 'make_tables.c']
   #, define_macros = [('SWIG_GLOBAL', None)]
)
    
setup(name = 'dparser'
    , version = '1.14.2'
    , description = 'DParser for Python'
    #cmdclass = {"install_data": smart_install_data},
    #py_modules = ["dparser"],
    , ext_modules = [module_swigc]
    , author = 'Mr Da Parser, John Plevyak'
    , author_email = 'john.plevyak@yahoo.com'
    , url = 'http://dparser.sourceforge.net/'
    , download_url = 'http://dparser.sourceforge.net/'
    , package_dir = {'dparser': '.'}
    , packages = [ 'dparser' ]
    , ext_package = 'dparser'
)
