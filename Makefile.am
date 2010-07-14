#
# $Id: Makefile.am,v 1.5 2010-07-09 13:55:24 christian.montanari Exp $
#
#AC defined

if ENABLE_PERL
MAYBE_PERL = perl
endif

if ENABLE_PYTHON
# automake chokes on "MAYBE_PYTHON"?
MAYBE_PYTHON_ = python
endif

SUBDIRS = . tests verilog $(MAYBE_PERL) $(MAYBE_PYTHON_)
CLEANFILES = 4calc.g.d_parser.c my.g.d_parser.c sample.g.d_parser.c

ACLOCAL_AMFLAGS = -I m4
AM_CPPFLAGS = @PROFILE_FLAG@ $(CWARNFLAGS)
#AM_LDFLAGS = -rpath '$(libdir)' -L/usr/local/lib
#AM_LDFLAGS = -L/usr/local/lib
AM_LDFLAGS =
AM_LIBTOOLFLAGS=--verbose
LIBS = -L/usr/local/lib $(GC_LIB) $(LEAK_LIB) $(POW_LIB)

dist_doc_DATA = index.html manual.html faq.html
dist_doc_DATA += 4calc.g 4calc.in

man1_MANS = make_dparser.1
#dist_man_MANS = make_dparser.1
#make_dparser.cat: make_dparser.1
#	nroff -man $< | sed -e 's/.//g' > $@

SUFFIXES=.g.d_parser.c .g 
#autoreconf  --install --verbose --warn=all ;make -k
#Makefile.am:73: `%'-style pattern rules are a GNU make extension
.g.g.d_parser.c:
	if test -f $<.flags; then flags=`cat $<.flags`;	fi;\
	$(MAKE_DPARSER) $<

sample.g.d_parser.c:sample.g  $(MAKE_DPARSER)
my.g.d_parser.c: my.g  $(MAKE_DPARSER)
grammar.g.d_parser.c: grammar.g
	$(MAKE_DPARSER) -i dparser_gram $^


#Libraries
#EXTRA_LTLIBRARIES = $(LIBS)
lib_LTLIBRARIES = libdparser.la
libdparser_la_SOURCES = arg.c parse.c scan.c symtab.c util.c read_binary.c dparse_tree.c
#libdparser_la_LDFLAGS = -rpath '$(libdir)' -version-number @DPARSER_VERSION_MAJOR@:@DPARSER_VERSION_MINOR@:@DPARSER_ALPHA_VERSION@ -no-undefined
libdparser_la_LDFLAGS = -version-number @DPARSER_VERSION_MAJOR@:@DPARSER_VERSION_MINOR@:@DPARSER_ALPHA_VERSION@ -no-undefined
#libdparser_la_LIBADD = 
#dparser_ldadd=libdparser.la
dparser_ldadd=-ldparser

#not for release...dparse own grammar compiler...
#libexec_PROGRAMS = 

noinst_LIBRARIES = libmkdparse.a
libmkdparse_a_SOURCES = mkdparse.c write_tables.c grammar.g.d_parser.c gram.c lex.c lr.c
mkdparse_ldadd = libmkdparse.a
#mkdparse_ldadd = -lmkdparse
#chicken and egg $(MAKE_DPARSER):libmkdparse.a:$(MAKE_DPARSER)
#also with ./make_dparser.exe -i dparser_gram grammar.g
#chuck 
#libmkdparse_a_DEPENDENCIES = $(MAKE_DPARSER)
#PRECIOUS=grammar.g.d_parser.c

#HEADERS
dist_noinst_HEADERS = d.h d_config.h
# unprefixed header
#include_HEADERS =

#Pakaging info
pkgconfigdir=$(libdir)/pkgconfig
pkgconfig_DATA=dparser.pc
pkginclude_HEADERS=dparse.h dparse_tables.h dsymtab.h dparse_tree.h


# Binaries=
MAKE_DPARSER=$(top_builddir)/make_dparser$(EXEEXT)
bin_PROGRAMS=make_dparser driver_parsetree
make_dparser_SOURCES = make_dparser.c version.c
make_dparser_LDFLAGS = $(mkdparse_ldadd) $(dparser_ldadd)
make_dparser_DEPENDENCIES = libmkdparse.a
#missing parser_tables_gram use instead parser_tables_dparser_gram?
driver_parsetree_LDFLAGS = $(mkdparse_ldadd) $(dparser_ldadd)
driver_parsetree_SOURCES = driver_parsetree.c version.c
driver_parsetree_DEPENDENCIES = libmkdparse.a

check_PROGRAMS = test_dparser 
test_dparser_SOURCES = test_parser.c version.c
test_dparser_LDFLAGS=$(mkdparse_ldadd) $(dparser_ldadd)
test_dparser_DEPENDENCIES=libmkdparse.a

#VERILOG_FILES = d/verilog/Makefile d/verilog/verilog.g d/verilog/README d/verilog/ambig.c \
d/verilog/main.c d/verilog/vparse.c d/verilog/vparse.h d/verilog/verilog_tests

#TEST
check_PROGRAMS+=myexample
myexample_SOURCES=my.c my.g.d_parser.c
myexample_LDFLAGS=$(dparser_ldadd)

#inc_BUILD_VERSION: $(bin_PROGRAMS)
#	@cat ${srcdir}/BUILD_VERSION 
#	@echo $(D_BUILD_VERSION+) > ${srcdir}/BUILD_VERSION
#@$(MV) -v BUILD_VERSION.tmp BUILD_VERSION

