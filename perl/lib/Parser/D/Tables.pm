#
# $Id$
#
# $Log$
#
#
#

package D_ParserTablesPtr;
use Parser::D;

sub new {
  my $class = shift || __PACKAGE__;
  my $t = $class->SUPER::new(@_);
  return $t;
}

sub DESTROY {
  # might want to unallocate {this} tables?
  shift->free;
}


package Parser::D::Tables;
#use strict;
use base qw(Class::Container);
use Params::Validate qw(:types);
use Carp qw(croak);
use Parser::D;
use FileHandle;
use Data::Dumper;
use Devel::Peek;

__PACKAGE__->valid_params
  (
   filename     => {default => ""}
   #, this => {isa => 'D_ParserTablesPtr'}
   , actions    => {default => []}
   , signature  => {default => ""}
   , d_debug_level => {
		       default => 0
		       , descr => "Debug - obsolete"
		       , type => SCALAR
		      }
   , log_level =>
   {
    default => 0
    , descr => "logging verbosity levels: info, debug, all..."
    , type => SCALAR
   }
  );

__PACKAGE__->contained_objects
  (
   tables_p => {class => 'D_ParserTablesPtr', delayed => 1}
 );


=heads3 new

just doitallsingingndancing by using this constructor.
it would call load_parser and load_code so this could be the only external function
to call in order to initialyse a parser table.

INPUT:
optional 'filename' the complete name of grammar
 (a suffixe .c will be added later).
optional 'actions' an ordered array of subroutines.


=cut

sub new {
  my $class = shift || __PACKAGE__;
  my $t = $class->SUPER::new(@_);
  $t->load_parser;
  $t->load_code;
  return $t;
}

sub load_parser {
  my $self = shift || undef;
  my $s = shift
    || (defined($self)
	? (ref($self) eq 'Parser::D::Tables'
	   ? $self->{filename} . '.d_parser.' . $self->{signature} . '.o'
	   : $self
	  )
	: '');
  unless(ref($self) eq 'Parser::D::Tables') {
    push(@_, filename => $s) unless(length($s) >= 0x100);
    $self = __PACKAGE__->new(@_);
    return($self) if(defined($self->{this}));
  }
  if(length($s) < 0x100 && (-f $s)) {
    $self->{this}
      = Parser::D::Tables::read_binary($s);
  } elsif(ref($s) eq 'FILE') {
    $self->{this}
      = Parser::D::Tables::read_binary_from_file($s);
  } elsif(length($s) >= 0x100) {
    $self->{this}
      = Parser::D::Tables::read_binary_from_string($s);
  }
  return $self;
}



=heads3 load_code

=item DESCRIPTION:

an important link in this package.

this module is typically run before starting crunching the decoder/encoder.
It would integrate and perl compile the functions attached to each procedures
and elements of the D-Parser's rules.

they are three classes of such fonctions :
 - the 'index_action', the speculative and final actions.
 - the 'map_action', reduced from ${action ??}
 - the 'action'

this is done by text extraction (parsing!) of the 'grammar'.c file resulting from
Parser::D::Grammar::write_table|string|file methods.

Although, the D-Parser package will automagically recognise perl scripting
as soon as a "#!perl" is introduced in the EBNF script.

It then translates the default C-functions call and the internal syntax into perl syntax
strings.

This method would also cover more translation in case the d-parser one does not work!

=item TODO:

-I also started another method of integrating production/elements mapped functions
 into the table, by directly entering an array, but traded this for that. 
It might have been usefull (c.f. python interface).
-the panoply of transforms is incomplete.

=item INPUT:
an optional Parser::D::Tables object
an optional 'filename' (the sufixe '.c' will be attached if not defined).

=item OUTPUT:
adds to the Parser::D::Tables object an indexed table of CODE (subroutines)
in HASH refered by 'index_action', 'map_action' and 'action'.

=cut

sub load_code {
  my $self = shift || undef;
  my $s = shift
    || (defined($self)
	? (ref($self) eq 'Parser::D::Tables'
	   ? $self->{filename} . '.' . $self->{signature} . '.c'
	   : $self
	  )
	: '');

  (-f $s) and do {
    # yeeehaaaa yet another parser of parsing parser
    #
    my $fh = new FileHandle($s, "r");
    if(defined $fh) {
      #do it, parsssssse another time...
      # get to create the table...of c functions.
      my $lines = '';
      my $redu_index = 1;
      my @default_index;
      while(<$fh>) {
	#
	# join lines until a /^#line \d+
	$lines .= $_;

	#
	#detect default functions:
	#
	/^int d_speculative_reduction_code_(\d+)_(\d+)_\w+\(.*_parser\);$/ && do {
	  $redu_index++ unless($redu_index > 2);
	  (@{$default_index[0]}) = ($1, $2);
	  $lines = '';
	};
	/^int d_final_reduction_code_(\d+)_(\d+)_\w+\(.*_parser\);$/ && do {
	  $redu_index++ unless($redu_index > 2);
	  (@{$default_index[1]}) = ($1, $2);
	  $lines = '';
	};

	/^#line \d+/ && do {
	  #(void *_ps, void **_children, int _n_children, int _offset, D_Parser *_parser)
	  my $index_code;
	  my $map_code;
	  my (@final_reduction_code) = $lines =~ m/int d_final_reduction_code_(\d+)_(\d+)_/g;
	  my (@speculative_reduction_code) = $lines =~ m/int d_speculative_reduction_code_(\d+)_(\d+)_/g;

	  my ($core) = $lines =~ m/\)\s*(\{.*\})\s*\#line/gs;
	  if($core) {
	    # $# => $#{$_[1]}
	    $core =~ s/\(_n_children\)/\$\#\$\_[1]/g;

	    # $#\d+ => $#{$_[1][\d+]}
	    $core =~ s/\(d_get_number_of_children\(\(D_PN\(_children(\[\d+\])\, _offset\)\)\)\)/\$\#\$\_[1]$1/g;

	    # $g => $g
	    $core =~ s/\(D_PN\(_ps\, _offset\)->globals\)/\$\_[0]->globals/g;

	    # $n\d+ => $_[1][\d+]
	    $core =~ s/\(\*\(D_PN\(_children(\[\d+\])\, _offset\)\)\)/\$\$\_[1]$1/g;

	    # $n => $_[0]
	    $core =~ s/\(D_PN\(_ps\, _offset\)\)/\$\_[0]/g;

	    # $$ => $_[0]->user or $u will do the job...
	    #
	    $core =~ s/\(D_PN\(_ps\, _offset\)->user\)/\$\_[0]->user/g;
	    
	    #$\d+ => $_[1][\d+]->user...
	    $core =~ s/\(D_PN\(_children(\[\d+\])\, _offset\)->user\)/\$\_[1]$1->user/g;

	    #${ child , \d+ } => (D_PN(_children[%s], _offset)) d_get_child(%s, %s)

	    #${ reject   }  => return -1

	    #${ free_below   } free_D_ParseTreeBelow(_parser, (D_PN(_ps, _offset)))
	    # todo...

	    #${scope} => (D_PN(_ps, _offset)->scope)
	    $core =~ s/\(D_PN\(_ps\, _offset\)->scope\)/\$\_[0]->scope/g;

	    #${parser} => _parser => $_[2]
	    $core =~ s/_parser/\$\_[2]/g;
	    
	    #${nterm}  => \d+ from find_symbol(g, e, a, D_SYMBOL_NTERM));
	    #${string} => \d+  from find_symbol(g, e, a, D_SYMBOL_STRING));
	    #${pass}   => \d+ find_pass(g, e, a)->index

=pod load_code: yet other stuff to worry about

${pass sym for_all postorder}
${pass gen for_all postorder}

{
int myscanner(char **s, int *col, int *line, unsigned short *symbol,
      int *term_priority, unsigned short *op_assoc, int *op_priority)
{
if (**s == 'a') {
    (*s)++;
    *symbol = A;
    return 1;
}
}
${scanner myscanner}
${token A BB CCC DDDD}
$0.symbol == ${string parameter_comma}

$name 


$# - number of child nodes
$$ - user parse node state for parent node (non-terminal defined by the production)
$X (where X is a number) - the user parse node state of element X of the production
$nX - the system parse node state of element X of the production

${scope} - the current symbol table scope
${reject} - in speculative actions permits the current parse to be rejected
*  initial_globals - the initial global variables accessable through $g
* initial_skip_space_fn - the initial whitespace function
* syntax_error_fn - the function called on a syntax error
* ambiguity_fn - the function called on an unresolved ambiguity
* loc - the initial location (set on an error).
*  sizeof_user_parse_node - the sizeof D_ParseNodeUser
* save_parse_tree - whether or not the parse tree should be save once the final actions have been executed
* dont_fixup_internal_productions - to not convert the Kleene star into a variable number of children from a tree of reductions
* dont_merge_epsilon_trees - to not automatically remove ambiguities which result from trees of epsilon reductions without actions
* dont_use_eagerness_for_disambiguation - do not use the rule that the longest parse which reduces to the same token should be used to disambiguate parses.  This rule is used to handle the case (if then else?) relatively cleanly.
* dont_use_height_for_disambiguation - do not use the rule that the least deep parse which reduces to the same token should be used to disabiguate parses.  This rule is used to handle recursive grammars relatiively cleanly.
* dont_compare_stacks - disables comparing stacks to handle certain exponential cases during ambiguous operator priority resolution.  This feature is relatively new, and this disables the new code.
* commit_actions_interval - how often to commit final actions (0 is immediate, MAXINT is essentially not till the end of parsing)
* error_recovery - whether or not to use error recovery (defaults ON)

=cut

	    my %acte = (
			__name__ => "node f:@final_reduction_code s:@speculative_reduction_code c:$core"
		       );
	    $acte{__code__} = eval "sub $core" || undef;
	    if($self->{log_level} > 1) {
	      warn(sprintf("\n\[%x\]=>", $redu_index), "f:@final_reduction_code s:@speculative_reduction_code c:$core\n");
	    }
	    if(@speculative_reduction_code) {
	      if(@default_index
		 && $speculative_reduction_code[0] == $default_index[0][0]
		 && $speculative_reduction_code[1] == $default_index[0][1]
		) {
		$self->{actions}[1] = \%acte;
	      } else {
		$self->{actions}[$redu_index] = \%acte;
	      }
	      $redu_index++;
	    } elsif(@final_reduction_code) {
	      if(@default_index
		 && $final_reduction_code[0] == $default_index[1][0]
		 && $final_reduction_code[1] == $default_index[1][1]
		) {
		$self->{actions}[2] = \%acte;
	      } else {
		$self->{actions}[$redu_index]  = \%acte;
	      }
	      $redu_index++;
	    } elsif($index_code) {
	      # it could have been an aray but speculative and final local code needs realy to be hashed
	      $self->{index_actions}[$index_code] = \%acte;

	    } elsif($map_code) {
	      $self->{map_actions}[$map_code] = \%acte;
	    }
	  }
	  $lines = '';
	};
      }
    }
  }; # do file $s
  return $self;
}

sub dump {
  my $self = shift || undef;
  $self->{this}->dump;
}

1;

__END__
