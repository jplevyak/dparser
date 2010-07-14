# $Id: Makefile.am,v 1.4 2010-07-09 13:55:24 christian.montanari Exp $
#all:
#	echo "type 'make install' as root to install"
#$(pythondir)
# Adds support for distributing Python modules and packages.  To
# install modules, copy them to $(pythondir), using the python_PYTHON
# automake variable.  To install a package with the same name as the
# automake package, install to $(pkgpythondir), or use the
# pkgpython_PYTHON automake variable.
#
# The variables $(pyexecdir) and $(pkgpyexecdir) are provided as
# locations to install python extension modules (shared libraries).
# Another macro is required to find the appropriate flags to compile
# extension modules.
#
# If your package is configured with a different prefix to python,
# users will have to add the install directory to the PYTHONPATH
# environment variable, or create a .pth file (see the python
# documentation for details).

CP = cp -av
MV = mv -v

EXTRA_DIST = __init__.py   @PACKAGE_NAME@_wrap.c
#dist_DATA' is used but `distdir' is undefined
python_DATA = index.html py_dparser_manual.html README
EXTRA_pythondir = @pkgpythondir@
#${prefix}/share/dparser
EXTRA_python_DATA = contrib/dparserpy.el contrib/dparserpy-syntax_error.py
EXTRA_python_PYTHON = setup.py  @PACKAGE_NAME@.i

AM_CPPFLAGS = -I/usr/include/python$(PYTHON_VERSION)
AM_CFLAGS = $(CWARNFLAGS)
#AM_CFLAGS =
#EXTRA_LIBS=-lmkdparse -ldparse
PYTHONPATH=$(builddir)/build/lib.$(PLAT)
#TESTS_ENVIRONMENT=export PYTHONPATH="$(builddir)/build/lib.cygwin-1.7.5-i686-2.5 /usr/local/lib/python2.5/site-packages";$(PYTHON) -v
TESTS_ENVIRONMENT=export PYTHONPATH="$(builddir)/build/lib.cygwin-1.7.5-i686-2.5";$(PYTHON) -v
TESTS = tests/test.py \
	tests/test2.py \
	tests/test3.py \
	tests/test4.py \
	tests/test5.py \
	tests/test6.py \
	tests/test7.py

#PYTHON_FILES =   d/python/contrib/d*
CLEANFILES=dparser.pyc tests/d_parser_mach_gen.* tests/d_parser*


__init__.py: @PACKAGE_NAME@.swig_py parser_dparser.swig_py
	cat $^ > $@

if ENABLE_SWIG
SUFFIXES=.i
@PACKAGE_NAME@_wrap.c: @PACKAGE_NAME@.i
	$(SWIG) -python -module $* -I$(top_srcdir) -o $@ $<
	-@$(MV) $*.py $*.swig_py

@PACKAGE_NAME@.py:@PACKAGE_NAME@.i

MOSTLYCLEANFILES=__init__.py python_wrap.c

else !ENABLE_SWIG
endif !ENABLE_SWIG

#python_PYTHON=dparser.py
#EXTRA_libpydparser_la_SOURCES=dparser.pyc
#libpydparser_la_DEPENDENCIES=@PACKAGE_NAME@.i  @PACKAGE_NAME@_wrap.c
pyexec_LTLIBRARIES=libpydparser.la
libpydparser_la_SOURCES= pydparser.c pydparser.h make_tables.c
libpydparser_la_LDFLAGS= -avoid-version -module 


all-local: setup.py __init__.py $(pyexec_LTLIBRARIES)
	$(PYTHON) setup.py build


#pyexecdir='${exec_prefix}/lib/python2.5/site-packages'
#pythondir='${prefix}/lib/python2.5/site-packages'

install-data-local:
	$(PYTHON) setup.py install --root="/$(DESTDIR)" --prefix="$(prefix)"

clean-local:
	if test -x "$(PYTHON)"; then $(PYTHON) setup.py clean; fi
	@$(RM) -rf build



