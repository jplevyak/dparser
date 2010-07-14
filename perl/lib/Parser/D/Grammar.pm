#
# $Id$
#
# $Log$
#
#
#





=head0 Parser::D::Grammar


 Module controling compilation of the Parser::D first rules, also called grammar.

 The grammar is compiled into Parser::Tables.

 Remarquably the D-Parser's gramma can be re-compiled at run time.

 Those Tables will be accessed later by D-Parser second step compilation
 in order to compile the target parser Script.

 the syntax of D-Parser scripting is reflected into this gramma
 and more information will be found in DParser's manual.

 In short, the gramma ressambles closely to (E)BNF syntax.

 Now, this module is more usefull for presenting the internal grammar tables
 to the DParser script-compilator.



=head2 SYNOPSIS:

    my $gram_str = $Parser::D::Gramma::gramgram;
    my $g = Parser::D::Grammar->new(grammar => $gram_str);
    $g->make;

    my $s = $g->write_string;

    my $t = $g->write_tables;

    my $f = $g->write_file;



=head3 new

=head4  OPTIONS:

=item grammar

=item d_verbose_level


=item filename

   #/* grammar construction options */

=item set_op_priority_from_rule

	default 0
	Set Operator Priority From Rule

=item   right_recursive_BNF

 => {default => 0, descr => "Use Right Recursion For */+"}


=item   states_for_whitespace

 => {default => 1, descr => "Compute Whitespace States"}

=item    states_for_all_nterms

 =>  {default => 1, descr => "Compute States For All NTERMs"}

=item    tokenizer

 =>  {default => 0, descr => "Tokenizer for START"}

=item    longest_match

 =>  {default => 0, descr => "Use Longest Match Rule for Tokens"}

   #/* grammar writing options */

=item    grammar_ident =>  {default => "gram", descr => "Grammar Identifier"}

=item    scanner_blocks =>  {default =>  4, descr => "Scanner Blocks"}

=item    scanner_block_size =>  {default =>  0}

=item    write_line_directives =>  {default =>  1, descr => "Write #line(s)"}

=item    write_header =>  {default =>  -1, descr => "Write Header (-1:if not empty)"}

=item    token_type =>  {default =>  0, descr => "Token Type (0:define, 1:enum)"
		    }
=item    write_extension

 => {default =>  "o"
			 , descr => "Code file extension (e.g. cpp)"
			}

=item   ident_from_filename

 => {default => 0
 			     , descr => "Use Filename as Identifier"
			    }


   # verbosity
=item    , d_rdebug_grammar_level => {
				default => 0
				, descr => "Replace actions with ones printing productions"
				, type => SCALAR
			       }
=item   , d_verbose_level => {
			 default => 2
			 , descr => "Verbose"
			 , type => SCALAR
			}
=item    , d_debug_level => {
		       default => 077
		       , descr => "Debug"
		       , type => SCALAR
		      }
  );

=cut

package Parser::D::Grammar;
use base qw(Class::Container);
use Params::Validate qw(:types);
use Carp qw(croak);
use FileHandle;
require Parser::D;
use Digest::MD5 qw(md5_hex);

=head3 $Parser::D::Grammar::gramgram

 This the string variable showing the internal rules of DParser grammar.
 It is also found in the DParser file:

  grammar.g
 
 Although it could be compiled at run time by Perl,
 the resulting Tables have already compiled in the library, and
 are accessed by the global variable:

  D_ParserTables parser_tables_dparser_gram;


=item TODO:

 At this time, the D-Parser Perl package does not handle all the functions
 inside this gramma, so it is more likely that this won't compile
 successfully!

=cut


our $gramgram =<< '_GRAM_'
/*
 Grammar Grammar
 */
{#!perl
#include "Dxs.h"
}

grammar: top_level_statement*;

top_level_statement: global_code | production | include_statement;

include_statement: 'include' regex {
  char *grammar_pathname = dup_str($n1.start_loc.s+1, $n1.end-1);
  if (parse_grammar($g, grammar_pathname, 0) < 0)
    d_fail("unable to parse grammar '%s'", grammar_pathname);
  FREE(grammar_pathname);
};

global_code
  : '%<' balanced_code* '%>'
    { add_global_code($g, $n0.start_loc.s+2, $n2.end-2, $n0.start_loc.line); }
  | curly_code { add_global_code($g, $n0.start_loc.s+1, $n0.end-1, $n0.start_loc.line); }
  | '${scanner' balanced_code+ '}' {
      $g->scanner.code = dup_str($n1.start_loc.s, $n1.end);
      $g->scanner.line = $n0.start_loc.line;
    }
  | '${declare' declarationtype identifier* '}' {
      if (!d_get_number_of_children(&$n2))
     	add_declaration($g, $n2.start_loc.s, $n2.end,  $1.kind, $n2.start_loc.line);
      else {
	int i, n = d_get_number_of_children(&$n2);
	for (i = 0; i < n; i++) {
	  D_ParseNode *pn = d_get_child(&$n2, i);
	  add_declaration($g, pn->start_loc.s, pn->end,  $1.kind, pn->start_loc.line);
	}
      }
    }
  | '${token' token_identifier+ '}'
  | '${pass' identifier pass_types '}' {
      add_pass($g, $n1.start_loc.s, $n1.end,  $2.kind, $n1.start_loc.line);
    }
  ;

pass_types
  : 
  | pass_type pass_types { $$.kind = $0.kind | $1.kind; }
  ;

pass_type 
  : 'preorder' { $$.kind |= D_PASS_PRE_ORDER; } 
  | 'postorder' { $$.kind |= D_PASS_POST_ORDER; }
  | 'manual' { $$.kind |= D_PASS_MANUAL; }
  | 'for_all'  { $$.kind |= D_PASS_FOR_ALL; }
  | 'for_undefined' { $$.kind |= D_PASS_FOR_UNDEFINED; }
  ;

declarationtype
  : 'tokenize' { $$.kind = DECLARE_TOKENIZE; } 
  | 'longest_match' { $$.kind = DECLARE_LONGEST_MATCH; }
  | 'whitespace' { $$.kind = DECLARE_WHITESPACE; }
  | 'all_matches' { $$.kind = DECLARE_ALL_MATCHES; }
  | 'set_op_priority_from_rule' { $$.kind = DECLARE_SET_OP_PRIORITY; }
  | 'all_subparsers' { $$.kind = DECLARE_STATES_FOR_ALL_NTERMS; }
  | 'subparser' { $$.kind = DECLARE_STATE_FOR; }
  | 'save_parse_tree' { $$.kind = DECLARE_SAVE_PARSE_TREE; }
  ;

token_identifier: identifier { new_token($g, $n0.start_loc.s, $n0.end); };

production 
  : production_name ':' rules ';' 
  | production_name regex_production rules ';'
  | ';';
regex_production : '::=' { 
  $g->p->regex = 1; 
}; 

production_name : (identifier | '_') { $g->p = new_production($g, dup_str($n0.start_loc.s, $n0.end)); } ;

rules : rule ('|' rule)*; 

rule : new_rule ((element element_modifier*)* simple_element element_modifier*)? rule_modifier* rule_code {
  vec_add(&$g->p->rules, $g->r);
};

new_rule : { $g->r = new_rule($g, $g->p); };

simple_element
  : string { $g->e = new_string($g, $n0.start_loc.s, $n0.end, $g->r); }
  | regex { $g->e = new_string($g, $n0.start_loc.s, $n0.end, $g->r); }
  | identifier { $g->e = new_ident($n0.start_loc.s, $n0.end, $g->r); }
  | '${scan' balanced_code+ '}' { $g->e = new_code($g, $n1.start_loc.s, $n1.end, $g->r); }
  | '(' new_subrule rules ')' {
      $g->e = new_elem_nterm($g->p, $1.r);
      $g->p = $1.p;
      $g->r = $1.r;
      vec_add(&$g->r->elems, $g->e);
    }
  ;

element
  : simple_element
  | bracket_code {
      Production *p = new_internal_production($g, NULL);
      Rule *r = new_rule($g, p);
      vec_add(&p->rules, r);
      r->speculative_code.code = dup_str($n0.start_loc.s + 1, $n0.end - 1);
      r->speculative_code.line = $n0.start_loc.line;
      $g->e = new_elem_nterm(p, $g->r);
      vec_add(&$g->r->elems, $g->e);
    }
  | curly_code {
      Production *p = new_internal_production($g, NULL);
      Rule *r = new_rule($g, p);
      vec_add(&p->rules, r);
      r->final_code.code = dup_str($n0.start_loc.s + 1, $n0.end - 1);
      r->final_code.line = $n0.start_loc.line;
      $g->e = new_elem_nterm(p, $g->r);
      vec_add(&$g->r->elems, $g->e);
  }
  ;

new_subrule : {
  $$.p = $g->p;
  $$.r = $g->r;
  $g->p = new_internal_production($g, $g->p);
  $g->r = 0;
};

element_modifier 
  : '$term' integer { 
      if ($g->e->kind != ELEM_TERM) 
        d_fail("terminal priority on non-terminal");
      $g->e->e.term->term_priority = strtol($n1.start_loc.s, NULL, 0); 
    }
  | '$name' (string|regex) { 
      if ($g->e->kind != ELEM_TERM) 
	d_fail("terminal name on non-terminal");
      $g->e->e.term->term_name = dup_str($n1.start_loc.s+1, $n1.end-1); 
    }
  | '/i' { 
      if ($g->e->kind != ELEM_TERM) 
	d_fail("ignore-case (/i) on non-terminal");
      $g->e->e.term->ignore_case = 1; 
    }
  | '?' { conditional_EBNF($g); }
  | '*' { star_EBNF($g); }
  | '+' { plus_EBNF($g); } ;

rule_modifier : rule_assoc rule_priority | external_action;

rule_assoc
  : '$unary_op_right' { $g->r->op_assoc = ASSOC_UNARY_RIGHT; }
  | '$unary_op_left' { $g->r->op_assoc = ASSOC_UNARY_LEFT; }
  | '$binary_op_right' { $g->r->op_assoc = ASSOC_BINARY_RIGHT; }
  | '$binary_op_left' { $g->r->op_assoc = ASSOC_BINARY_LEFT; }
  | '$unary_right' { $g->r->rule_assoc = ASSOC_UNARY_RIGHT; }
  | '$unary_left' { $g->r->rule_assoc = ASSOC_UNARY_LEFT; }
  | '$binary_right' { $g->r->rule_assoc = ASSOC_BINARY_RIGHT; }
  | '$binary_left' { $g->r->rule_assoc = ASSOC_BINARY_LEFT; }
  | '$right' { $g->r->rule_assoc = ASSOC_NARY_RIGHT; }
  | '$left' { $g->r->rule_assoc = ASSOC_NARY_LEFT; }
  ;

rule_priority : integer { 
  if ($g->r->op_assoc) $g->r->op_priority = strtol($n0.start_loc.s, NULL, 0); 
  else $g->r->rule_priority = strtol($n0.start_loc.s, NULL, 0); 
};

external_action
  : '${action}' { $g->r->action_index = $g->action_index++; }
  | '${action' integer '}' { $g->r->action_index = strtol($n1.start_loc.s, NULL, 0); }
  ;

rule_code : speculative_code? final_code? pass_code* ;

speculative_code : bracket_code {
  $g->r->speculative_code.code = dup_str($n0.start_loc.s + 1, $n0.end - 1);
  $g->r->speculative_code.line = $n0.start_loc.line;
};

final_code : curly_code {
  $g->r->final_code.code = dup_str($n0.start_loc.s + 1, $n0.end - 1);
  $g->r->final_code.line = $n0.start_loc.line;
};

pass_code : identifier ':' curly_code {
  add_pass_code($g, $g->r, $n0.start_loc.s, $n0.end, $n2.start_loc.s+1,
    $n2.end-1, $n0.start_loc.line, $n2.start_loc.line);
};

curly_code: '{' balanced_code* '}';
bracket_code: '[' balanced_code* ']';
balanced_code 
  : '(' balanced_code* ')' | '[' balanced_code* ']' | '{' balanced_code* '}'
  | string | identifier | regex | integer | symbols;
symbols : "[!~`@#$%^&*\-_+=|:;\\<,>.?/]";
string: "'([^'\\]|\\[^])*'";
regex: "\"([^\"\\]|\\[^])*\"";
identifier: "[a-zA-Z_][a-zA-Z_0-9]*" $term -1;
integer: decimalint | hexint | octalint;
decimalint: "-?[1-9][0-9]*[uUlL]?";
hexint: "-?(0x|0X)[0-9a-fA-F]+[uUlL]?";
octalint: "-?0[0-7]*[uUlL]?";
_GRAM_
;

=pod Public Attributes

file:///H:/prj/trace/html/d5/d1f/structGrammar.html
char * 	pathname
Code 	scanner
Code * 	code
int 	ncode
char * 	default_white_space
int 	set_op_priority_from_rule
int 	right_recursive_BNF
int 	states_for_whitespace
int 	states_for_all_nterms
int 	tokenizer
int 	longest_match
int 	save_parse_tree
char 	grammar_ident [256]
int 	scanner_blocks
int 	scanner_block_size
int 	write_line_directives
int 	write_header
int 	token_type
int 	write_cpp
char 	write_extension [256]
Production * 	p
Rule * 	r
Elem * 	e
int 	action_index
int 	action_count
int 	pass_index
int 	rule_index
int 	write_line
char * 	write_pathname


=cut

__PACKAGE__->valid_params
  (# input.
   filename => {default => ".g"}
   , grammar => {default => ''}
   , make_grammar_file => {default => 0}

   #/* grammar construction options */
   , set_op_priority_from_rule => {default => 0, descr => "Set Operator Priority From Rule"}
   , right_recursive_BNF => {default => 0, descr => "Use Right Recursion For */+"}
   , states_for_whitespace => {default => 1, descr => "Compute Whitespace States"}
   , states_for_all_nterms =>  {default => 1, descr => "Compute States For All NTERMs"}
   , tokenizer =>  {default => 0, descr => "Tokenizer for START"}
   , longest_match =>  {default => 0, descr => "Use Longest Match Rule for Tokens"}

   #/* grammar writing options */
   , grammar_ident =>  {default => "gram", descr => "Grammar Identifier"}
   , scanner_blocks =>  {default =>  4, descr => "Scanner Blocks"}
   , scanner_block_size =>  {default =>  0}
   , write_line_directives =>  {default =>  1, descr => "Write #line(s)"}
   , write_header =>  {default =>  -1, descr => "Write Header (-1:if not empty)"}
   , token_type =>  {default =>  0, descr => "Token Type (0:define, 1:enum)"
		    }
   , write_extension => {default =>  ""
			 , descr => "Code file extension (e.g. cpp)"
			}
   , ident_from_filename => {default => 0
			     , descr => "Use Filename as Identifier"
			    }


   # verbosity
   # shall map this to a log level (ie. from syslog)
   , d_rdebug_grammar_level => {
				default => 0
				, descr => "Replace actions with ones printing productions"
				, type => SCALAR
			       }
   , d_verbose_level => {
			 default => 1
			 , descr => "Verbose"
			 , type => SCALAR
			}
   , d_debug_level => {
		       default => 0
		       , descr => "Debug"
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
   grammar_p => {class => 'GrammarPtr', delayed => 1}
 );

sub new {
  my $class = shift || __PACKAGE__;
  my $g = $class->SUPER::new(@_);
  # or use create_delayed_object('grammar_p', arg =>$g->{filename});
  $g->{this} = GrammarPtr->new($g->{filename});
  unless($g->{write_extension}) {
    $g->{write_extension} = $g->update_signature . '.o';
  }
  if($g->{ident_from_filename}) {
    ($g->{grammar_ident} = $g->{filename}) =~ s/.*[\/_]//g;
    $g->{grammar_ident} =~ s/\..*//;
  }
  $g->update_options;
  return $g;
}

sub update_options {
  my $g = shift;
  Parser::D::Gammar::update_constantes($g, $g->{this});
  #$g->update_constantes($g->{this}); #dont try!
}

sub read_dir {
  my $g = shift || return undef;
  # open script files...in contrib...
  my $asn_dir = shift;
  unless(-d $asn_dir) {
    my $dir = '../' . $asn_dir;
    $asn_dir = $dir;
  }
  my @asn_f;
  opendir(DIR, $asn_dir) and do {
    @asn_f = grep(/\.asn|\.exp/i , readdir(DIR));
    close DIR;
  };
  my $i = 0;
  my $desc = '';
  foreach (@asn_f) {
    my $deli = $/;
    undef $/;
    open(FILE, "<" . $asn_dir . "/" . $_);
    $desc .= <FILE>;
    #{
    #  chomp;
    #s/\s+/ /g;
    #  $desc .= " -- " . $i++ . "\n" . $_ . "\n";
    #  $desc .= $_ . "\n";
    #}
    #$desc .= "\n";
    close FILE;
    $/ = $deli;
  }
  return $desc;
}

our $magic_header = '.d_parser SIGNATURE:';

=head3 update_signature

 from file or string create a signature...

=cut

sub update_signature {
  my $d = shift || return undef;
  my $s = shift || $d->{grammar};
  my $f = shift || $d->{filename};
  my $digest = '';
  # Parses Perl Grammar into DParse Gramma String.
  # saving function order...
  # is it an array of HASH mapping CODE
  #
  # get the gramma in one wallop
  #
  if(!$s && ((-f $f) || 0)) {
    # actually here this might not be nescessary in case the gramma has already been compiled.
    my $fh = new FileHandle($f, "r");
    if(defined $fh) {
      my $sign = $fh->getline;
      #
      # sign in c function table?
      # could also check in o tables....?
      my $f_o  = $f . '.c';
      if(-f $f_o) {
	my $fh = new FileHandle($f_o, "r");
	if(defined $fh) {
	  my $sign_o =  $fh->getline;
	  if($sign eq $sign_o) {
	    ($digest = $sign) =~ s/$magic_header//g;
	    next;
	  }
	}
      }
      if($sign !~ /$magic_header/) {
	$s .= $sign;
      } else {
	($digest = $sign) =~ s/$magic_header//g;
      }
      $s .= join("", $fh->getlines);
    }
  }
  # we have a string.
  # This would need to be parsed into a gramma
  # since the the dparser-internal grammar cannot yet itself build
  # perl scripts, actions would have to be parsed again.
  $d->{grammar} = $s;

  
  # signature management
  $d->{signature} = $digest || md5_hex((ref($s) eq 'SCALAR' ? $$s : $s));
  #
  # update name radix?
  #
  #$d->{filename} = $f;
  return $d->{signature};
}

sub sig_changed {
  my $g = shift;
  unless(defined $g->{signature}) {
    $g->update_signature(@_);
  }
  return((-M $g->{filename} . '.' . $g->{signature} . '.c' || 2e32)
	 > (-M $g->{filename} || 0));
}

sub parse_n_build {
  my $self = shift;
  my $s = shift || '';
  unless(ref($self) eq __PACKAGE__) {
    push @_, (grammar => $s);
    $self = __PACKAGE__->new(@_);
  } else {
     $self->{grammar} = $s;
  }
  $s = $self->make;
  return $s;
}

sub write_c {
  my $g = shift->{this} || return -1;
  my $i = $g->write_c_tables;
  return $i;
}

sub write_tables {
  my $g = shift->{this} || return -1;
  my $i = $g->write_binary_tables;
  return $i;
}

sub write_string {
  my $g = shift->{this} || return '';
  my $s = $g->write_binary_tables_to_string;
  return $s;
}

# will write to a C file...
sub write_file {
  my $g = shift || return 0;
  return 0 unless(defined $g->{this});
  my $fh = new FileHandle('>' . $g->{filename} . '.' . $g->{signature} . '.c');
  $fh->print($g->{this}->write_binary_tables_to_file($fh)) or
      warn __PACKAGE__ . "::write_file::" . caller() . "::failed";
  $fh->close;
}

=head3 make

 -internal grammar parsing and building

 -this function can only be called once (you have been warned).

INPUT:
  grammar object
  grammar script (or default 'grammar'  option)
  grammar filname script (or default 'filename')


=cut


sub make {
  my $g = shift;
  my $s = shift || $g->{grammar};
  my $f = shift || $g->{filename};
  if($g->sig_changed($s, $f) || $g->{make_grammar_file}) {
    my $g_p = $g->{this} || return $g;
    if((-f $f) && !$s)  {
      eval {$g_p->mkdparse($f)};
    } else {
      $g_p->mkdparse_from_string(ref($s) eq 'SCALAR' ? $$s : $s);
    }
  } else {# tables shall already be ok...
    undef $g->{this};
    unless(ref($s) eq 'SCALAR') {
      undef $g->{grammar}; # could be very big...
    }
  }
  return $g;
}


=head3 print_rdebug_grammar

 try this exceptional function to print to STDOUT
 the whole production/declaration tree of the gramma.

=cut

sub print_rdebug_grammar {
  my $g = shift || return;
  if(defined $g->{this}) {
    $g->{this}->print_rdebug_grammar($g->{filename});
  }
}



=head3 GrammarPtr::free_D_Grammar

this is a call to free the Tables allocated with the Grammar pointer.
It has been hooked to the Parser::D::Gammar::DESTROY.
Unfortunatly it frees also the links to perl objects, whithout
decreasing references counts.

=item TODO:

 one would have to do those perl-object dereference first before calling
GrammarPtr::free_D_Grammar...?!

It is also used in parse_grammar()


=head3 GrammarPtr::new_D_Grammar

Low level call to create instance and allocate 
memory for of a Grammar.


=head3 GrammarPtr::write_binary_tables_to_string



=head3 GrammarPtr::write_binary_tables_to_file


=head3 GrammarPtr::write_binary_tables


=head3 GrammarPtr::write_c_tables



=head3 GrammarPtr::mkdparse

call to parse_grammar/build_grammar
to build the grammar object in the firt argument.
It is possible to add a second argument containing
a file-path-name of the grammar.

=head3 GrammarPtr::mkdparse_from_string


calls to parse_grammar/build_grammar
on the opject pointed by the first argument.
The grammar which is going to be compiled shall be
hold in a string by the second argument.



=head3 Parser::D::Gammar::update_constantes

must needed function for passing all options of the Parser::D::Gammar perl object into the Grammar C object.
This call is expected to be done when perl options have been manipulated, like before calling GrammarPtr::mkdparse.

=cut



package GrammarPtr;
use Parser::D;
use Devel::Peek;
use File::Temp;

=head1 GrammarPtr


wrappers for package Parser::D::Grammar which helps binding perl and C.

methodes:

=head3 void g_register_fatal( SV *    fn)

	links with an exit callback named exit_callback().


=head3 void g_free_D_Grammar(g) Grammar* g


=head3 Grammar*g_new_D_Grammar(grammar_pathname) char* grammar_pathname

=head3 SV*g_write_binary_tables_to_string(g) Grammar* g


=cut

sub new {
  my $class = shift || __PACKAGE__;
  my $f = shift || "";
  my $t = GrammarPtr::new_D_Grammar($f);
  # it crashes!
  register_fatal(\&pcb1);
  bless $t, $class;
  return $t;
}

sub DESTROY {
  my $g = shift
    || warn __PACKAGE__ ."::DESTROY $g", Dump($g);
  $g->free_D_Grammar;
}

sub pcb1 {
    die __PACKAGE__ . "::pcb1 I'm dying...\n" ;
}

sub TODO {
my $tmp = new File::Temp( TEMPLATE => 'tempXXXXX',
			  DIR => 'mydir',
			  SUFFIX => '.dat');
}

1;

__END__
