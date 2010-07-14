#!perl -I t
#
# $Id$
# 
# $Log$ 
#
#
#######################

BEGIN {
    require tests;
}
END {
    done_testing(30+2);
}

use_ok('Parser::D', 'version');

#
#
#
$test = 'Parser::D::version';
ok(($s = Parser::D::version()) eq $Parser::D::VERSION
   , $test)
  or diag("bad version:" . $s);

$test = 'Parser::D::new';
$s = find_test_file('test.g');
open(TEST, '<' . $s);
$s = '';
while(<TEST>) {$s .= $_};
close(TEST);
$stest = $test . '::grammar string';
ok(defined($p = Parser::D->new(grammar => $s)), $stest)
  or diag("failed new=" . $p);

$stest = $test . '::grammar scalar string';
ok(defined($p = Parser::D->new(grammar => \$s)), $stest)
  or diag("failed new=" . $p);

# save signature for later...
$s = $p->{signature};
$stest = $test . '::grammar in file';
ok(defined
   ($p = Parser::D->new
    (filename => find_test_file('test.g'))
   )
   , $stest
  )
  or diag("failed new=" . $p);

#
#
$stest = $test . '::signature';
ok($s eq $p->{signature}, $stest)
	or diag("bad signature:". $s . " #" . $p->{signature});
#
#
# init
$test = 'Parser::D::init';
$gram =<<'_GRAM_'
program : statement;
statement : program;
whitespace: ' ';
statement: "[a-z]+";
_GRAM_
;
$gram =<<'_GRAM_'
program : statement*;
whitespace: ' ';
statement: "[a-z]+";
_GRAM_
;
ok(defined($p = Parser::D->new(grammar => \$gram)), $test)
  or diag("failed new=" . $p);
ok(defined($s = $p->init('whitespace')), $test)
  or  diag("failed initialisation to \"statement\"",  Dumper($p, $s));

$stest = $test . ':: re-init?';
ok(defined($s = $p->init('statement')), $stest)
  or  diag("failed initialisation to \"statement\"",  Dumper($p, $s));

$stest = $test . ':: returns valid object';
is(ref($s), 'ParserPtr',  $stest)
  or diag('found this instead of "ParserPtr"', Dumper($s));

#
#
# run
$test = 'Parser::D::run';
$stest = $test . '::no error';
$s = 'hihohihoooo';
ok(@r = $p->run($s), $stest)
  or diag('why did it not run? must be the grammar');
ok($#{$r[1]} < 0, $stest)
  or diag('found too many errors, the grammar and/or the script is pants.'
	  , Dumper($p, @r));
is(ref($r[0]), 'D_ParseNodePtr', $stest)
  or diag('need to return a D_ParseNodePtr when finished the run', Dumper($p,@r));
# the run(\'hhihh')
$stest = $test . '::scalar string referencing script';
ok(@r = $p->run(\$s), $stest);
is(ref($p->{top_node}), 'D_ParseNodePtr', $stest)
  or diag('did not liked it:: top_node result::', Dumper($p->{top_node}, @r));

#
#
# default syntax error
$test = 'Parser::D::syntax_error_fn';
diag($test_jump, 'testing ' . $test);
ok(@r = $p->run('hi ho hi hoooo'), $test) or
  diag("why did it not run? must be the grammar", Dumper($p, @r));

ok(!defined($r[0]), $stest) or
  diag("not expecting anything after an error ", Dumper(@r));
is(ref($r[1]), 'ARRAY', $test) or
  diag("expecting an array of errors", Dumper(@r));

$stest = $test . '::here is an error here is an error with pos 3?';
is($r[1][0]{ERI}, 3, $stest)
  or diag("Parser::D::d_loc_t::tell or Parser::D::syntax_error_fn need debugging"
	  , Dumper(@r));

#TDOD:CPM100709 STDEER looks like this.
#Parser::D::syntax_error_fn::#[1]	line:1
#hi [SNERR0R]ho hi hoooo


#
# ambiguity...
$test = 'testing ambiguity';
$gram =<<'_G_'
program : statement* [#!perl
	$$("it is ambiguous");];
statement::= "[a-z]";
_G_
;
$stest= $test . "::defined";
ok(defined($p = Parser::D->new(grammar => \$gram, d_debug_level => 0)), $test) or
  diag($test_jump, $test, "is quite ambiguous after all");
ok(@r = $p->run('hi'), $stest)
  or diag('parser did not fired up', Dumper($p));
$stest= $test . "::user variable of top node is also updated";
is($s = $r[0]->user, 'it is ambiguous', $stest)
  or diag('user() does not work. check NodePtr, redu_index in write_reduction() etc...', Dumper(@r));
#it did not work...for a while
#CPM070919 fixed this... it was a static redu_index in write_reduction()

#
#
#  GLOBALs structure parsing
$test='globals structures::';
$stest= $test . "defined";
$gram=<<'_G_'
module : program+ {#!perl
$g->{yo}++;};
statement : "[a-z]+";
program : statement ("\." statement)*;
_G_
;
ok(defined($p = Parser::D->new
	   (grammar => \$gram , d_debug_level => 0
	    , initial_globals => {a_global => 1}
	   )
	  )
   , $test);
ok(@r = $p->run('   yoyo.statement. hello that is silly', 0), $stest);
is(ref($r[0]), 'D_ParseNodePtr', $stest) or diag("did not run");
my $n = 1;
my $c;
ok(defined($c = $r[0]->globals), $stest)
  or diag('$global not defined', Dumper(@r));
$stest= $test . "initial_globals:: initialised";
is($c->{a_global}, 1, $stest)
  or diag("undefined initial global::", Dumper($c));
$stest= $test . "parsed";
is($c->{yo}, $n, $test)
  or diag($test . "::global count ", Dumper($c) );


#
#
#
#test my own white space fn...
$test='white space function::';
$stest= $test . "defined";
sub snow_white {
  my $p = shift;
  my $loc = Parser::D::d_loc_t->new(shift, $p);
  my $s = ${$loc->{buf}};
  pos($s) = $loc->tell;
  #this function takes non-spaces to white-space tokens!
  $s =~ m/\G\w+/gcm;
  $loc->seek(pos($s));
}

$gram=<<'_G_'
module : (program {#!perl
	$g->{yo}++;
	})*;
/*  * is better than + to run the final code */
statement::="[\. ]";
program : statement+;
_G_
;
ok(defined($p = Parser::D->new
	   (grammar => \$gram
	    , initial_skip_space_fn => *snow_white
	   )
	  )
   , $stest)
  or diag($test_jump, 'oopsy dparser is died');

ok(@r = $p->run('   yoyo.statement. hello that is silly', 0), $stest);
ok(defined($c = $r[0]->globals), $stest)
  or diag($test . "::global not defined the script has mistakes");

$stest= $test . "::global count parsed";
is($c->{yo}, 9, $stest)
  or diag("::check grammar or free_node_fn() ", Dumper($c) );


TODO:
do {

  #the _ option

  #  @_


  # the $0, $1, $2...$$

  #the $n0 $n1->val...more a Node thingy

  # the %{$1}

  # the $term -20   $term -1

  #   $# 

};
