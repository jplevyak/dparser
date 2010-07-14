# Binaries=
MAKE_DPARSER=$(top_builddir)/make_dparser$(EXEEXT)
#MAKE_DPARSER = $(top_builddir)/test_dparser$(EXEEXT)
#MAKE_DPARSER = $(top_builddir)/sample_dparser$(EXEEXT)
#EXTRA_LTLIBRARIES = $(top_builddir)/libdparser.la
DIFF="diff --ignore-all-space  --ignore-blank-lines --ignore-tab-expansion --ignore-space-change"

TESTS = @DPARSER_DIFF_TESTS@
#XFAIL_TESTS = 
TESTS_ENVIRONMENT = $(SHELL)

VPATH = @top_srcdir@ @top_builddir@
SUFFIXES = .test.g.d_parser.c .test.g .check.out .check .diff .out
CLEANFILES = *.sp$(EXEEXT) *.out *.diff *.test.g.d_parser.c *.test.g.d_parser.h

AM_LDFLAGS=
AM_CFLAGS=-L/usr/local/lib -L$(top_builddir) $(CWARNFLAGS)
AM_LIBTOOLFLAGS=--verbose

check_LIBRARIES = libsample_dparser.a
libsample_dparser_a_SOURCES = sample_parser.c 
libsample_dparser_a_LIBADD = $(top_builddir)/version.$(OBJEXT)

.test.g.test.g.d_parser.c:
	if test -f $<.flags; then flags=`cat $<.flags`; fi;\
	$(MAKE_DPARSER) $$flags $<

.check.check.out:
	g=`echo $* | sed -e 's,\.g.*$$,.g,g'`;\
	spg="./$${g}.sp$(EXEEXT) -v";\
	if test -f $*.flags; then flags=`cat $*.flags`;	fi;\
	$(VALGRIND) $$spg $$flags $* >$@ 2>&1

.out.diff:
	-@echo "$(DIFF) $< $*" > $@

include tests.am

