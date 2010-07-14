#!/usr/bin/perl -w
#
# $Id$
#

use ExtUtils::MakeMaker;
use ExtUtils::Constant qw(WriteConstants);
use Cwd;
use Config;

=pod

=cut

our $MODULE = 'Parser::D';
WriteMakefile
    (
     NAME         => $MODULE
     , ABSTRACT	=> 'a Perl interface to the Da Parser'
     , AUTHOR	=> 'Christian Montanari <christian.montanari@sharp.eu>'
     , LICENSE	=> 'perl'
     , VERSION => q[1.14.2]
     , FIRST_MAKEFILE => 'Makefile.perl'
     , INC => q[-I..  -Wall -Wpointer-arith -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wnested-externs -fno-strict-aliasing -Wbad-function-cast -Wformat=2 -Wold-style-definition -Wdeclaration-after-statement]
     , DEFINE => q[-DHAVE_CONFIG_H]
     #'EXE_FILES'    => ['bin/ccconfig'],
     #'PL_FILES'     => \%GENERATE,
     #'CONFIGURE'    => \&configure,
     #, 'PM'	=> { '.pm' => '$(INST_LIBDIR)/Lex.pm' }
     #, 'dist'	=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
     # Default value for LDDLFLAGS is $Config{lddlflags}="-shared 
     # but we want rpath to be ${exec_prefix}/lib or ${prefix}/lib
     , LDDLFLAGS => q[-shared -Wl,-rpath=/usr/local/lib -L/bin ]
#CPM100708 issues with 
#undefined reference to `___stack_chk_guard'
#undefined reference to `___stack_chk_fail'
#found in
#Binary file /lib/gcc/i686-pc-cygwin/4.3.4/libssp.a matches
#Binary file /lib/gcc/i686-pc-cygwin/4.3.4/libssp.dll.a matches
#	-L/usr/lib/perl5/5.10/i686-cygwin/CORE -lperl
     , LIBS => q[-L../.libs -L..
        -L${exec_prefix}/lib
	-lmkdparse -ldparser
        -L/usr/local/lib -lgc  
        -L/lib/gcc/i686-pc-cygwin/4.3.4 -lssp
     ]
     , 'OBJECT' => 'perl_wrap.o'
     #, 'SOURCES'      =>  ['perl_wrap.c', 'make_tables.c']
     #, 'XS'	 => { 'D.xs' => 'Lex.xs.tab.c' }
#CPM070508
# the linking/makefile generation discards mkdparse,dparase if not compiled before hand!
# 6.21.
#How canI adjust the heap/stack size of an application?
#	If you need to change the maximum amount of memory available to Cygwin, see http://cygwin.com/cygwin-ug-net/setup-maxmem.html. Otherwise, just pass heap/stack linker arguments to gcc. To create foo.exe with a heap size of 200MB and a stack size of 8MB, you would invoke gcc as:
#gcc -Wl,--heap,200000000,--stack,8000000 -o foo foo.c
   , 'clean'        => { FILES => 'y.tab.pl *~ *.tab.c *.output *.vcg Lex.y Lex.xs const-xs.inc const-c.inc TAGS' }
   #, 'realclean'    => { FILES => "@REALCLEAN" }
   , 'PREREQ_PM' => {'IO::Gzip'			=> 0
		     , 'Data::Dumper'		=> 2.121
		     , 'Data::Hexdumper'	=> 1.2
		     , File::Temp        	=> 0.16
		     , File::Spec => 0
		     , File::Path => 0
		     , 'Parse::Lex'		=> 2.15
		     , 'Test::More'        	=> 0.34
		     , 'Test::Exception'	=> 0
		     , 'Class::Container'	=> 0.12
		     , 'Params::Validate'	=> 0
		     , 'GraphViz' => 0
		    }
);

if(eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw(D_ParseNode_Globals D_ParseNode_User));
  ExtUtils::Constant::WriteConstants
      (
       NAME         => 'Paresr::D',
       NAMES        => \@names,
       DEFAULT_TYPE => 'IV',
       C_FILE       => 'const-c.inc',
       XS_FILE      => 'const-xs.inc',
      );
} else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}


package MY;

# --- MakeMaker depend section:

# --- MakeMaker const_config section:
sub dist
{
  shift->SUPER::dist(@_).<<_END
SHELL:=bash
DIFF:=diff -wbB --unified=5
pck_name:=d-1.15-src
src_dir:=..
pck_dir:=//s-pc37-w2k/dump/cygwin/contrib/parsers/\${pck_name}.tar.gz
src_dir_orig:=\${src_dir}/orig
CVS	:=cvs.1.11.22
CVS_RSH	:=ssh
CVSROOT	:=-z3 -d:ext:ptizoom\@dparser.cvs.sourceforge.net:/cvsroot/dparser

_END
}

sub dist_basics
{
  shift->SUPER::dist_basics(@_).<<_END

# generate package diffs..
# quite wrong anyway...
diff:\$(pck_name)_orig.diff

\${pck_name}_orig.diff : \${src_dir_orig}/\${pck_name} \${src_dir}/\${pck_name}
	-\${DIFF} -r \$\^ > \$\@

\${src_dir}/\${pck_name}:
	install -d \$\@
	tar xzuf \${pck_dir} -C \$(\@D)

\${src_dir_orig}/\${pck_name}:
	install -d \$\@
	tar xzf \${pck_dir}  -C \$(\@D)


#
# other installation things

co:
	\$(CVS) \$(CVSROOT) login
	cd /usr/src;\$(CVS) \$(CVSROOT) co dparser

_END
}

sub depend_
{
  shift->SUPER::depend(@_).<<_END
MYEXTLIBS:=extralibs
.PHONY : extralibs

\$(XS_FILES) : \$(C_FILES_) Dxs.c \$(H_FILES)

#Dxs.c :: \$(XS_FILES)

_END
}

sub subdirs_
{
  shift->SUPER::subdirs(@_).<<_END

#-L../ -lmkdparse_gc -ldparse_gc -lgmon -lgc'
#D_OPTIMIZE=1
#D_LEAK_DETECT=1 but no lib leak, so don't use gc

subdirs :: extralibs

#	\${MAKE} D_DEBUG=1 D_USE_GC=1 D_PROFILE=1 -C \${src_dir} libs

extralibs :
	\${MAKE} D_DEBUG=1 D_PROFILE=1 -C \${src_dir} libs

_END
}


#&Meta->write;
sub test_
{
  shift->SUPER::test(@_).<<_END

TEST_FILES = `find t -iname "*.t"`

_END
}
