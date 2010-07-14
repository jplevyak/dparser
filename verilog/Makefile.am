#
# $Id: Makefile.am,v 1.2 2010-06-28 12:58:12 cmont Exp $
#
# $Revision: 1.2 $
#
# Binaries=
MAKE_DPARSER=$(top_builddir)/make_dparser$(EXEEXT)
DPARSEFLAGS=

#check_TESTS=$(DPARSER_DIFF_VERILOG)
TESTS_ENVIRONMENT=$(builddir)/v$(EXEEXT)
TESTS=@DPARSER_DIFF_VERILOG@
check_PROGRAMS = v
v_SOURCES= main.c vparse.c ambig.c verilog.g.d_parser.c
#v_LDFLAGS= -l -v -L$(top_builddir) -ldparse
v_LDFLAGS=-L$(top_builddir) -ldparser
#v_CFLAGS=-I$(top_builddir)
v_DEPENDENCIES = $(MAKE_DPARSER)

AM_LIBTOOLFLAGS=--verbose
AM_CFLAGS=
AM_CPPFLAGS = @PROFILE_FLAG@ $(CWARNFLAGS)

SUFFIXES=.g.d_parser.c .g

.g.g.d_parser.c:
	$(MAKE_DPARSER) $(DPARSEFLAGS) $<

verilog.g.d_parser.c: verilog.g

#lint:
#	lint $(CFLAGS) $(CSRCS)
#test:	$(TARGET)
#	./verilog_tests
#	grep succeeded log.txt | wc -l
#	grep failed log.txt | wc -l
