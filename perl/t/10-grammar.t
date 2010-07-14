#!perl -I t
#
# $Id: 10-grammar.t,v 1.2 2010-07-09 13:55:24 christian.montanari Exp $
#
# $Revision: 1.2 $ $Change: 1871 $ $DateTime: 2002/11/03 19:22:02 $
#
use Test::More tests => 21;
BEGIN {
    use Digest::MD5 qw(md5_hex);
};

use_ok('Parser::D::Grammar');

my $test_jump = "\n" x 3;
my $test = ''; #function tested
my $e = 0; # ERRNO

my $gram =<<'_GRAM_'
program : statement;
statement : program;
_GRAM_
;


my $g;
my $s; # some strings
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

$test = 'Parser::D::Grammar::new';
diag($test_jump, 'tetsing ' . $test);
$s = find_test_file('grammar.g');
ok($g = GrammarPtr::new($s), $test)
  or diag('got OBJPTR:', $g);

$test = 'Parser::D::Grammar::free_D_Grammar';
diag($test_jump, 'tetsing ' . $test);
ok($g = 1, $test)
  or diag('got OBJPTR:', $g);

#
# test multiple init//free
my @v;
my $i0 = 10;
my $i = $i0;
while($i--) {
  push @v, GrammarPtr::new($s);
}
ok($#v == ($i0 - 1), $test);
while(@v) {
  my $g = pop @v;
}
@v = ();
ok($#v == -1, $test);




$test = 'Parser::D::Grammar::new';
diag($test_jump, 'tetsing ' . $test);
ok($g = Parser::D::Grammar->new(grammar => $gram), $test)
  or diag('got:', $g);

#$test = 'Parser::D::Grammar::new::new';
#diag($test_jump, 'tetsing ' . $test);
#ok($g = Parser::D::Grammar->new(pathname => 't/test.g'), $test)
#  or  diag("bad test::",$test, '::got::', $g);

$i = $i0;
while($i--) {
  push @v,  new Parser::D::Grammar();
  #print "[$#v]", $v[$#v],"\t";
}
ok($#v == ($i0 - 1), $test);
@v = ();
ok($#v == -1, $test);


#
#
# the make of a grammar
#

$test = 'Parser::D::Grammar::make';
diag($test_jump, 'tetsing ' . $test);
ok(defined($g
	   = Parser::D::Grammar->new
	   (grammar => $gram
	    , make_grammar_file => 1
	    , d_verbose_level => 0
	   )
	  ), $test)
  or diag("failed to make", $g);


#
# the tenuppling makes....
#
ok(defined($g->make) x 10, $test);


#
#
# the tables writing
#

$test = 'Parser::D::Grammar::write_tables';
diag($test_jump, 'tetsing ' . $test);
ok(! $g->write_tables, $test)
  or diag("failed to write tables");



$s = find_test_file('test.g');
$test = 'Parser::D::Grammar::write_string';
diag($test_jump, 'tetsing ' . $test);
ok(ref($g
       = Parser::D::Grammar->new
       (filename => $s
	, make_grammar_file => 1
        , d_verbose_level => 0
       )
      ) eq 'Parser::D::Grammar', $test);
ok(defined($g->make));
ok($s = $g->write_string, $test)
  or diag("failed to write tables into a string");
my $l = 119032;
#119080;
#118944;
#119080;
#125192
ok(length($s) == $l, $test) or
  diag("length $l#", length($s));

# used later....
my $sig = md5_hex($g->{grammar});


diag("trying file testing :\n", $gram);
ok(ref($g = Parser::D::Grammar->parse_n_build
	   ($gram
	    , d_verbose_level => 0
	   )
	  ), $test);

#CPM070914 for some reasons it crashes,
# but undef makes it recorver!
undef $g;

$test = 'Parser::D::Grammar::write_file';
diag($test_jump, 'tetsing ' . $test);
$s = find_test_file('test.g');
ok(defined($g
	   = Parser::D::Grammar::parse_n_build
	   (undef, undef
	    , make_grammar_file => 1
	    , filename => $s
	    , d_verbose_level => 0)
	  ), $test . "::parse_n_build ")
  or diag("parse_n_build cocked up");

#
#could also check md5 of the string
# check signatures
#5899988f0f4b489bbe9aa0cf57a49f64
is($sig, $g->{signature}, $test)
  or diag("expected signature", $sig
	  , "or 5899988f0f4b489bbe9aa0cf57a49f64"
	  , "but got signature:", $g->{signature});

#
#
$test = 'Parser::D::Grammar::write_file::.o';
ok($g->write_file > 0, $test)
  or diag("did not get to load a proper gramma (\"$s\")");
#
#diag("checking .o exist");
#
$test = 'Parser::D::Grammar::write_file';
ok(-f $s . '.d_parser.' . $sig . '.o', $test)
  or diag("no table .o output for $s?");

#
#
#
$test = 'Parser::D::Grammar::write_file::.c';
open(TEST, '<' . $s . '.' . $sig . '.c'); 
ok(grep(/d_(speculative_reduction|final_reduction)_code_\d+_\d+_gram/, <TEST>), $test)
  or diag("missing C outputs functions");
close TEST;


TODO:
#
# grammar perl sub-parsing...
#
$test = 'Parser::D::Grammar::write_file::.c';
#
# linking perl function in grammar.
#

1;
