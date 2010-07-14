EXTRA_DIST =	D.pm
noinst_DATA =	D.so
BUILT_SOURCES = D.c
#EXTRA_LTLIBRARIES = $(top_builddir)/libdparser.la
#noinst_LIBRARIES =  $(top_builddir)/libmkdparse.a

LDADD=$(top_builddir)/libmkdparse.a

CP=cp -av
RM=rm -fv

#pkglib_LTLIBRARIES=libD.la
#libD_la_SOURCES=D.c 
#EXTRA_libD_la_SOURCES=D.xs
#D_la_DEPENDENCIES=$(top_builddir)/libdparser.la
#libD_la_LIDADD=$(top_builddir)/libdparser.la
#libD_la_LDFLAGS=-module

if ENABLE_SWIG
D.c: $(top_srcdir)/dparser.i $(top_srcdir)/charmap.i
	$(SWIG) -perl -module 'Parser::D' -o $@ $<

#MOSTLYCLEANFILES=perl_wrap.c D.pm D.bs
MOSTLYCLEANFILES=perl_wrap.c D.bs
else
#use perl embed .xs stuff
perl_wrap.c: D.c
	$(CP) $< $@

D.c: Makefile.perl D.xs Dxs.c Dxs.h
	$(MAKE) -f $< $(@F)

endif

Makefile.perl: Makefile.PL
	$(PERL) $< PREFIX=$(prefix) MAKEFILE=$@

all-local D.so: Makefile.perl
	$(MAKE) -f $<

install-data-local: Makefile.perl
	$(MAKE) -f $< install

# sadly there is no make uninstall for perl
#uninstall-local: Makefile.perl
#	$(MAKE) -fMakefile.perl uninstall

clean-local:
	if test -f Makefile.perl; then $(MAKE) -fMakefile.perl realclean; fi
	rm -f Makefile.perl Makefile.perl.old
	rm -f *.so *.$(OBJEXT)


check-local: Makefile.perl
	$(MAKE) -f $< test
