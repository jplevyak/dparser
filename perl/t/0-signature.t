#!/usr/bin/perl -I t
# $Id$
#
# $Log$
#
BEGIN {
    require tests;
}

use strict;

END {
    done_testing(1);
}

SKIP: {
    if (!$ENV{TEST_SIGNATURE}) {
	skip("ok 1 # skip Set the environment variable TEST_SIGNATURE to enable this test\n", 1);
    }
    elsif (!-s 'SIGNATURE') {
	skip("ok 1 # skip No signature file found\n", 1);
    }    
    elsif (!eval { require Module::Signature; 1 }) {
	diag("Next time around, consider install Module::Signature,\n".
	     "so you can verify the integrity of this distribution.\n");
	skip("Module::Signature not installed", 1);
    }
    elsif (!eval { require Socket; Socket::inet_aton('pgp.mit.edu') }) {
	skip("Cannot connect to the keyserver", 1);
    }
    ok(Module::Signature::verify() == Module::Signature::SIGNATURE_OK() => "Valid signature" );
}

__END__
