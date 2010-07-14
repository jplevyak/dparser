#
# $Id$
#
# complementary test module allowing
# design of tests as the same time of insvestigating
# development
#
# $Log$
#

use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use IO::String;
use IO::File;
use Data::Hexdumper qw(hexdump) ;
use File::Temp	qw/tempfile tempdir mktemp/;
use File::Path	qw(remove_tree make_path);
use File::Spec;
use File::Basename;
use Tie::IxHash;
use Storable;



BEGIN {
	if($0 =~ qr#/usr/.*src/#) {
		my($p) = $0 =~ m#/usr/.*src/[^/]+/#g;
		unshift(@INC, File::Spec->catfile($p, 'lib'));
	}
	use lib qw(
	/net/stenb-d530-04/c/cygwin/usr/lib/perl5/site_perl
	//stnb-d530-04/c/usr/lib/perl5/site_perl
    );
}

sub ok {
	_base_dumper('ok', @_);
}
sub is($$;$) {
	_base_dumper('is', @_);
}
sub like($$;$) {
	_base_dumper('like', @_);
}
sub is_deeply {
	_base_dumper('is_deeply', @_);
}

sub use_ok {
	my $u = shift;
	$u = $u . '.pm';
	$u =~ s/::/\//g;
	require $u ,(@_);
}
sub cmp_ok {
	_base('cmp_ok', @_);
}
sub diag {
	_base('diag', @_);
}
sub done_testing {
	_base('done_testing', @_);
}
sub skip {
	_base('skip', @_);
}
sub _base {
	my $s = 'Test::More::' . shift;
	if($0 =~ qr/\.t$/) {
		&{$s}(@_);
	} else {
		print caller(), @_;
	}
}
sub _base_dumper {
	my $s = 'Test::More::' . shift;
	if($0 =~ qr/\.t$/) {
		&{$s}(@_);
	} else {
		print caller(), Dumper(@_);
	}
}

if($0 =~ qr/\.t$/) {
	require Test::More;
	foreach
		$s
		qw/ok is diag done_testing use_ok skip like cmp_ok is_deeply/
	{
		undef *{$s};
		*{$s} = \&{'Test::More::' . $s};
	}
}
#bundle of values used in nearly every tests
@search_path_d  = ('.', 'doc', '../doc', 't', '../t');
$d_t = (-d 't' ? 't/' : '');
$test_jump = "\n" x 3;
$cache_d = $d_t . 'tmp';
$db_n = $d_t . 'test_results.db';
$dsn = 'dbi:SQLite:dbname=' . $db_n;
$f_store = $d_t . 't_convert_parse_features_stats.pdb';
@f_tests = ();
@f_directories = ();

sub find_test_file {
  my $s = shift || '.g';
  if(-f $s) {
    return $s;
  }
  if(-f '../' . $s) {
    return '../' . $s;
  }
  if(-f '../../' . $s) {
    return '../../' . $s;
  }
  if(-f 't/' . $s) {
    return 't/' . $s;
  }
  if(-f '../t/' . $s) {
    return '../t/' . $s;
  }
  if(-f 'contrib/' . $s) {
    return 'contrib/' . $s;
  }
  if(-f '../contrib/' . $s) {
    return '../contrib/' . $s;
  }
  diag("FIXME: test file $s not found");
  return $s;
}

$gram =<<'_GRAM_'
program : statement;
statement : program;
_GRAM_
;




1;
__END__
