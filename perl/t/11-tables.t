#!/usr/bin/perl
# $File: //member/autrijus/Module-Signature/t/0-signature.t $ $Author: cmont $
# $Revision: 1.1.1.1 $ $Change: 1871 $ $DateTime: 2002/11/03 19:22:02 $

use strict;
use Test::More tests => 3;
BEGIN {
  use_ok('Parser::D::Tables');
}

my $test_jump = "\n" x 3;
my $test = ''; #function tested
my $e = 0; # ERRNO


$test = 'Parser::D::Tables::new';
diag($test_jump, 'tetsing ' . $test);
my $t;
ok(defined($t = Parser::D::Tables->new(filename => "t/test.g.d_parser")), $test)
  or diag("failed ", $test);

# check this?!
#


$test = 'Parser::D::Tables::load_parser';
diag($test_jump, 'tetsing ' . $test);
#need a string or a file...
my $s = 't/test.g.d_parser';
ok(defined($t = Parser::D::Tables::load_parser($s)), $test)
or diag("error in ", $test);


#this is the pointer to tables structure...
#check that?
#ok(, $test);

1;
