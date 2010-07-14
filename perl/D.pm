
=head3 COPYRIGHTS

 @PACKAGE_COPYRIGHT@

=heads1 DParser for Perl Documentation

This page describes the Perl interface to DParser.
Please see the DParser manual for more detailed information on DParser.

=head3 basic ideas

=item arguments to actions

=item arguments to dparser.Parser()

=item arguments to dparser.Parser.parse()

=item pitfalls and tips

=item Basic Ideas

Grammar rules are input to DParser using Python function documentation strings.
A string placed as the first line of a Python function is the function's documentation string.
In order to let DParser know that you want it to use a specific function's documentation string as part of your grammar,
begin that function's name with "d_".

The function then becomes an action that is executed whenever the production defined in the
documentation string reduces. For example,

def d_action1(t): " sentence : noun 'runs' "
print 'found a sentence' #...

This function specifies an action, d_action1, and a production, sentence, to DParser.
d_action1 will be called when DParser recognizes a sentence.
The argument, t, to d_action1 is an array.
The array consists of the return values of the elements making up the production, or, for terminal elements, the string the terminal matched.
In the above example, the array t array will contain the return value of noun's action as the first element
and the Python string 'runs' as the second.
Regular expression are specified by enclosing the regular expression in double quotes:

def d_number(t): ' number : "[0-9]+" '
# match a positive integer return int(t[0])
# turn the matched string into an integer
#...

Make sure your documentation string is a Python raw string (precede it with the letter r)
if it contains any Python escape sequences.
For more advanced features of productions, such as priorities and associativites, see the DParser manual.
For a simple, complete example to add integers, go back to the home page.

=heads3 Arguments to actions

All actions take at least one argument, an array, as described above.
Other arguments are optional. The interface recognizes which arguments you want based on the name you give the argument.
Possible names are:spec, spec_onlyIf an action takes spec,
that action will be called for both speculative and final parses (otherwise, the action is only called for final parses).
The value of spec indicates whether the parse is final or speculative (1 is speculative, 0 is final).

To reject a speculative parse, return dparser.Reject.

If an action takes spec_only, the action will be called only for speculative parses.

The return value of the action for the final parse will be the same Python object that was returned for the speculative parse.

Complete example.

g
DParser's global state.
g is actually an array, the first element of which is the global state.
(Using a one-element array in this manner allows the action to change the global state.)

s
contains an array (a tree, really) of the strings that make up this reduction.
s is useful if the purpose of your parser is to alter some text, leaving it mostly intact.
See here for a complete example.
nodes an array of Python wrappers around the reduction's D_ParseNodes.

They contain information on line numbers and such. See here for useful fields.

this
the D_ParseNode for the current production. ($$ in DParser.)
Again, see this example.

parser
your parser (sometimes useful if you're dealing with multiple files).



=item Arguments to dparser.Parser()

All arguments are optional.

modules:
an array of modules containing the actions you want in your parser.
If this argument is not specified, the calling module will be used.

file_prefix:
prefix for the filename of the parse table cache and other such files.
Defaults to "d_parser_mach_gen"

=item Arguments to dparser.Parser.parse()

The first argument to dparser.
Parser.parse is always the string that is to be parsed.
All other arguments are optional.


start_symbol:
the start symbol. Defaults to the topmost symbol defined.

print_debug_info:
prints a list of actions that are called if non-zero.
Question marks indicate the action is speculative.

dont_fixup_internal_productions
, dont_merge_epsilon_trees
, commit_actions_interval
, error_recovery:
correspond to the members of D_Parser (see the DParser manual)


initial_skip_space_fn:
allows user-defined whitespace (as does the whitespace production, 
and instead of the built-in, c-like whitespace parser).
Its argument is a d_loc_t structure.
This structure's member, s, is an index into the string that is being parsed.
Modify this index to skip whitespace:

def whitespace(loc): # no d_ prefix
while loc.s < len(loc.buf) and loc.buf[loc.s:loc.s+2] == ':)': # make smiley facethe white space
loc.s = loc.s + 2 #...

Parser().parse('int:)var:)=:)2', initial_skip_space_fn = whitespace)

syntax_error_fn:
called on a syntax error. By default an exception is raised.
It is passed a d_loc_t structure (see initial_skip_space_fn) indicating the location of the error. The
function below will put '<--error' and a line break at the location of the error:

def syntax_error(loc):
mn = max(loc.s - 10, 0)
mx = min(loc.s + 10, len(loc.buf))
begin = loc.buf[mn:loc.s]
end = loc.buf[loc.s:mx]
space = ' '*len(begin)
print begin + '\n' + space + '<--error' + '\n' + space + end
#... Parser().parse('python is bad.'
, syntax_error_fn = syntax_error)


ambiguity_fn:
resolves ambiguities.
It takes an array of D_ParseNodes and expects one of them to be returned.
By default a dparser. AmbiguityException is raised.


=heads4 Pitfalls and Tips

Let me know if you run into a pitfall or have a tip, and I will put it here.
 Debugging a GrammarPass print_debug_info=1 to Parser.parse() to see a list of the actions that are being called (pass it 2 to see only final actions). Also, try looking at the grammar file that is created, d_parser_mach_gen.g.Regular expressions:DParser does not understand all of the regular expressions understood by the Python regular expression module. Make sure you are using regular expressions DParser can understand. Also, make sure your documentation string is a Python raw string (precede it with the letter r) if it contains any Python escape sequences.Whitespace:By default, DParser treats tabs, spaces, newlines and #line commands as whitespace. If you want to deal with any of these yourself (especially be careful of the # character), you have to either create an initial_skip_space_fn, as shown above, or define the special whitespace production:def d_whitespace(t)
: 'whitespace : "[ \t\n]*" ' # treat space, tab and newline as whitespace, but treat the # character normally print 'found whitespace:' + t[0]DParser specifiers/declarations:DParser can be passed declarations in documentation strings. For example,from dparser import Parser def d_somefunc(t) : '${declare longest_match}' #...(see the DParser manual for an explanation of specifiers and declarations.)Multiple productions per action:You can put multiple productions (even your entire grammar) into one documentation string. Just make sure to add semicolons after each production:from dparser import Parser def d_grammar(t): '''sentence : noun verb; noun : 'dog' | 'cat'; verb : 'run' ''' print 'this function gets called for every reduction' Parser().parse("dog run")

=cut






package Parser::D::d_loc_t;
#@ISA = qw( d_loc_tPtr ); #T_OBJPTR

=pod public attribs

char * 	s
char * 	pathname
char * 	ws
int 	col
int 	previous_col
int 	line

=cut

sub new {
  my ($class, $this, $p) = @_;
  bless {
	 'this' => $this
	 , d_parser => $p
	 , buf => $p->interface->{buf_start}
	} , $class;
}

sub tell {
 my $self = shift;
 $self->s_get;
}
sub seek {
  s_set(@_);
}

sub pathname {
  my $self = shift;
  my $val = shift || return $self->pathname_get;
  $self->pathname_set($val);
}

sub pathname_get {
  my $self = shift;
  $self->{pathname};
}
sub pathname_set {
  my $self = shift;
  $self->{pathname} = shift;
}


sub previous_col {
  my $self = shift;
  my $val = shift || return $self->previous_col_get;
  $self->previous_col_set($val);
}

sub previous_col_get {
  my $self = shift;
  $self->{previous_col};
}
sub previous_col_set {
  my $self = shift;
  $self->{previous_col} = shift;
}

sub col {
  my $self = shift;
  my $val = shift || return $self->col_get;
  $self->col_set($val);
}
sub col_set {
  my $self = shift;
  $self->{col} = shift;
}


sub line {
  my $self = shift;
  my $val = shift || return $self->line_get;
  $self->line_set($val);
}
sub line_set {
  my $self = shift;
  $self->{line} = shift;
}






=heads2 ParserPtr

module intented to interface Perl objects of "Parser" structure
to Parser.

on the C-Object
Parser.interface1 shall point to this object:
IV ParserPtr.

and the IV of ParserPtr:: perl object to the
C-Object "Parser".



using this object in C:

...
  XPUSHs(sv_setref_pv(newSV(0), "ParserPtr", (void*)p));
...


however this function does not call ParserPtr::new
but the SVRef is blessed to ParserPtr...
but one would need to call bless_interface....


using the Perl Constructor:

yeark! Don't do that.
but if you insist, ParserPtr->new()
would do.



=cut

package ParserPtr;
use Devel::Peek;
use Data::Dumper;
use Carp qw(croak carp);


=heads3 new

the right way to bless the Scalar pointer
to a perl module.


=cut


sub new {
  my $class = shift || __PACKAGE__;
  my $t = $class->SUPER::new(@_);

  # also check for dereferencing p->interface1?!
  # is t->interface1->{this} this?!
  # if not then t->interface1 needs to be duplicated!
  $t->bless_interface;
  return $t;
}

sub DESTROY {
  shift->free_D_Parser;
}

=heads3  ambiguity_fn

  function called when the parser has too many options

  its needs to return a node index which will decides on the NODE child
  to take.

=cut

sub ambiguity_fn {
  my $p = shift;
  my $nodes = shift;
  #map {$_->user} @_ ==> crashes!
  my $u = map($_->user, @$nodes);
  #warn __PACKAGE__ . "::into ambiguity node ptr:" , Dump($nodes);
  # multiple nodes choice
  # TODO shall return the shortest path??
  # randomize, etc...
  # here retro-act on the node path...
  # shortest = most wanted...etc...
  return $#$nodes + 13;
}


=heads3 node_action

a cunning function bridging parser nodes with perl node actions
speculative :
   0 => final_code
   1 => speculative
   2 => action index final
   3 => action index speculative
   4 => map actions

=item TODO 

stuffs like this do not work:

a : c*
c ::= '.'

...
::action[107<119] not defined in table...
...


=cut

sub node_action {
  my $pp = shift;
  my $index_code = shift;
  my $speculative = shift;
  #get the Parser::D object
  my $p = $pp->interface;
  unless(ref($p) eq "Parser::D") {
    warn(__PACKAGE__, "::", Dumper($p), "\n referenced by \n" , Dumper($pp));
    return 1;
  }
  my $f;

  my $i = $#{$p->{tables}{actions}};
  # could do a modulo....
  if(defined($f = $p->{tables}{actions}[$index_code]{__code__})) {
    push @_, $pp;
    my $r = 0;
    eval { $r = &{$f}(@_)};
    if($@) {
      warn __PACKAGE__, "::node_action::perl ERROR::", $@
	, "at symbol::\t", $_[2]->tables->symbol_name($_[0]->symbol)
	  , "\n__code__::", $p->{tables}{actions}[$index_code]{__name__}
	    , "\n";
    }
    return($r);
  } else {
    carp(caller(), 'node_action::action[', $index_code,'<', $i, '] not defined in table');
  }
  return 0;
}


=heads3 white_space_fn

 default inter-token lexical parser.
 called by default from the initial_white_space_fn()

 can be overriden:

  *white_space_fn = \&my_white_space_fn;


=cut

sub white_space_fn {
  my $p = shift;
  #
  #TODO one can be definitly smarter here since
  # shift is already a d_loc_tPtr object...
  # however... d_loc_tPtr is not an HASH, and to work well it needs $ppi->{buf_start}?
  #
  my $loc = Parser::D::d_loc_t->new(shift, $p);

  #warn(__PACKAGE__ , "::initial_white_space_fn ", $loc->{this});

  my $s = $loc->{buf};
  pos($$s) = $loc->tell;

  $$s =~ m/\G\s*/gcm;
  $loc->seek(pos($$s));

  #warn(__PACKAGE__ , "::white_space_fn pos=", $loc->tell, "~", pos($$s)
  #     , "::", Dump($p)
  #     , "::", Dump($loc));
}




sub symbol_name {
  my $p = shift;
  my $symbol = shift;
  return $p->tables->($symbol);
}



=heads2 Parser::D

=pod example of rules

my @rule_code
  = (
     'h : h1 | h2'
      => sub h :type { return $t[0]; }
    );
     , {"h1 : 'a'"
	=> sub h1 :t :spec_only { return 1; }}
     , {"h2 : 'a'"
	=> sub h2 :t :spec {
	  if($spec)
	    return 'dparser.Reject';     # don't let h2 match.  If this were not here, a dparser.AmbiguityException exception would result
	  return 2;
	}
       }
    );


=cut


package Parser::D;

BEGIN { require 5.005 }

use warnings;
#use strict;
use Carp qw(croak carp);
use vars qw($VERSION @ISA $AUTOLOAD $use_XSLoader);
#use Attribute::Handlers;
require AutoLoader;

$VERSION = q[1.14.2];

BEGIN {
    $use_XSLoader = 1 ;
    { local $SIG{__DIE__} ; eval { require XSLoader } ; }
 
    if ($@) {
        $use_XSLoader = 0 ;
        require DynaLoader;
        @ISA = qw(DynaLoader);
    }
}

use base qw(Class::Container Exporter);
use Params::Validate qw(:types);

our %EXPORT_TAGS
  = (
     'all' => [ qw(
		   version
		   loaded_tables
		   make
		   node_action
) ] );

our @EXPORT_OK =  @{$EXPORT_TAGS{'all'}};

our @EXPORT = qw();
our $DEBUG = 2;

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my ($error, $val) = constant($constname);
    Carp::croak $error if $error;
    no strict 'refs';
    *{$AUTOLOAD} = sub { $val };
    goto &{$AUTOLOAD};
}         

use Devel::Peek;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
$Data::Dumper::Indent = 1;
use FileHandle;
use Parser::D::Node;

if ($use_XSLoader)
  { XSLoader::load("Parser::D", $VERSION)}
else
  { bootstrap Parser::D $VERSION }  

our %loaded_tables = ();

__PACKAGE__->valid_params
  (
   # local to Parser::D
   buf_offset        => {default => 0}
   , dont_fixup_internal_productions => {default => 0}
   , dont_merge_epsilon_trees => {default => 0}
   , commit_actions_interval => {default => 0}
   , error_recovery => {default => 1}
   , print_debug_info => {default => 1}
   , partial_parses => {default => 0}
   , dont_compare_stacks => {default => 0}


   , file_prefix => {default =>  ".d_parser"}

   # parser options
   , use_greedyness_for_disambiguation => {default => 0}
   , dont_use_eagerness_for_disambiguation => {default => 1}
   , dont_use_height_for_disambiguation    => {default => 1}

   , fixup_EBNF_productions => {default => 0}

   , save_parse_tree =>
   {default => 1
    , desc => "leave this on for avoiding freeing memory allocation of the parser block after a run"
   }
   , initial_skip_space_fn => {default => undef}

   , initial_globals => {default => {}}  #NULL pointer D_ParseNode_Globals	*
   , initial_scope => {default => undef}    #NULL pointerstruct D_Scope 	*
   , start_token   => {default => ''}

   # user parameters
   , filename    => {default => ''}
   , grammar     => {default => ''
		      , desc =>
  "this is the second level Grammar which will be compiled into a binary table by d-parse."
. "The Grammar can be a string or an ARRAY of procedures with perl coded subroutines."
. "refere to the manual for the syntax."
		}
   # general
   , d_debug_level => {
		       default => 0
		       , descr => "Debug"
		       , type => SCALAR
		      }
   , d_verbose_level => {
			 default => 0
			 , descr => "Verbose"
			 , type => SCALAR
			}
   , description => {optional => 1}
  );

__PACKAGE__->contained_objects
  (
   g         => {class => 'Parser::D::Grammar', delayed => 1 }
   , tables  => {class => 'Parser::D::Tables', delayed => 1 }
  );


=heads3 new

  the new function will create an instance of Parser::D,
  but also possibly compile its grammar, and load resulting tables,
  the objects containing states, transitions (shifts, gotos), but
  also compiles any perl sub-routines attached to the states.
  finaly initialise the jump-start and the parser
  would be ready to run... all this.

=heads4 SYNOPSIS


=heads4 INPUT



=pod arguments for parser

  #, sig     => {class => 'Digest::MD5', delayed => 1 }
  #symbols[nsymbols].{name,kind{D_SYMBOL_NTERM}}

=cut

sub new {
  my $class = shift || __PACKAGE__;
  my $d = $class->SUPER::new(@_);
  # ..or directly create the SV called by initial_white_space_fn()
  if(defined($d->{initial_skip_space_fn})) {
    *ParserPtr::white_space_fn = $d->{initial_skip_space_fn};
  }
  # may be do a group commande here...
  $d->make_gramma(undef, undef, @_);
  $d->load_tables(undef, @_);
  $d->{top_node} = $d->init;
  #
  # ready to go!
  return $d;
}


=heads3 update_dictionary

this function is the first to start in order to gather the grammar string.
here we will format the 'filename' or the 'grammar' string,
as well as the 'signature'.


=item SYNOPSIS

my $grammar =<<'PROCEDURES'
 h: h1 | h2;
 h1: "[a-z]+"
{
  print "hello}";
  $reject;
};
 h2: '.'
 ( $1; )
 | ';'
 [ $$ ];

PROCEDURES
;

my $parser = new Parser::D;
$parser->update_dictionary($grammar);
$parser->update_dictionary('', $grammar_file);



=cut

sub make_gramma {
  my $d = shift || return undef;
  #
  # force rewrite of gramma
  my $gs = shift || $d->{grammar};
  my $f  = shift || $d->{filename};
  my %b = (@_);
  my %c;
  foreach (keys(%{Parser::D::Grammar->allowed_params})) {
    $c{$_} = $b{$_} if(defined $b{$_});
  }
  my $g = $d->create_delayed_object
    ('g'
     , filename => $f
     , grammar => $gs
     , %c
    );
  $g->make;
  if($d->{d_debug_level} > 8) {
    $g->print_rdebug_grammar;
  }
  $g->write_file;
  # bye bye grammar...
  $d->{filename} =  $g->{filename};
  $d->{signature} = $g->{signature};
  #$d->{grammar} = $g->{grammar};
  #      'contained' => HASH(0x10610b30)
  #       'g' => HASH(0x10610a88)
  #          'args' => HASH(0x10610b9c)
  #             'grammar' => 'ye : yea* yee* titi* yo* {#!perl
  #
}

=heads3 load_tables

easy function which prepares the da-parsing tables.


=cut


sub load_tables {
  my $d = shift || return undef;
  my $f = shift  || $d->{filename};
  unless(-f $f || -f $f . '.' . $d->{signature} . '.c') {
    $f = $d->{filename} = '.g';
  }
  push @_, filename => $f;
  push @_, signature => $d->{signature};
  my %b = (@_);
  my %c;
  foreach (keys(%{Parser::D::Tables->allowed_params})) {
    $c{$_} = $b{$_} if(defined $b{$_});
  }
  $d->{tables} = $d->create_delayed_object('tables', %c);
}

=heads3 init

parse internal variables from perl to D-Parser object.
This call need to be done before the run and after the tables
are loaded.

=item INPUT

the Parser::D object.
optionaly the string 'start_token' production.

=item OUTPUT

amongs others,
the associated pointer C object DParserPtr.

=cut

sub init {
  my $self = shift || return undef;
  my $start = shift || $self->{start_token};
  if(defined($self->{tables}{this})) {
    $self->{this} = $self->make($self->{tables}{this}, $start);
  } else {
    carp(__PACKAGE__, "::init tables not done yet made...rerun init...");
  }
  $self->{start_token} = $start;
  @{$self->{ERR}} = ();
  return $self->{this};
}


=heads3  run

=item DESCRIPTION

alas complete or compiles the user scripts using the grammar tables prepared earlier.

a script needs to be provided in the form of a string or a scalar to a string
(prefered if your script is greater than 10K).

a second arguments will provide a starting offset into the script.

in returns an array of two objects are given.

the "top_node" this is the pointer object of the last Node processed.
it shall refere to the (Top) Entry Node of the grammar.

also an array of error hash objects.
each of those hash ojects have keys ERR, ERL, ERC, defined by the default
error function (c.f. <\C>syntax_error_fn<>). These can be changed!

TODO:
the run function is not re-entrent...the parser looses its state at exist of a run.
there might be an option I missed to do so.


=item SYNOPSIS

 my $p = Parser::D->new(grammar => 'hello: "[a-z]"+;');
 my ($r, $e) =  $p->run(' abc ');

=cut

sub run {
  my $ppi = shift;
  my $string = shift || return undef;
  my $string_p = (ref($string) eq 'SCALAR' ? $string : \$string);
  # pointer reference to string....
  # offsetting the grammar Tables altogether...
  $ppi->{buf_start} = $string_p;
  # also offsetting the parsing buffer?
  my $buf_idx = shift || 0;
  unless($buf_idx && exists($ppi->{ERR})) {
    @{$ppi->{ERR}} = ();
  }
  my $l = length($$string_p) - $buf_idx;
  my $p = $ppi->{this} || $ppi->init(@_); #??

  # get the Parser::D::Node...Ptr or might to change to node object!
  $ppi->{parsing} = 1;
  my $pn = $ppi->{top_node} = $ppi->dparse($buf_idx, $l);
  $ppi->{parsing} = 0;
  #
  # or $dp->syntax_errors
  if($ppi->syntax_errors && ($ppi->syntax_errors > $#{$ppi->{ERR}})) {
    # not done auto magically...??
    $ppi->syntax_error_fn;
  }
  # I might want to proceed all nodes:
  #unless(defined($pn->user)) {
  # this is to reference ->user, else it disappears.
  #$pn->user($u = $ppi->commit_children($pn));
  #}
  #warn Dumper($pn);
  return ($pn,  $ppi->{ERR});
}



=heads3 commit_children

nifty function which executes all the actions of descendent nodes.
a list of node actions are registered in the node children list
ordered by their apearence in the grammar.

	parent		children

	 .
   ->	node-a#? --->	| node-b#0 |	---> ...| node-e#?
			| node-c#1 |	.
			...		.
			| node-d#n |	.



there is also a mean to resolve ambiguity of node cycles using weights.
check it out.


ARGUMENTS
ppi perl parser object __PACKAGE__
dpn the d-parser node pointer .

RETURNS
this function is self calling (recurring)
it will return the user field of the dpn.

=cut

sub commit_children {
  my $ppi = shift;
  my $dpn = shift || return 0;
  # run actions?! now...
  my $v = $dpn->children_list;
  my $u;
  foreach my $c_pn (@$v) {
    print "commit_children::", Dumper($c_pn->val);
    # here call to commit_children
    $u = $ppi->commit_children($c_dpn);
  }
  #exec final action?
  unless(defined($dpn->user)) {
    $ppi->{this}->node_action($dpn->action_index, 1, $dpn, $v);
    unless(defined($dpn->user)) {
      ($u) = grep(defined, map($_->user || $_->val, @$v));
       $dpn->user($u);
    } else {
      $u = $dpn->user;
    }
  } else {
    $u = $dpn->user;
  }
  warn caller() . "::commit_children::", Dumper($dpn->user), Dump($dpn->user);
  return $u;
}

=heads3 syntax_errors

link to the dparser syntax errors variable.
it is a read only function I am afraid.
this variable is a counter of reported syntax errors during the run.

=cut

sub syntax_errors {
 shift->{this}->syntax_errors(@_);
}

sub DESTROY {
  my $p = shift;
  unless(defined($p->{this})) {
    carp(caller() . "::DESTROY::", $p, "with undef D_ParseNodePtr");
    return;
  }
  #considere freeing nodes automatically in D_ParseNodePtr...
  if(defined($p->{top_node})) {
    # hofully the user copy of the nodes are kept!
    $p->{top_node}->free_D_ParseTreeBelow($p->{this});
    $p->{top_node}->free_D_ParseNode($p->{this});
  }
}

=heads3 loc_type

silly function which
returns a Parser::D::d_loc_t object.

=cut

sub loc_type {
  my $ppi = shift;
  my $p = $ppi->{this} || return;
  return Parser::D::d_loc_t->new($p->loc, $p, @_);
}


#
#D_ParseNodePtr = Parse::D::Node ISA?!
# nice!
# C equivalent of make_pl_node
# used to link a Parser::D::Node 
# perl object to a D_ParseNode* pointer.
# the thing is I do not know what to do whith thi
# new perl object?!
#

## do this in ParseNodePtr, Parse::D::Node 
sub node_info_type {
  my $p = $_[0];
  push @_, $p->{buf_start};
  warn(__PACKAGE__,"::node_info_type:: @_");
  #Parser::D::Node->new(@_);
}



=heads3 syntax_error_fn

default __PACKAGE__ error handler

this handler just try to locate and report the error detected in the user script.

it pushed in the ERR array the locy (Parser::D::d_loc_t) and a simple descriptive string.
in the HASH {ERL,ERS}.


=cut

sub syntax_error_fn
{
  my $ppi = shift;
  return if($ppi->{error_recovery}-- > 0);
  my $p = $ppi->{this};
  my $loc = Parser::D::d_loc_t->new($p->loc, $p);
  my $ee = '...';
  my $be = '...';
  my $width = 25;
  my $loc_s = $loc->tell;
  my $mn = $loc_s - $width;
  if ($mn < 0) {
    $mn = 0;
    $be = '';
  }
  my $mx = $width;
  my $s = $loc->{buf};
  if($mx > length($$s)) {
    $mx = length($$s);
    $ee = '';
  }
  my $begin = substr($$s, $mn, $loc_s - $mn);
  my $end = substr($$s, $loc_s, $mx);
  my $string
    = __PACKAGE__ . "::syntax_error_fn::#[" . $p->syntax_errors
      . "]\tline:" . $loc->line_get . "\n"
	. $be . $begin .  '[SNERR0R]'
	  . $end . $ee . "\n\n";
  carp($string);
  # save ERROR message.
  push(@{$ppi->{ERR}}
       , {ERI => $loc->tell
	  , ERC => $loc->col
	  , ERL => $loc->line
	  , ERS => $string
	 }
      );
  return;
}






# Autoload methods go after _ _E ND__, 
#and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!