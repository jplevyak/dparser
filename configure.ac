#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.
# automake  --verbose --add-missing --copy
AC_PREREQ(2.65)
AC_INIT([dparser], [1.14.2], [john.plevyak@yahoo.com])

#AC_CONFIG_AUX_DIR([.,/usr/share/libtool/config])
AC_CONFIG_SRCDIR([Makefile.am])

#/usr/share/aclocal
AC_CONFIG_MACRO_DIR([m4])

AC_COPYRIGHT(dnl
 [Copyright (c) 2002-2010 John Plevyak
  2010 Sharp Telecommunication of Europe Ltd. <christian.montanari@sharp.eu>])

AC_REVISION($Revision: 1.14 $)
AC_SUBST(PACKAGE_URL, [http://dparser.sourceforge.net/])
AC_SUBST(PACKAGE_DOWNLOAD_URL, [http://dparser.sourceforge.net/])

# set version in header
# ---------------------
DPARSER_SET_VERSION
AC_DEFINE([D_VERSION],["(DPARSER_VERSION_MAJOR<<24)+(DPARSER_VERSION_MINOR<<16)+(DPARSER_ALPHA_VERSION & 15)"],
  [is the package version mark.])
AC_SUBST_FILE([BUILD_VERSION])
BUILD_VERSION=${srcdir}/BUILD_VERSION
AC_SUBST(DPARSER_VERSION_MAJOR)
AC_SUBST(DPARSER_VERSION_MINOR)
AC_SUBST(DPARSER_ALPHA_VERSION)
# ---------------------
AM_INIT_AUTOMAKE([dist-bzip2 color-tests -Wall -Werror])
XORG_CWARNFLAGS

AC_CONFIG_HEADERS([d_config.h])
AM_MAINTAINER_MODE

# Checks for programs.
# ---------------------
AC_PROG_AWK
AC_PROG_CC
dnl compiling `main.c' with per-target flags requires `AM_PROG_CC_C_O' in `configure.ac'
AM_PROG_CC_C_O
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PROG_SED
XORG_ENABLE_DOCS
XORG_ENABLE_SPECS
XORG_ENABLE_DEVEL_DOCS
XORG_WITH_XMLTO
XORG_WITH_ASCIIDOC
XORG_WITH_DOXYGEN
XORG_WITH_FOP
XORG_WITH_GROFF
XORG_WITH_PS2PDF

dnl libtoolize: `AC_PROG_RANLIB' is rendered obsolete by `LT_INIT'
LT_INIT

# Configuration of shared libraries
AC_MSG_CHECKING([whether to build shared libraries])
AC_ENABLE_SHARED
case "$host" in
 alpha-*-openbsd*)
     enable_shared=no
     ;;
 *)
     ;;
esac
AC_MSG_RESULT($enable_shared)



# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([inttypes.h stdlib.h string.h unistd.h])
AC_CHECK_HEADERS([fcntl.h limits.h  sys/time.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T

# Checks for library functions.
AC_FUNC_MALLOC
AC_FUNC_REALLOC
AC_FUNC_STRTOD
AC_CHECK_FUNCS([bzero memmove memset strchr strerror strncasecmp strrchr strstr strtol])

#
# Checks for libraries.
AC_CHECK_LIB([m],[infinity],[AC_MSG_RESULT([math library exists, used])])


# Garbage Collector
# -----------------
DPARSER_DISABLE_GC
AM_WITH_DMALLOC

# Debugging
# ---------
AC_ARG_ENABLE([debug], [AS_HELP_STRING([--enable-debug],[enable general debugging.])])
AC_DEFINE([D_DEBUG], [1], [dparser general debugging flag.])

#else optimize?

# profiling
# -----------------
AC_ARG_ENABLE([profiling],
 [AS_HELP_STRING([--enable-profiling],[enable general profiling.])],
 [AS_IF([test "x${enable_profiling}" = xyes],[AC_SUBST([PROFILE_FLAG],[-pg])])])


# memory watching tool
AC_CHECK_HEADERS([memwatch.h])

#ifdef MEMWATCH
#define MEMWATCH_STDIO 1
#include "../../src/memwatch-2.67/memwatch.h"
#define MEM_GROW_MACRO
#endif

#TODO:CPM100618
#dp_valgrind='linux32 valgrind --tool=memcheck --leak-check=yes --show-reachable=yes'
dp_valgrind=
AC_SUBST([VALGRIND], $dp_valgrind)

# leak detection
# -----------------
AH_TEMPLATE([LEAK_DETECT], [leak detection mode, but needs "leak" to work.])
AC_ARG_ENABLE(leak-detect, [AS_HELP_STRING([--enable-leak-detect],[enable leak detection reports.])])
AC_CHECK_LIB([leak], [main], [
     AC_SUBST([LEAK_LIB], [-lleak])
     AC_DEFINE([LEAK_DETECT], [1])
   ]
)

# check for language bindings
#----------------------------
#PERL 
#----------------------------
AC_ARG_ENABLE([perl],[AS_HELP_STRING([--disable-perl],dnl
     [Disables perl language bindings @<:@default=auto@:>@])],
     [ac_perl_enabled=$enableval],
  [AC_CHECK_PROG([ac_perl_enabled],[perl],[yes],[no])]
)
if test "$ac_perl_enabled" = yes; then
   AC_PATH_PROG([PERL], [perl], [])
fi
AM_CONDITIONAL([ENABLE_PERL], [test x"$PERL" != x""])
#python
#----------------------------
AC_ARG_ENABLE([python],dnl
  [AS_HELP_STRING([--disable-python],dnl
    [Disables python language bindings @<:@default=auto@:>@])],dnl
  [ac_python_enabled=$enableval],dnl
  [AC_CHECK_PROG([ac_python_enabled],[python[$PYTHON_VERSION]],[yes],[no])]
)
if test "$ac_python_enabled" = yes; then
   AM_PATH_PYTHON([2.5],, [:])
fi
AM_CONDITIONAL([HAVE_PYTHON], [test "$PYTHON" != :])
AM_CONDITIONAL([ENABLE_PYTHON], [test x"$PYTHON" != x""])
#SWIG
# check for optional swig rebuild
#----------------------------
AC_ARG_ENABLE([swig],dnl
	[AS_HELP_STRING([--enable-swig],dnl
		[Rebuild language bindings @<:@default=no@:>@])
	],dnl
	[case "${enableval}" in
  	     yes) want_swig_rebuild=true ;;
  	     no)  want_swig_rebuild=false ;;
  	     *) AC_MSG_ERROR(bad value ${enableval} for --enable-swig) ;;
	     esac],dnl
	[want_swig_rebuild=false]
)
AM_CONDITIONAL(ENABLE_SWIG, test x$want_swig_rebuild = xtrue)
if test x$want_swig_rebuild = xtrue; then
	AC_PROG_SWIG(1.3.7) dnl how low can we go?
fi

# check tests 
#----------------------------
dp_tests=`find tests -name '*.check' -exec $as_basename {} -print \;`
dp_tests_chk_basename=
for tc in $dp_tests ; do
    dp_tests_chk_basename="${dp_tests_chk_basename} ${tc}.diff"
done
AC_SUBST([DPARSER_DIFF_TESTS],[$dp_tests_chk_basename])

dp_tests=`find tests -name '*.test.g' -exec $as_basename {} -print \;`
dp_tests_g_basename=
for tc in $dp_tests ; do
    dp_tests_g_basename="${dp_tests_g_basename} ${tc}"
done
AC_SUBST([DPARSER_G_TESTS],[$dp_tests_g_basename])

#tests/tests.am
dp_tests_am_f=tests/tests.am
$as_echo "check_PROGRAMS=" >$dp_tests_am_f     	
for tc in $dp_tests_g_basename ; do
    $as_echo "check_PROGRAMS+= ${tc}.sp" >>$dp_tests_am_f
    tc_u=`$as_echo_n $tc | sed -e 's,\.,_,g;s, ,,g'`
    $as_echo "${tc_u}_sp_SOURCES= ${tc}.d_parser.c" >>$dp_tests_am_f
    $as_echo "${tc_u}_sp_LDFLAGS=\$(check_LIBRARIES) -ldparser" >>$dp_tests_am_f
    $as_echo "${tc}.d_parser.c:${tc}" >>$dp_tests_am_f
dnl    $as_echo "${tc}.d_parser.c:\$(MAKE_DPARSER) ${tc}" >>$dp_tests_am_f
done
for tc in $dp_tests_chk_basename ; do
    tc_u=`$as_echo_n $tc | sed -e 's,\.check.*,.check,g;'`
    $as_echo "${tc}:${tc_u}.out" >>$dp_tests_am_f
    $as_echo "${tc_u}.out:${tc_u}" >>$dp_tests_am_f
done

AC_MSG_RESULT([done building $dp_tests_am_f])

#dp_tests_chk="`find tests -name '*.check' -print`"
#dp_tests_chk_basenames=
#for tc in ${dp_tests_chk} ; do
#    dp_tests_chk_basenames="${dp_tests_chk_basenames} `($as_basename "${tc}") || (echo "$tc" | sed -e 's,.*/, ,g')`"
#done
#AC_SUBST([DPARSER_DIFF_TESTS],[$dp_tests_chk_basenames])
#dp_tests_g_basename=
#for tc in ${dp_tests_chk_basenames} ; do
#    dp_tests_g_basename="${dp_tests_g_basename} `echo \"${tc}\"`"
#| sed -e 's,\.g.*\.check,.g,g'`"
#done
#dp_tests_g_basename=`$ac_echo "$dp_tests_chk_basenames" | sed -e 's,\.g[^ ]+\.check,.g,g'`
# | uniq --unique
#AC_SUBST([DPARSER_G_TESTS],[$dp_tests_g_basename])
#tests/tests.am
#dp_tests_am_f="tests/tests.am"
#$as_echo "check_PROGRAMS=" >$dp_tests_am_f
#for tc in $dp_tests_g_basenames ;
#do
#	[$ac_echo "check_PROGRAMS+= ${tc}.sp " >>$dp_tests_am_f]
#	[tc_u=`$ac_echo "${tc}" | sed -e 's,\.,_,g;s, ,,g'`]
#	$ac_echo "${tc_u}_sp_SOURCES= ${tc}.d_parser_c" >>$dp_tests_am_f
#	$ac_echo "${tc_u}_sp_LDADD=libsample_parser.a" >>$dp_tests_am_f
#	$ac_echo "" >> $dp_tests_am_f
#done
#AC_MSG_RESULT([building "$dp_tests_am_f"]);

# check verilog tests 
#----------------------------
dp_verilog_am_f="verilog"
AC_MSG_RESULT([building "$dp_verilog_am_f"])
dp_verilog_chk=`find verilog/testsuite -iname '*.v' -print`
dp_verilog_chk_basenames=
for tc in ${dp_verilog_chk} ; do
    dp_verilog_chk_basename="${dp_verilog_chk_basename} `echo ${tc} | sed -e 's,[^/]+/,,g'`"
done
AC_SUBST([DPARSER_DIFF_VERILOG],[$dp_verilog_chk_basenames])


AM_SILENT_RULES

# postamble
# ---------------------------
AC_CONFIG_FILES([Makefile dparser.pc
 tests/Makefile
 verilog/Makefile
 python/Makefile python/setup.py
 perl/Makefile.PL  perl/Makefile perl/D.pm
])
AC_OUTPUT
