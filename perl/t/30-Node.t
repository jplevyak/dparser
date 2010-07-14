#!perl
# $File: //member/autrijus/Module-Signature/t/0-signature.t $ $Author: cmont $
# $Revision: 1.1.1.1 $ $Change: 1871 $ $DateTime: 2002/11/03 19:22:02 $

use strict;
use Test::More tests => 1;
BEGIN {
  use_ok('Parser::D::Node');
}
my $test_jump = "\n" x 3;
my $test = ''; #function tested
my $e = 0; # ERRNO
