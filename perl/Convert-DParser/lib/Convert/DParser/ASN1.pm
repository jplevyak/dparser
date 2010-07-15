#
# $Id$
#

=head1 NAME

 Convert::DParser::ASN1

=head1 ABSTRACT

an ineficient package interpreting ASN1 PER,BER encoding and decoding closely derived from 
its specification grammar and supported by the Tomota LR parser <Parser::D>.



=head1 SYNOPSIS



=head1 DESCRIPTION

its grammar is borrowed textually from the specifications and appended with minor changes 
which to resolve mainly a few ambiguous loops and hooks to our parser.

=head1 METHODS

=cut


package Convert::DParser::ASN1;
use strict;
use warnings;
use Carp qw(carp);
use Storable;
use File::Spec ();
use File::Path ();
use Digest::MD5 qw(md5_hex);
use GraphViz;

use Devel::Peek;
use Data::Dumper;

use Convert::ASN1 qw(:all);
BEGIN {
    Convert::ASN1->_internal_syms;
}

use base qw(Class::Container Convert::ASN1 Exporter);
use Params::Validate qw(:types);


require Convert::DParser::ASN1::Grammar;

use constant {
    opENCODE => opBCD + 1
	, opENUM => opBCD + 2
	, opSEQUENCEOF => opBCD + 3
	, opSETOF => opBCD + 4
	, opCHOICEOF => opBCD + 5
};

=pod 

UNIVERSAL 0 Reserved for use by the encoding rules
UNIVERSAL 1 Boolean type
UNIVERSAL 2 Integer type
UNIVERSAL 3 Bitstring type
UNIVERSAL 4 Octetstring type
UNIVERSAL 5 Null type
UNIVERSAL 6 Object identifier type
UNIVERSAL 7 Object descriptor type
UNIVERSAL 8 External type and Instance-of type
UNIVERSAL 9 Real type
UNIVERSAL 10 Enumerated type
UNIVERSAL 11 Embedded-pdv type
UNIVERSAL 12 UTF8String type
UNIVERSAL 13 Relative object identifier type
UNIVERSAL 14-15 Reserved for future editions of this Recommendation | International Standard
UNIVERSAL 16 Sequence and Sequence-of types
UNIVERSAL 17 Set and Set-of types
UNIVERSAL 18-22, 25-30 Character string types
UNIVERSAL 23-24 Time types
UNIVERSAL 31-... Reserved for addenda to this Recommendation | International Standard

Table 4  Characters in xmlasn1typename
ASN.1 type production name Characters in xmlasn1typename
BitStringType BIT_STRING
BooleanType BOOLEAN
ChoiceType CHOICE
EmbeddedPDVType SEQUENCE
EnumeratedType ENUMERATED
ExternalType SEQUENCE
InstanceOfType SEQUENCE
IntegerType INTEGER
NullType NULL
ObjectClassFieldType See ITU-T Rec. X.681 | ISO/IEC 8824-2, 14.10 and 14.11
ObjectIdentifierType OBJECT_IDENTIFIER
OctetStringType OCTET_STRING
RealType REAL
RelativeOIDType RELATIVE_OID
RestrictedCharacterStringType The type name (e.g. IA5String)
SequenceType SEQUENCE
SequenceOfType SEQUENCE_OF
SetType SET
SetOfType SET_OF
TaggedType See 11.25.5
UnrestrictedCharacterStringType SEQUENCE

=cut


# Given a class and a tag, calculate an integer which when encoded
# will become the tag. This means that the class bits are always
# in the bottom byte, so are the tag bits if tag < 30. Otherwise
# the tag is in the upper 3 bytes. The upper bytes are encoded
# with bit8 representing that there is another byte. 
our %ber_encoding_class_tag
  = (
     UNIVERSAL     =>   0b00 << 6
     , APPLICATION =>   0b01 << 6
     , CONTEXT     =>   0b10 << 6
     , PRIVATE     =>   0b11 << 6
    );

our %ber_encoding_type_tag
  = (#UNIVERSAL class TAG assignment
     BOOLEAN             => 1
     , INTEGER           => 2
     , BITSTRING         => 3
     , OCTETSTRING       => 4
     , NULL              => 5
     , OBJECTIDENTIFIER  => 6
     , ObjectDescriptor  => 7
     , REAL              => 9

     , ENUMERATED        => 10

     , CHOICE            => undef

     , 'RELATIVE-OID'    => 13

     , SEQUENCE          => 16
     , SEQUENCEOF        => 16
     , SET               => 17
     , SETOF             => 17

     , UTF8String        => 12
     , NumericString     => 18
     , PrintableString   => 18
     , TeletexString     => 20
     , T61String         => 20
     , VideotexString    => 21
     , IA5String         => 22
     , UTCTime           => 23
     , GeneralizedTime   => 24
     , GraphicString     => 25
     , VisibleString     => 26
     , ISO646String      => 26
     , GeneralString     => 27
     , CharacterString   => 28
     , UniversalString   => 28
     , BMPString         => 30
     , BCDString         => 4
    );

#BuiltinTypes
our %per_item_bit_size
  = (BOOLEAN             => 1
     , INTEGER           => 8
     , BITSTRING         => 1
     , OCTETSTRING       => 8
     , NULL              => 0
     , OBJECTIDENTIFIER  => 32
     , ObjectDescriptor  => 32
     , REAL              => 32
     #, ENUMERATED/CHOICE        => bit size calculated with the number of elements
     , 'RELATIVE-OID'    => 32
     , SEQUENCE          => -1
     , SEQUENCEOF        => -1
     , SET               => -1
     , SETOF             => -1
     , UTF8String        => 8
     , NumericString     => 3
     , PrintableString   => 7
     , TeletexString     => 7
     , T61String         => 8
     , VideotexString    => 8
     , IA5String         => 7
     , UTCTime           => 8
     , GeneralizedTime   => 8
     , GraphicString     => 8
     , VisibleString     => 7
     , ISO646String      => 8
     , GeneralString     => 8
     , CharacterString   => 8
     , UniversalString   => 8
     , BMPString         => 3
     , BCDString         => 3
    );


__PACKAGE__->valid_params
  (
   filename => {default => ".d_parser", optional => 1}
   , grammar => {default => \$Convert::DParser::ASN1::grammar}
   , start_token => {default => 'top'}
   , description => {default => ""}
   , parser => {isa => 'Parser', optional => 1 }
   , initial_skip_space_fn => {default => *white_space_fn}
  );

__PACKAGE__->contained_objects
  (
   parser => {class => 'Parser::D', delayed => 1}
   , encoder => {class => 'Convert::DParser::ASN1::Encode', delayed => 1}
   , decoder => {class => 'Convert::DParser::ASN1::Decode', delayed => 1}
  );

our(@EXPORT, @EXPORT_OK);
our %EXPORT_TAGS
    = (
       'all' => [ qw(
		     grammar explicit
		    )
		]
       , encode => [
		    qw(
		       i2osp asn_encode_length num_length
		       opOBJID opGTIME opENCODE
		      )
		   ]
       , decode => [
		    qw(
		       os2ip
		       opANY opCHOICE opOBJID opBITSTR opSTRING opUTF8
		       ASN_CONSTRUCTOR
		      )
		   ]
      );
@EXPORT_OK = map {@$_} values %EXPORT_TAGS;

=head2 new

    simple instenciator.

accet parameters:

   filename => {default => ".d_parser", optional => 1}
   , grammar => {default => \$Convert::DParser::ASN1::grammar}
   , start_token => {default => 'top'}
   , description => {default => ""}
   , parser => {isa => 'Parser', optional => 1 }
   , initial_skip_space_fn => {default => *white_space_fn}


=cut

sub new {
  my $c = shift || __PACKAGE__;
  my $t = $c->SUPER::new(@_);
  return $t->prepare;
}

sub save_state {
  my ($self, $path) = @_;
  map(delete($self->{$_}) , qw(grammar parser description));
  if(-e $path) {
    #File::Path::rmtree($path) or die "Couldn't overwrite $path: $!";
  }
  #mkdir($path, 0777) or die "Can't create $path: $!";
  Storable::nstore($self->{script}, $path);
  #File::Spec->catfile($path, 'self'));
}

sub restore_state {
  my ($self, $path) = @_;
  return undef unless(-e $path);
  # also check for time stamps...
  return $self->{script} = Storable::retrieve($path);
  #File::Spec->catfile($path, 'self'));
  $self->{tree} = $self->pack_struct($self->{script});
}

=head2 prepare

=head3 DESCRIPTION

done just after initialisation of this __PACKAGE__ object.
the ASN1 description (stored in "description" field) script is compiled by default.

passing a string argument, a scalar to a string (prefered!), or a FILE object,
will override the compile of the default ASN1 description.

because this compilation can be long,
a storage/retrieving system has been inserted.

the function will attempt to restore already compiled parsing tables using
an derived MD5 content key to identify the stored structure.
Also at the end of a compilation the tree hash is saved.

  $object->save_state($path);
  ... time passes ...
  $object = Class->restore_state($path);



after grammar compilation, the produced tree is
verified (first distribution)
and then compiled (first factorisation),
packed and stored.


=head3 SYNOPSIS

my $other_grammar =<<'ESD'
ModuleDefinition:ModuleIdentifier
"DEFINITIONS" 
TagDefault ExtensionDefault "::="
"BEGIN"
ModuleBody
"END";
ModuleIdentifier:word;
TagDefault:word;
ExtensionDefault:word;
ModuleBody:word;
word                  ::= "[a-z][a-z0-9_\-]*";
ESD
;

my $asn = __PACKAGE__->new->prepare(\$other_grammar);

=cut


sub prepare {
  my $t = shift || return;
  my $asn = shift || $t->{description} || return $t;
  my $txt = (ref($asn) eq 'SCALAR' ? $asn : \$asn);
  if(ref($asn) eq 'GLOB') {
    local $/ = undef;
    $txt = \${<$asn>}; #TODO tobe checked 070920
  }
  if($txt) {
      my($r, $err);
      my $s = md5_hex($$txt);
      my $path = 'asn_' . $s . '.i';
      unless($s = $t->restore_state($path)) {
	  $t->{parser} = $t->create_delayed_object
	      ('parser'
	       , map(($_ => $t->{$_}), qw(grammar start_token))
	       , @_
	      );
	  ($r, $err) = $t->{parser}->run($txt);
	  if($@ || (ref($r) ne 'D_ParseNodePtr')) {
	      carp "failed second stage compilation of grammar " . $s
		  . sprintf('%30s ... ', $txt);
	      return $t;
	  }
	  my $tree = $t->{htree} = $r->user;
	  _make_graph($tree, 'parsed.' . $$);
	  #CPM070924
	  #TODO: comments are not yet linked to there modules etc...
	  $t->{comments} = $t->{parser}->{comments};
	  $err = $t->verify($tree);
	  _make_graph($tree, 'verife.' . $$);
	  carp(caller(), $err, Dumper($tree)) if($err);
	  $err = $t->compile($tree);
	  _make_graph($tree, 'compil.' . $$);
	  carp(caller(), $err, Dumper($tree)) if($err);
	  unless ($tree) {
	      $t->{error} = $@;
	      return $t;
	  }
	  $t->{script} = $tree;
	  $t->{tree} = $t->pack_struct($tree);
	  $t->save_state($path);
      }
  }
  return $t;
}


=head2 pack_struct

nothing

=cut

sub pack_struct {
  my $s = shift;
  my $t = shift;
  # here convert op HASHs to ARRAYS :
  # my $yoyo = qw(cTAG cTYPE cVAR cLOOP cOPT cCHILD cDEFINE);
  return $t;
}




=head2 expand_ops

this is to expand the "COMPONENT OF" TYPE
it directly inserts into the CHILD array any individual sub-types.

=cut

sub expand_ops {
  my $op = shift;
  my $tree = shift;
  my $seen = shift || { };
  my $want = $op->name;
  my $nm = $op->op_explicit($tree, $want);
  die __PACKAGE__ . "::ERROR::COMPONENTS OF loop $want\n" if($seen->{$want}++);
  die __PACKAGE__ . "::ERROR::Undefined macro $want\n" unless($nm);
  #
  #CPM0608
  # not goodygoody , why not using the global structure...
  my $ops = shift || $op->{CHILD} || [];
  # reconsiders
  warn __PACKAGE__ . "::ERROR::Bad macro for COMPONENTS OF '$want'\n"
    unless(@$ops == 1
	   && ($ops->[0]{TYPE} eq 'SEQUENCE' || $ops->[0]{TYPE} eq 'SET')
	   && ref($ops->[0]{CHILD})
	  );
  # !?!
  $ops = $ops->[0]{CHILD};

  for(my $idx = 0 ; $idx < @$ops ; ) {
    my $op = $ops->[$idx++];
    if ($op->{TYPE} eq 'COMPONENTS') {
      splice(@$ops, --$idx, 1, $op->expand_ops($tree, $seen));
    }
  }
  @$ops;
}


=head2 verify

=head3 DESCRIPTION

tree is expected with this format:

(c.f. <>compile_one<>)


ARRAY[ : root module
...
   , HASH{
     ... 
	, VAR	=> reference value : string | OP | HASH
        , CHILD => assigned  value : string | number | OP | HASH | ARRAY of these
        , TYPE	=> attribute type  : string
        , OPT	=> options   : tags?
	, OPE   => operator value : string
	, '.'	=> my stash
        , '..'  => parent stash
	, '...' => root stash
   }
, ...
]

%stash is an histogram of variables.

TYPE = COMPONENTS are going to be expanded using CHILD

CHILD could also be some imports...


this is an exit tree example :

0  HASH(0x16ce8a84)
   'Constant-definitions' => ARRAY(0x16ce8cd0)
      0  Convert::DParser::ASN1=HASH(0x16ce8ca0)
         'hiPDSCHidentities' => ARRAY(0x16ce8538)
            0  HASH(0x16ce84cc)
               'CHILD' => 64
               'TYPE' => 'INTEGER'
               'VAR' => 'hiPDSCHidentities'
   'TYPE' => 'AUTOMATIC'
   'VAR' => HASH(0x16ce4a6c)
      'CHILD' => HASH(0x16cd2f40)
           empty hash
      'VAR' => 'Constant-definitions'


=item TODO

in a more general way,
the parser's rules will categorise information and each node creates group of elements.
a class can be associated to those elements and methodes.

EBNF,

A_node0 : conditions(A_node1, A_node2, ... )

C++,
A::{a1,a2,a3,...} associated maps (A::(alpha1,alpha2,...)()).

the bottoms rules end with pattern matchers.
these are combination of dirac functions after all.
from ordered |N**32 to {0,1}.

the associated maps on each node shall creates an outcome program
which reflect , or, let say, the specifications !



=cut

sub verify {
  my $s = shift;
  my $tree = shift || $s->{CHILD};
  #$tree = [ $tree ] unless(ref($tree) eq 'ARRAY');
  $s->{CHILD} = $tree;
  $tree = $s->verify_array;
  while(my $v = shift @{$s->{TODO}}) {
    # make an exit mechanisme... this could loop forever!
    $tree .= $s->verify_array([ $v ], $v->{'...'}{STASH});
  }
  return $tree;
}

=head2 verify_array

this function cross check the consistency of a branch of parsed
script.

given a node, also a blessed __PACKAGE__,
optionaly an array of sub nodes, usually refered by the key CHILD
and a dictionary refered by  a STASH of references,
it will descend to the next sub nodes
and compare duplicate information, incompletes information,
propagate the STASHes.

this method is a defactorisation/expension/completion tool done after
(or may be during) the first parsing...

an intermediary hash is saved keyed by TODO in order to allow more
processes and passes.

at the end of it every known elements shall have links to there referer,
and references, like this,
I found  the compilation process is clearer to implement.

-auto TAG implementating
-package blessing of HASH nodes 
-distinctions criteria beetween nodes types 
-check parenting and node types.


...
'VAR' => 'M-b',
      'CHILD' => {
        'VAR' => 1,
        'CHILD' => 'pci'
      }
...
is an OID mapping...
this too
{
        'VAR' => 'ftam',
        'CHILD' => [
          'iso',
          'standard',
          8571
        ],
        'TYPE' => 'OBJECTIDENTIFIER'
}

an VAR-type is also an equation definition...

'VAR' is a 'TYPE' of (CHILD)

=TODO

make it part of our lovely first parser...!


=cut

sub verify_array {
  my $s = shift;
  $s->{TODO} = [] unless(defined($s->{TODO}));
  my $ops = shift || $s->{CHILD} || [];
  # call back to {STASH} (are also imports)
  my $stash = shift || $s->{STASH} || ($s->{STASH} = {});
  my $err = '';
  my $idx = 0;
  # case {CHILD} => HASH into {CHILD} => [HASH]
  if(ref($ops) eq 'HASH') {
    $ops = [ $ops ];
  }
  # {CHILD} => [..., op[i] ,...]
  #loops in childrens of given node $s
  while(my $op = $ops->[$idx]) {#each HASH children nodes has to be an ASN1 object...
    if((ref($op) eq 'HASH') and %$op) {
      #case {CHILD} => [...,HASH{...},...] into {CHILD} => [...,__PACKAGE__,...]
      bless $op;
    } else {# {CHILD} => [...,__PACKAGE__|[...]|{} ,...]
      #TODO: this is the part that need to be minimised
      if((ref($op) eq __PACKAGE__) && defined($op->{TODO})) {
	# {CHILD} => [...,__PACKAGE__{TODO},...]
	next;
      }
    }
    unless(ref($op) eq __PACKAGE__) {# not {CHILD} => [...,__PACKAGE__,...]
      # child node could be an array of strings for type enumerated
      # named number, identifier
      if(ref($op) eq 'HASH') {# {CHILD} => [...,HASH{},...] into {CHILD} => [...,...]
	#TODO: .. shall have been filtered out up front...ie. node ModuleIdentifier:
	splice(@$ops, $idx--, 1);
      } else {# we have a pure SCALAR value here...(string or number)
	#
	# leave this atome alone...
	#
      } #s->{'...'}{STASH}{'..'}{$s->{VAR}}{STASH}{$op}
      next;
    }
    #now  {CHILD} => [...,__PACKAGE__,...]
    # {CHILD} => [...,__PACKAGE__{TODO},...] linkto {TODO}
    #done...this node... pass down TODO
    $op->{TODO} = $s->{TODO} unless(defined($op->{TODO}));
    # verify VAR, operator name. Can be inherant.
    my $var = $op->name;
    if(defined($var)) {#{CHILD} => [...,__PACKAGE__{VAR}=>var,...]
      if(defined($stash->{$var})) {#{STASH}=>{var}=>...
	if($stash->{$var} eq $op) {#{CHILD} => [...,__PACKAGE__,...] is {STASH}=>{var}=>...
	  next;
	} else {# stash error....
	  my $e = "::stash error::two nodes for same reference {VAR} $var, something quite wrong...";
	  carp caller() . $e;
	  $err .= $e;
	  push(@{$op->{TODO}}, $stash->{$var});
	  push(@{$stash->{$var}{TODO}}, $op);
	  #TODO:CPM071005 it could be an OID arc put on stash by mistake
	  # would need to check with types. is_oid($stash->{$var})
	  # no no no OID stash shall stuck at same level.
	}
      } else {# stash it... 
	#TODO:CPM071005 however this is wrong when $op->{TYPE} is FROM...
	$stash->{$var} = $op;
      }
      if(ref($op->{VAR}) eq __PACKAGE__) {#{CHILD} => [...,{VAR}=>__PACKAGE__,...]
	my $v = $op->{VAR};
	if(exists($v->{CHILD})) {#{CHILD}=>[...,{VAR}=>__PACKAGE__{CHILD}=>,...]
	  #OID reference, definite OID
	  # {..,VAR=>{CHILD=> [ path declaration, ], VAR=>'name'},..}
	  # get to know OID link, another way to refere to VAR,  isn't it?
	  # put type 'OBJECTIDENTIFIER'
	  # this could be redundant if we assume in the later
	  # (VAR + CHILD) only implies TYPE = OID)
	  # sub process here in OID with root stash.
	  $err .= $v->verify_oid($v->{CHILD}, $stash);
	}
      }
    }
    # PARENTING setup
    # according to TYPE
    my $tp = $op->{TYPE} || '';
    if($tp && $tp !~ /RANGE|SIZE/) {
      # setup the parenting
      # we could restrict this only for composed TAGs...
      if(!defined($op->{'...'}) && defined($stash->{'.'})) {
	$op->{'...'} = $stash->{'.'};
      }
    }
    #
    # TYPE and CHILD ARRAY combinations,
    #
    my $e;
    if(defined($e = $op->{CHILD})) {
      if(ref($e) eq 'HASH') {# ARRAY is sometimes a string (ie. enumeration)
	#TODO:here shall have been done in first pass.
	$e = [ $e ];
      }
      if($tp eq 'COMPONENTSOF') {# $op->{type} a string?
	# here expend...
	splice(@$ops, --$idx, 1, $op->expand_ops($s));
	next;
      } elsif($tp eq 'DEFINITIONS') {
	# lovely backward link to the root STASH
	unless(defined($op->{STASH}{'..'})) {
	  $op->{STASH}{'..'} = $stash;
	}
	unless(defined($op->{STASH}{'.'})) {
	  $op->{STASH}{'.'} = $op;
	  # this special path, allows to
	  # seek parents for constructed (instead of primitive) types
	  # like sequence or set
	}
	#get in DEFINITIONS 
	$err .= $op->verify_array;
      } elsif($tp eq 'IMPORTS') {
	# then migrates to s->OPT and has to be  stashed anyway
	# $s is the definitions, $op is the import, and child all the importee!	
	# move op into OPT..., and hopefully would be dealt there
	# since not yet done in the master OP.
	# do imports now or wait to hit OPT loop?
	$err .= $s->verify_array($e);
	push @{$s->{OPT}}, @$e;
	#splice(@$ops, $idx--, 1);
	delete($ops->[$idx--]);

      } elsif($tp eq 'FROM') {
	my $v = $stash->{'..'}{$var} || undef;
	my $s_b = $s;
	if(defined $v) {
	  my $i = 0;
	  foreach my $t (@$e) {
	    my $vv = $v->{STASH}{$t} || $stash->{$t} || undef;
	    my $s_b = $s;
	    while(!defined($vv) && defined($s_b)) {
	      $err .= $s_b->verify_array;
	    } continue {
	      $s_b = $s_b->{'...'}{STASH}{'..'} || undef;
	      $vv = $v->{STASH}{$t} || $stash->{$t} || undef;
	    }
	    if(defined $vv) {
	      $e->[$i] = $stash->{$t} = $vv;
	    } else {
	      $err .= __PACKAGE__ . '::verify_array zut alors not '. $t . " yet processed\n";
	      warn $err;
	      undef($op->{TODO});
	      push @{$s->{TODO}}, $op;
	    }
	    $i++;
	  };
	} else {
	  undef($stash->{$var});
	  undef($op->{TODO});
	  # found a way to cope... fortunately shall not happen the second run...
	  $err .= __PACKAGE__ . '::verify_array FROM '. $var .' not processed\n';
	  push @{$s->{TODO}}, $op;
	}
      } elsif($tp =~ /(SET|SEQUENCE)OF/) {
	# CHILD  is a loop
	# here it would be an array or an element
	# referencing to a variable..
	# LOOP shall be only one element I heard... still to check?
	# take the last anyway
	unless(ref(my $v = (ref($e) eq 'ARRAY') ? $e->[-1] : $e)) {
	  # here we have a string,
	  # check the stash?
	  my $s_b = $s;
	  my $s_s = $stash->{$v} || undef;
	  while(!defined($s_s) && defined($s_b)) {
	    # leave it as is check again at compile time...
	    $err .=  __PACKAGE__ . "::verify_array  LOOP fork on "
	      . $v . ", next pass for " . $var . "\n";
	    # carry on dud, open a new root... fork?! do something
	    $err .= $s_b->verify_array;
	  } continue {
	    $s_b = $s_b->{'...'} || undef;
	    $s_s = $stash->{$v}  || undef;
	  }
	  if(defined $s_s) {# and replace...
	    $op->{CHILD} = [ $s_s ];
	    # no need to do more since the loop type has been (re)defined
	  } else {
	    $err .= __PACKAGE__ . "::verify_array LOOP bommer, saperlipopette and double array reference failed verifying " . $e . ".\n";
	    warn $err;
	    undef($op->{TODO});
	    push @{$s->{TODO}}, $op;
	  }
	}
      } elsif($tp =~ /OBJECTIDENTIFIER/) {
	#CPM070925 register OID in module declaration ...	
	$err .= $op->verify_oid($e, $stash);
	
      } elsif($tp =~ /RELATIVE-OID/) {
	$err .= $op->verify_roid($e, $stash);
	
      } elsif($tp =~ /CLASS/) {
	# link back...to build the path.
	$op->{'..'} = $s;
	$err .= $op->verify_array($e, $stash);

      } elsif(ref($e) eq 'ARRAY') {#typeless sub scan
	$err .= $op->verify_array($e, $stash);
      }
    }
    #
    # verify Attributes in OPT
    if(defined($e = $op->{OPT})) {
      # here it would be an array or an element
      # referencing to a variable..
      if(ref($e) eq 'ARRAY') {
	# get in...
	$err .= $s->verify_array($e, $stash);
      }
    }
  } continue {#?!
    $idx++;
  }
  return $err;
}


=heads3 verify_oid

=pod OID layout

the OID has to be verified here since one needs type, var to discriminate.
we layer down and process CHILDs and so one but most likely find raw strings 
(name references) or HASH (referenced name) in this sub layer, so
hardly unprocessable.

this is why a kind of compile is done at back on these children.
may be it is the role of the compiler?
-:verifyer check in front
-:compiler check in back



here is an example of HASH for OID comming after scripting verify_one:

{
      'ftam' => bless( {$op->{VAR}
        'TODO' => $VAR1->[0]{'TODO'},
        'VAR' => 'ftam',

#child shall be the link to next...OID bits...
# $VAR1->[0]{'STASH'}

        'CHILD' => [
          'iso',
          'standard',
          8571
        ],

        'TYPE' => 'OBJECTIDENTIFIER',
        '...' => $VAR1->[0]

}

"..." 


in root, a special STASH is created with all the reference name of OIDs arcs.
tree=> {
...
    'OID' => {... CHILD => [
{
VAR   => 'node ref name' not redundant since it creates a back link to HASH....
CHILD => [ oid node, oid node, oid node...]
TAG   => {CHILD => number identity}
OPE   => bit coding number
TYPE  => 'CHOICE'
.     => here
..    => previous OID node
...   => root stash
}
,...}
]
...
}

}

=cut


sub verify_oid {
  my ($op, $e, $stash) = @_;
  unless(defined($e)) {
    $e = $op->{CHILD};
  }
  if(ref($e) eq 'ARRAY'
     && $#$e == 1
     && ref($$e[0]) eq 'ARRAY'
    ) {#TODO:CPM071008 we would need trying to stop constructions =>[ [] ]
    # this is looping again...?
    #symbol[312]=InstanceOfValue<-[46]	child#1[46]=Value
    #symbol[48]=BuiltinValue<-[312]	child#1[312]=InstanceOfValue
    #symbol[46]=Value<-[48]	child#1[48]=BuiltinValue
    #into...:
    #symbol[37]=ValueAssignment<-[46]	child#4[369]=valuereference
    carp(caller() . "::bad constructions =>[ [] ]:: $e = $$e[0]");
  }
  #prepare OID , stash has to be  the root stash  of all...
  my $err = '';
  # = $op->verify_array($e, $r_s);
  # not really a good idea! from a nice OID list of strings
  # get an awfull linked list!?
  # OID arcs stash is not the same as modules stash..
  # particularely when one of OID VAR ref is also type ref.
  # each OID arc has its own local stash.
  my ($prev, $r_s) = _install_default_oid($stash);
  # is  default?
  # tag put in {OPT}[TYPE=>default, CHILD=>[an oid description]]
  if((my $c = $op->is_default)
     || ($op->type_explicit eq 'OBJECTIDENTIFIER')) {
    if(exists($stash->{ROID})) {
      if($stash->{ROID}{CHILD}[-1]{OPT} == 22) {
	$stash->{ROID} = $op;
      }
    } else {
      $stash->{ROID} = $op;
    }
  }
  # position from root..
  #my $i = 0;
  foreach my $n (@$e) {
    if(ref($n) eq 'HASH') {
      bless $n;
    }
    my $nn = $n;
    my @oids = _find_flat_oid($prev, $n);# check the stash...
    if($n =~ /^\d+$/) {# number only ... could put this front.
      # is there an associated element
      # is there a number inside the previous?
      foreach my $c (@oids) {# found $n in OIDS
	my $var = $c->name;
	if(($var eq $n) || $c->is_number_form_oid($n)) {
	  # it exists in node, lets replace, shall merge in case???
	  $n = $c->merge_oid($n);
	}
	unless($c eq $n) {
	  # here found similare OID...but not mergeable??
	  # be clever what the back compile needs to link... TAGs reordering...
	  push(@{$r_s->{TODO}}, $c);
	}
      }
      if(ref($n) eq __PACKAGE__) {# seen it before;  a number like a string? is linked and merged
	if(@oids) {#found a ref number (TODO:CPM071001 or more?????)
	  #it is redundant but shall never happen because stash{$n} already exists
	  #merge children...
	  $n = $oids[-1]->merge_oid($n);
	  #TODO::CPM071001
	  # linked objects to this???? oops how to mend this?
	}
      } else {# did not found assosiation, create one,
	# and unfortunatly with a number for VAR
	$n = $op->new_oid(bless({}), $r_s, $n, $prev);
      }
    } elsif(ref($n) eq __PACKAGE__) {
      if(@oids) {# name already registered???
	$n = $oids[-1]->merge_oid($n);
      } elsif(($prev eq $prev->{'...'}{OID})
	      && exists($n->{TYPE})
	      && ($n->{TYPE} =~ /RELATIVE-OID|OBJECTIDENTIFIER/)
	     ) {# this is a link to an ROID, OID
	# we also assume that the link has been already verified
	$n = $n->{CHILD}[-1];
	#$prev = $n->{'..'};
      } else {
	# like {VAR => 'pci', OPT => [1]}
	$nn = $n->name;
	#TODO::CPM071001 shall not be nescessary... just check unlinked info.
	$n = $op->new_oid($n, $r_s, $nn, $prev);
      }
    } elsif(!ref($n)) {#strings only
      if(@oids) {
	# is this already registered, ie.  string is a name reference of type OID
	$n = $oids[-1];
      } elsif(# only the first OID element can be an absolute OID ref. I guess.
	      ($prev eq $prev->{'...'}{OID})
	      && exists($stash->{"$n"})
	      && (ref($stash->{"$n"}{CHILD}) eq 'ARRAY')
	     ) {# map to last ref...
	$n = $stash->{"$n"}{CHILD}[-1];
      } else {# new OID value ref
	#$stash->{"$n"}{CHILD} might not be an ARRAY but a string...
	# because not processed yet... or oid name and reference type are sharing.
	#push(@{$stash->{TODO}}, $stash->{"$n"});
	$n = $op->new_oid(bless({}), $r_s, $n, $prev);
      }
    } else {
      $err .= "\ncant find OID sorts...not registering";
    }
    $prev = $n;
    #$i++; # TODO:CPM071024 obsolete.. do not use.
  }
  #keep last
  @$e = ( $prev );
  return $err;
}

=head2 is_oid_arc

answer the question, check if the operator is an OID arc
(or an OID reference type?)

=cut

*is_oid = \&is_oid_arc;

sub is_oid_arc {
  # find back wards '..' type choices, up to var = root.
  my ($op) = @_;
  if(exists($op->{'..'})) {
    return is_oid($op->{'..'});
  }
  if($op->{TYPE} eq 'CHOICE'
     && exists($op->{'...'})
     && exists($op->{'...'}{OID})
     && $op->{'...'}{OID} eq $op) {
    return 1;
  } else {
    return 0;
  }
}

=heads3 merge_oid type reference

s is the source, m the merger.

in checking VAR, merge r to b at end.

s (and b) are the dominant source

=cut

sub merge_oid {
  my $s = shift || return undef;
  my $m = shift || return $s;
  #
  # merge CHILD
  if($m eq $s) {
    return $s;
  }
  unless(ref($m)) {
    if($m =~ /^\d+$/) {
      unless($s->is_number_form_oid($m)) {
	push(@{$s->{OPT}}, $m);
      }
    } else {
      if(exists($s->{VAR})
	 && ($s->{VAR} =~ /^\d+$/)
	 || (!exists($s->{VAR}))
	) {
	$s->{VAR} = $m;
      }
    }
    return $s;
  }
  my $a = $m->{CHILD} || undef;
  my $b = $s->{CHILD};
  if(defined($a)) {
    if(defined($b)
       && ref($a) eq 'ARRAY') {
      #TODO:CPM071003
      # with a for j for i cond loop (ie. it is a sort)
      # since it is orderer... a sort could be even better!
      foreach my $c (@$a) {
	unless
	  (grep
	   (
	    ((ref($c) eq __PACKAGE__) ? $c->{VAR} : $c)
	    eq
	    ((ref($_) eq __PACKAGE__) ? $_->{VAR} : $_)
	    , @$b
	   )
	  ) {
	    push(@$b, $c);
	  }
      };
    } elsif($a =~ /^\d+$/) {# this is a number tag
      # move number form to {OPT}
      $m->{OPT} = $a;
    }
  }
  # m{OPT} or s{OPT} can be \d, [\d], [\d, {} ], etc...
  # need to compare alike.
  #
  $b = undef;
  if(exists($s->{OPT})) {# check OPT definite number name form.
    $b = $s->{OPT};
    if(ref($b) eq 'ARRAY') {
      ($b) = grep(/^\d+$/, @{$b});
    }
  }
  unless($b) {
    $a = undef;
    if(exists($m->{OPT})) {
      $a = $m->{OPT};
      if(ref($a) eq 'ARRAY') {
	($a) = grep(/^\d+$/, @{$a});
      }
    }
    if(defined($a)) {
      unshift(@{$s->{OPT}}, $a);
    }
  }
  # is source name {VAR} a number?
  if(($s->name =~ /^\d+$/)
     && exists($m->{VAR})
    ) {#if s-name is a number but not m-name
    $s->{VAR} = $m->{VAR};
  }
  return $s;
}

=head2 new_oid

this is verifying and constructing one chain of
the OID tree definition, not to mistake with
a declaration of definitive type OBJECTIDENTIFIER.
this is why I stuff the OID nodes into a 'CHOICE' set, but watch out,
it all start from 'root'...

=cut

sub new_oid {
  my $op = shift; #TODO:CPM071015 only $op->{CHILD} is needed really.
  my ($oid, $root, $n, $prev) = @_;
  my @oid = (defined($prev) ? _find_flat_oid($prev, $n) : ());
  unless(@oid) {
    $oid->{'...'}	= $root;
    $oid->{'..'}	= $prev;
    $oid->{'.'}		= $oid;
    $oid->{TYPE}	= 'CHOICE';
    $oid->{VAR}		= $n;
    if($n =~ /^\d+$/) {
      $oid->{OPT}	= $n;
      # here we have to investigate this OID VAR,
      # but also any back references to it...
      push(@{$root->{TODO}}, $oid);
    };
    #TODO:CPM071003 this could be passed in the parser...
    if(defined($oid->{CHILD})) {
      if($oid->{CHILD} =~ /^\d+$/) {
	push(@{$oid->{OPT}}, $oid->{CHILD});
	delete($oid->{CHILD});
      } else {# child is not a pure number... something not quite right
	#TODO:CPM071011 this hardly can't be delt anywhere else than here.
	# { a b } is translated into by ... (only for case of 2 elements by the way!)
	#ObjectIdentifierValue {CHILD} => [HASH{VAR=>a, CHILD} , HASH{VAR=>b, CHILD}]
	#CharacterStringValue  {CHILD} => [HASH{VAR=>a, CHILD=>b}]
	my $s = $oid->{CHILD};
	unless(ref($s)) {# it is a string... is this a ref? assume not.
	  # move this to an array
	  if($#{$op->{CHILD}} == 0) {# this has identified one of those uncertain casting.
	    # move string around.
	    push(@{$op->{CHILD}}, $s);
	    delete($oid->{CHILD});
	  } else {
	    carp caller() . "::bad OID construction:{CHILD}=>[HASH{VAR=>a,CHILD=> [ ... ]}]";
	  }
	} else {
	    carp caller() . "::bad OID construction:{CHILD}=>[HASH{VAR=>a,CHILD=> ..not a string.. }]";
	}
      }
    }
    if(defined($oid->{OPT})) {# check OPT definite number name form.
      if(ref($oid->{OPT}) eq 'ARRAY') {
	@{$oid->{OPT}} = grep(/^\d+$/, @{$oid->{OPT}});
      } else {# nothing todo I guess.
      }
      #ordering has to be done at later compile stage.
    }
    # here add the node at last.
    # CPM071011 previous  {CHILD} must be an array else we are not dealing
    # with an OID name (but rather a OID type ref)
    # it bombs out anyway.
    push(@{$prev->{CHILD}}, $oid);
    # would need some sorting...
  } else {# OID exists in node choice
    #TODO::CPM071001 merge info. compare consistancy of TAG numbers.
    $oid = $oid[-1];
  }
  return $oid;
}

=head2  _find_oid

since OID names in path reference are not name definitions, there shall ne be stashed.
we could I think have an OID like, { a b(0) } and like { b(2) }
(but not like { a b(0) } { a b(1) } !?!)

=cut

sub _find_oids {
  my ($root, $n) = @_;
  my @found = [];
  foreach $_ (@{$root->{CHILD}}) {
    push(@found, $_) if($_->{VAR} eq $n);
    push(@found, _find_oids($_, $n));
  };
  return @found;
}
#
#
#
sub _find_oid {
  my ($root, $n) = @_;
  my @found = ();
  foreach $_ (@{$root->{CHILD}}) {
    push(@found, $_) if($_->{VAR} eq $n);
    push(@found, _find_oid($_, $n));
    last if(@found);
  };
  return @found;
}
#
#DefinitiveNumberForm
#
sub is_number_form_oid {
  my ($oid, $n) = @_;
  if(ref($n) eq __PACKAGE__
     && exists($n->{CHILD})
    ) {
    return is_number_form_oid($oid, $n->{CHILD});
  }
  if(exists($oid->{OPT})) {
    if(ref($oid->{OPT}) eq 'ARRAY') {
      foreach (@{$oid->{OPT}}) {
	if($_ eq $n) {
	  return 1;
	}
	#TODO:CPM071025 destroy empty elements
      };
    } else {
      return($n eq $oid->{OPT});
    }
  }
  return 0;
}
#
sub _find_flat_oid {
  my ($root, $n) = @_;
  my @found = ();
  unless(ref($root)) {
    carp caller() . "::root is not an object:" . Dumper($root);
  } else {
    #TODO massive problem... root childs is not an HASH?
    #CPM071012 root child could be still a string when OID name and OID type ref collide
    return @found unless(ref($root->{CHILD}) eq 'ARRAY');
    foreach (@{$root->{CHILD}}) {
      next unless(ref($_));
      if((exists($_->{VAR})
	  && ($_->{VAR} eq $n))
	 or
	 is_number_form_oid($_, $n)
	 or
	 (# what if $n is a __PACKAGE__
	  (ref($n) eq __PACKAGE__)
	  && (
	      (exists($n->{VAR})
	       && exists($_->{VAR})
	       && ($_->{VAR} eq $n->{VAR})
	      )
	     )
	 )
	) {
	push(@found, $_);
      }
    };
  }
  return @found;
}


=head2 _install_default_oid


=head3 DESCRIPTION

key structure:
TREE[
...
{
OID 
=> {
	. => oid self
	.. => arc oid self
	CHILD => [ oid arc ]
	VAR   => name
	TYPE  => CHOICE
	TAG => {CHILD => number/order.}
   }
}
...
]

=head3 ARGUMENTS

=cut

sub _install_default_oid {
  my $stash = shift;
  my $r_s = $stash->{'...'} || $stash;
  if(exists($r_s->{'..'})) {
    $r_s = $r_s->{'..'};
  }
  my $prev = $r_s->{OID} || undef;
  unless(defined($prev)) {
    $prev = $r_s->{OID} = bless
      (
       {'.'	=> $r_s
	, '...'	=> $r_s
	, VAR	=> 'OID'
	, TYPE	=> 'CHOICE'
	#OID... it is a choice indeed but adds an extra TAG?!
	, OPT   => -1
       }
      );
  }
  unless(exists($stash->{ROID})) {#no default indexes for ROI.
    #E.2.19.1.a){iso(1) identified-organization(3) set(22)}
    my $roid
      = $stash->{ROID}
      = bless
	(
	 {TYPE => 'OBJECTIDENTIFIER'
	  , VAR => 'ROID'
	  , CHILD =>
	  [{VAR => 'iso', OPT => 1}
	   , {VAR => 'identified-organization', OPT =>  3}
	   , {VAR => 'set', OPT => 22}
	  ]
	  , OPT => {TYPE => 'DEFAULT'}
	 }
	);
    $roid->verify_oid(undef, $stash);
  }
  return ($prev, $r_s);
}


=head2 verify_roi

relative Object Identifier linker

=item DESCRIPTION

verfiy integrity of this type and links it to the right OID arc.

each modules in stash has a ROI pointer
this could be the last

=item ARGUMENTS

=cut

sub verify_roid {
  my ($op, $e, $stash) = @_;
  unless(defined($e)) {$e = $op->{CHILD};}
  #prepare OID , stash has to be  the root stash  of all...
  my ($prev, $r_s) = _install_default_oid($stash);
  #check for existing oid type references...
  if(exists($stash->{"$e->[0]"})) {
    $e->[0] = $stash->{"$e->[0]"};
    # verify_oid will link the rest.
  } else {
    #then when arc found and link done by prepanding  $stash->{ROID}...
    unshift(@$e, $stash->{ROID});
  }
  return $op->verify_oid($e, $stash);
}





=head2 compile_one

=head3 DESCRIPTION

compile a full tree of ASN1 entity rule on a branch.
The function will recurre into the tree and which is a vertex/branch.

=head3 ARGUMENTS

tree: an entry to a linked heap of operators.

operators: array reference of an objects containing [cTYPE, enCHILD, enLOOP, enVAR]

name: of the module/class
RETURNS: 
operators.
tree:
/----tree
{..
,
/----op
 /---------name
name => {
	... 
	, OPT   => [automatic optional default etc...]
	,       or key string for the operator...
	, TAG   => num
	, VAR   => (oftype) ... is it a bit like 'name' 
	, CHILD => { ... }   is it also a sub-tree ----- next tree
	, TYPE  => definitions integer string etc... itself?!
	, OPE   => internal indexe for operator code.
	, ...
	}
,

..}

but it is not ordered, so beware of sequences, sets...???


=cut

sub _range {
  my $r = shift;
  my $var  = shift;
  if($var < $r->[0]) {
    $var = $r->[0];
  } elsif($var > $r->[1]) {
    $var = $r->[1];
  }
  return $var;
}

=pod old _range use


      'OPT' => ARRAY(0x1a636d68)
         0  Convert::DParser::ASN1=HASH(0x1a62f7ac)
            'CHILD' => ARRAY(0x1a6179e8)
               0  Convert::DParser::ASN1=HASH(0x1a62edd4)
                  'CHILD' => ARRAY(0x1a62edbc)
                     0  1
                     1  8
                  'TYPE' => 'RANGE'
            'TYPE' => 'SIZE'


    if($tp eq 'SIZE') {
      my $r = $op_c->{CHILD} || next;
      if(ref($r->[0]) and $r->[0]{TYPE} eq 'RANGE') {
	#
	$r = $r->[0]{CHILD};
	$l =  _range($r, $l);
	$var = substr($var . "\0" x $l, 0, $l);	
      }
      unless(ref($r)) {
	if($r > 0) {
	  $l = $r;
	  $var = substr($var . "\0" x $l, 0, $l);	
	}
      }
    }
  };

=cut

=heads3 constrain

=item DESCRIPTION

this function caps variable associated wiht operators value (CHILD)
according to their  size, range, size and range, sets etc...

=item ARGUMENTS

requires a blessed operator,
a variable (number!) to compare and constrain,
returns the capped variable.

=item SYNOPSIS

my $t = bless(__PACKAGE__
	,{OPT => bless(__PACKAGE__
		,{TYPE => 'RANGE', CHILD => [-4, 10]})
	});
my $v = $t->constrain(44); #returns 10...

=item TODO

so far it works only on numbers?!

=cut

sub constrain {
  my $op = shift;
  my $var = shift || 0;
  # check for constraints...
  foreach my $op_c (@{$op->options_get}) {
    my $tp;
    next unless(ref($op_c));
    next unless(defined($tp = $op_c->{TYPE}));
    if($tp eq 'RANGE') {
      my $r = $op_c->{CHILD} || next;
      $var = _range($r, $var);
    }
    if($tp eq 'SIZE') {
      my $r = $op_c->{CHILD} || next;
      if(ref($r) eq 'ARRAY') {
	$r = $r->[0];
      }
      unless(ref $r) {
	# size only
	if($r > 0) {
	  $var = $r;
	}
      } else {
	# size + range
	$var = constrain($r, $var);
      }
    }
  };
  return $var;
}


=heads3 convert_range

=item DESCRIPTION

order an enumeration of constraints.
it determines the caracteristics of the set, like ist uper, lower limits, total number.
this sub compilation is required before encoding/decoding.

=item ARGUMENTS


=item SYNOPSIS


=cut

sub convert_range {
  my $op = shift;
  # get type of items
  my $ops = shift || $op->options_get || [];
  my $var = shift || 0;
  unless(ref($op) eq __PACKAGE__) {
    # this is a value scalar...string or number
    warn __PACKAGE__, "::convert_range::<", $op, "> has not been blessed";
    bless $op;
  }
  unless(ref($ops) eq 'ARRAY') {
    $ops = [ $ops ];
  }
  # check for constraints... SIZE or FROM...
  foreach my $op_c (@{$ops}) {
    my $tp;
    next unless(ref($op_c));
    next unless(defined($tp = $op_c->{TYPE}));
    if($tp eq 'RANGE') {
      # it has to be converted in sorted numbers
      my $r = $op_c->{CHILD} || last;
      my $i = 0;
      my $d = 0;
      while($i < $#$r) {
	#TODO CPM0610 cases r[i] <= r[i-1] ?! and single element list? r[i] == r[i+1]
	my($r0, $r1) = ($op->ord_ref($r->[$i]), $op->ord_ref($r->[$i + 1]));
	$d +=  $r1 - $r0 + 1;
	if($var < $d) {#gotcha
	  return(1 + $var + $r1 - $d);
	}
      } continue {
	$i += 2;
      }
      # this is wrong...get the upper bound
      $var = $op->ord_ref($r->[-1]) || $op->{TOTALSIZE} || 0;
      last;
    }
  }
  return $var;
}

=heads3 convert_size_range

=item DESCRIPTION

#order an enumeration of constraints.
#it determines the caracteristics of the set, like ist uper, lower limits, total number.
#this sub compilation is required before encoding/decoding.

=item ARGUMENTS


=item SYNOPSIS

my $op = {
      'VAR' => 'aname',
      'OPT' => [
        {
          'CHILD' => [
            {
              'CHILD' => [
                4,
                123456
              ],
              'TYPE' => 'RANGE'
            }
          ],
          'TYPE' => 'SIZE'
        }
      ],
      'CHILD' => 'INTEGER',
      'TYPE' => 'SEQUENCEOF'
    };

=cut

sub convert_size_range {
  my $op = shift;
  my $var = shift || 0;
  # check for constraints...
  return $var unless(defined($op->{TOTALSIZE}) && ($op->{LOG2SIZE} >= 0));
  # size only
  return $op->{TOTALSIZE} unless($op->{LOG2SIZE} > 0);

  # SIZE + RANGE
  # grep size and range...
  foreach my $op_c (@{$op->options_get}) {
    my $tp;
    next unless(ref($op_c));
    next unless(defined($tp = $op_c->{TYPE}));
    if($tp eq 'SIZE') {
      my $r = $op_c->{CHILD} || last;
      if(ref($r) eq 'ARRAY') {
	$r = $r->[0];
      }
      if(ref($r) && defined($op->{TOTALSIZE})) {# size + range
	return $op->convert_range($r, $var);
      }
      #wrong size on its own?!
      last;
    }
  }
  return $var;
}

=heads3 convert_range

=item DESCRIPTION

=item ARGUMENTS

=item SYNOPSIS

=cut

sub is_optional {
  my $op = shift;
  # only first level search
  foreach (@{$op->options_get}) {
    if(/OPTIONAL/) {
      return 1;
    }
  }
  return 0;
}

=heads3 convert_range

=item DESCRIPTION

=item ARGUMENTS


=item SYNOPSIS

=cut

sub is_default {
  my $op = shift;
  # only first level search
  foreach (@{$op->options_get}) {
    next unless(ref);
    next unless(defined($_->{TYPE}));
    if($_->{TYPE} eq 'DEFAULT') {
      return $_->{CHILD};
    }
  }
  return undef;
}


=heads3 compile_opt

=item DESCRIPTION

compile options key

=item ARGUMENTS


=item SYNOPSIS

0  Convert::DParser::ASN1=HASH(0x1082cca0)
   'CHILD' => ARRAY(0x1082ca48)
      0  Convert::DParser::ASN1=HASH(0x10837024)
         'CHILD' => ARRAY(0x10836fe8)
            0  4
            1  123456
         'TYPE' => 'RANGE'
   'TYPE' => 'SIZE'
  'TAG' => {
    'TYPE' => 'EXPLICITE'
  },
  'VAR' => 'Example_of_encodings',
  'OPT' => [
    {}
  ],
  'TYPE' => 'DEFINITIONS',
  'CHILD' => [
    'IA5String',
    {
      'VAR' => 'B',
      'OPT' => [
        {
          'CHILD' => [
            {
              'CHILD' => [
                4,
                123456
              ],
              'TYPE' => 'RANGE'
            },
            {}
          ],
          'TYPE' => 'SIZE'
        },
        {}
      ],
      'CHILD' => 'INTEGER',
      'TYPE' => 'SEQUENCEOF'
    },
    {},
    {}
  ]
};
# dont compile OPT if named type ?

=cut

sub compile_opt {
  my $op     = shift;
  # get type of items
  my $ops    = shift || $op->options_get || return undef;
  my $type   = shift || '';
  my $groups = shift || -1;
  unless(ref $ops eq 'ARRAY') {
    $ops = [ $ops ];
  }
  my $total_range = 0;
  my $i = -1;
  # sometimes the referenced type constants are not yet calculated in the stash
  my $op_r = ref($op->{TYPE}) ? $op->{TYPE} : $op;
  foreach my $op_c (@{$ops}) {
    $i++;
    # compute number of items?
    if(ref($op_c) =~ /HASH|Convert::DParser::ASN1/) {
      unless(%$op_c) {
	delete $ops->[$i--];
	next;
      }
    } else {# is it a named reference? or a keyword (ie. OPTIONAL)
      my $v_r;
      next unless(defined($v_r = $op_r->{'...'}{STASH}{$op_c} || undef));
      $ops->[$i] = $op_c = $v_r;
    }
    my $tp;
    next unless(defined($tp = $op_c->{TYPE}));
    #
    # bear in mind that a '...'
    # will ask for further construction..
    if($tp eq 'RANGE') {
      my $r = $op_c->{CHILD} || next;
      if(ref($r) eq 'ARRAY') {
	# here you want only integers...
	my @i = ();
	my $i = 0;
	foreach my $v (@$r) {
	  my $v_i;
	  if(ref($v) eq __PACKAGE__) {
	    $v_i = $v->{CHILD};
	  } elsif(defined(my $v_r = $op_r->{'...'}{STASH}{$v} || undef)) {
	    #TODO: hopefully this is type assigned...?
	    # or use a recurrent function.
	    $v_i = $v_r->{CHILD};
	    $r->[$i] = $v_r;
	  } else {
	    if($v =~ /\D{2}/) {
	      warn __PACKAGE__ . "::compile_opt not finding $v in stash\n";
	    }
	    $v_i = $v;
	  }
	  push @i, ref($v_i) ? $v_i->[-1] : $v_i;
	  $i++;
	};
	#@i = sort {$a <=> $b} @i;
	while(@i) {
	  # TODO check on limitations...
	  my $lb = shift @i;
	  my $ub = shift @i;
	  my $d = $ub - $lb + 1;
	  if($d < 0) {
	    warn __PACKAGE__ . "::compile_opt a kind of error, something is not quite right distance $d";
	  }
	  $total_range += $d;
	}
      }
    }
    if($tp eq 'SIZE') {
      my $r = $op_c->{CHILD} || next;
      my $v_i;
      if(ref($r) eq 'ARRAY') {
	$r = $r->[0];
      }
      unless(ref $r) {# size only
	if($r > 0) {
	  $total_range = 1;
	  $op->{TOTALSIZE} = $r;

	} elsif(defined(my $v_r = $op_r->{'...'}{STASH}{$r} || undef)) {
	  # is it a marker
	  $op_c->{CHILD}[0] = $r = $v_r;
	  $total_range = 1;
	  $v_i = $r->{CHILD};
	  $op->{TOTALSIZE} = ref($v_i) ? $v_i->[-1] : $v_i;

	} else {
	  warn  __PACKAGE__ . "::compile_opt can't find value $r for SIZE only";
	}
      } else {
	if($r->{TYPE} eq 'INTEGER') {# already referenced value...
	  $total_range = 1;
	  $v_i = $r->{CHILD};
	  $op->{TOTALSIZE} = ref($v_i) ? $v_i->[-1] : $v_i;

	} else {
	  # size + range
	  $op->{TOTALSIZE} = -1;
	  $op->{TOTALSIZE} = $op->compile_opt($r);
	}
      }
    }
    if($tp eq 'INTEGER') {
      # the refered info...
    }
  }
  #LOG2SIZE or ITEMBITSIZE
  if($total_range) {
    my $i = int(0.5 + log($total_range) / log(2));
    if(defined $op->{TOTALSIZE}) {
      $op->{LOG2SIZE} = $i;
    } else {
      $op->{ITEMBITSIZE} = $i;
    }
  }
  unless(defined $op->{LOG2SIZE}) {
    # be processed later using TYPE
    $op->{LOG2SIZE} = -1;
  }
  if(!defined($op->{ITEMBITSIZE})
     && defined(my $i = $per_item_bit_size{$type})
    ) {
    $op->{ITEMBITSIZE} = $i;
  }

  #ENUMERATION tagging
  if($type =~ /ENUMERATED|CHOICE/ && $groups >= 0) {
    $op->{ITEMBITSIZE} = int(0.5 + log(1 + $groups) / log(2));
  }
  if(defined($op->{LOG2SIZE}) && ($op->{LOG2SIZE} < 0)) {
    if($type =~ /(SET|SEQUENCE|CHOICE|ENUMERATED|INTEGER)$/i
      ) {#else forces size reads in strings/integers....
      $op->{LOG2SIZE} = 0;
    }
  }

=pod truth table for SIZE attributes (types)

            nothing  size only  size+range       range only    size+range+from      size+from
TOTALSIZE   undef      size.   total range        undef
LOG2SIZE     -1          0    bits of total range    -1
BITSIZE     undef      type        type        bits of total range


=cut

  return $total_range;
}



sub options_get {
  my $op = shift;
  my $ope = shift || [];
  my $v = $op->{OPE} || undef;
  if(ref($v) eq 'HASH') {
    bless($v);
  }
  if(ref($v) eq __PACKAGE__) {
    $ope = $v->options_get($ope);
  }
  if(defined($v = $op->{OPT})) {
    unless(ref($v) eq 'ARRAY') {
      $v  = [ $v ];
    }
    push(@$ope, @$v);
  }
  return $ope;
}


sub ord_ref {
  my $op = shift;
  my $v = shift || return 0;
  my $op_r = ref($op->{TYPE}) ? $op->{TYPE} : $op;
  my $v_i;
  if(ref($v) eq __PACKAGE__) {
    $v_i = $v->{CHILD};
  } elsif(defined(my $v_r = $op_r->{'...'}{STASH}{$v} || undef)) {
    #TODO: hopefully this is type assigned...?
    # or use a recurrent function.
    $v_i = $v_r->{CHILD};
  } else {
    if($v =~ /\D{2}/) {
      warn __PACKAGE__ . "::ord_ref not finding $v in stash\n";
    }
    $v_i = $v;
  }
  return ref($v_i) ? $v_i->[-1] : $v_i;
}

=heads4 order_tag

=cut

sub _compile_order_tag {
  my ($group) = @_;
  return () unless($#$group > 0);
  my @tags = map {
    defined($_->{TAG}{ORDER})
      ? $_->{TAG}{ORDER}
	#: defined $_->{TYPE}{TAG}{BER}
	#  ? ord($_->{TYPE}{TAG}{BER})
	: -1
      } @{$group};
  my @gorder = sort {$tags[$a] <=> $tags[$b]} (0 .. $#tags);
  @{$group} = @{$group}[(@gorder)];
  return @gorder;
}



=heads3 what_tag

=item DESCRIPTION

state machine which derives and complete TAG numbers and attributes localy.

it basically changes implicite, or automatic tag into explicits one.
stored into at the  key {ORDER}.

It is the stage before  PER, BER (en/de)codings,



this is so complicated I can not make sense at all of all this coding,
but it seems to have have worked for a few cases...!

=pod a TAG is like wise:

 { TYPE => AUTOMATIC|EXPLICITE|IMPLICITE
   VAR => UNIVERSAL| APPLICATION | PRIVATE | CONTEXSPECIFIC is for undef...
   CHILD => value integer
 }
 also could be called compile_tag?


=cut

*what_tag = \&compile_tag;

sub compile_tag {
  my $op = shift;
  my $v = $op->{TAG} || ($op->{TAG} = {});
  #  unless(ref($v) eq 'HASH') {
  #    # it has been already been encoded
  #    return $v;
  #  }
  #TODO:CPM071015 sometimes with verify OID $op->{'...'} get assigned to a string...
  unless(ref($op->{'...'})) {
    if(defined($op->{'...'})) {
      carp caller() . "::bad root link with::" . Dumper($op);
      my $n = $op->{'...'};
      delete($op->{'...'});
    }
  }
  # get to root class
  my $stash = shift || $op->{STASH} || $op->{'...'}{STASH}
    || $op->{'...'} || {}; # surely the case of a OID elements...
  unless(%$stash) {
    # here $op->{STASH} might have been created but been empty..
    undef $op->{STASH};
    $stash = $op->{'...'}{STASH};
  }
  unless(defined($stash->{'.'}) && %{$stash->{'.'}{TAG}}) {
    # here $op->{STASH}{'.'}{TAG} is rubbish
    undef $op->{STASH};
    $stash = $op->{'...'}{STASH} || $op->{'...'} || {};
  }
  # sorted, do not need to change.
  my $type  = $v->{TYPE} || $stash->{'.'}{TAG}{TYPE} || 'EXPLICITE';
  my $class = $v->{VAR} || undef;
  my $opt = $op->type_explicit;

  if(!defined($v->{CHILD}) && !defined($class)) {
    if($type =~ /EXPLICITE/) {
      # pretty much nothing, tag of the old type:
      my $opt = $op->{TYPE} || return undef;
      if(exists $ber_encoding_type_tag{$opt}) {
	$v->{CHILD} = $ber_encoding_type_tag{$opt};
	# it is an UNIVERSAL TYPE already....
	$v->{TYPE} = 'IMPLICITE'; # tag type is UNIVERSAL IMPLICITE...
	$v->{VAR}  = 'UNIVERSAL';
      } else {# type is a type reference and implicite
	my $op_ref = $op->op_explicit;
	#$op_ref->tag_ber; # too early? map the OP_ref to this OP...
	$op->{TAG} = $v = $op_ref->{TAG};
      }
      $v->{ORDER} = -1;

    } elsif($type =~ /AUTOMATIC/) {
      # cannot do much things here to recover without any info,
      # just get the explicit type and force it to this tag....
      # we might decide to do nothing.
      $v->{VAR} = 'UNIVERSAL';
      $v->{ORDER}
	= $v->{CHILD}
	  #CPM071015 could be an OID here under type CHOICE
	  = $ber_encoding_type_tag{$opt} || $v->{CHILD};
      #$op->tag_ber;
      #$v = %{$op_ref->{TAG}};
      #map(($v->{$_} = $op_ref->{TAG}{$_}), keys(%{$op_ref->{TAG}}));
    } else {
      #IMPLICITE
      # bad, really bad, how  to tag without any info to tagging it?
      return undef;
    }
  } elsif(defined($v->{CHILD})) {
    #tag number may be withtout a class... it shall not matter
    #class is context specific
    if($op->is_oid_arc) {
      #is this an OID arc TAG (no need for ->make_explicite)
      #return $v;
    } elsif($type =~ /EXPLICITE/) {
      # split operator and compile tag...
      # has the forward compile been done?
      $op->make_explicit;
      return $op->compile_tag;
    } else {# IMPLICITE/AUTOMATIC whithout a class,
      # and tag number already calculated
      #$op->tag_ber;
    }
    $v->{ORDER} = $v->{CHILD};
  } elsif(defined $class) {
    # a class without a tag number, yeeeak!
    # unless it is an universal class?!
    if($class eq 'UNIVERSAL' || exists $ber_encoding_type_tag{$op->{TYPE}}) {# deja vue.
      $v->{ORDER} = -1; #TODO... it could be child...
      $v->{CHILD} = $ber_encoding_type_tag{$opt};
      $v->{TYPE} = 'IMPLICITE'; # yep this is a end TAG.
    } elsif($type =~ /EXPLICITE/) {
      $op->make_explicit->compile_tag;
      return $op->compile_tag;
    } else {# IMPLICITE/AUTOMATIC whithout a class,
      # and tag number already calculated
      $v->{ORDER} = $v->{CHILD};
    }
  }
  return $v;
}



sub tag_ber {
  my $op = shift;
  my $tag =  $op->{TAG};
  return $tag->{BER} if(defined  $tag->{BER});
  my ($class, $value) = ($tag->{VAR} || 'CONTEXT', $tag->{CHILD} || 0);
  my $ope = $op->type_explicit;
  my $ber =
    (
     #($ope =~ /SET|SEQUENCE|CHOICE/)
     #&& ($tag->{TYPE} !~ /IMPLICITE/) oops explicit tags becomes implicites
     #&& ($class !~ /UNIVERSAL/)
     defined($op->{CHILD}) && ($#{$op->{CHILD}} >= 0)
     ? 0x20 # CONSTRUCTOR
     : 0x00);
  my @t = ();
  unless(exists $ber_encoding_class_tag{$class}) {
    warn sprintf "tag_ber::Bad tag class:", $class;
    $class = 'CONTEXT';
  }
  $ber |= $ber_encoding_class_tag{$class};
  if($value < 0) {
    warn "tag_ber::negative tag value:", $value;
    $value = -$value;
  }
  if($value >= 31) {
    $ber |= 31;
    $value -= 31;
    @t = ($value & 0x7f);
    unshift(@t, (0x80 | ($value & 0x7f))) while($value >>= 7);
  } else {
    $ber |= $value;
  }
  return $tag->{BER} = pack("C*", $ber, @t);
}


=heads3 name

=item DESCRIPTION

descend into operators $op->{VAR}...{VAR} sub-hashes
to return the irreductible {VAR} value.

usually a string.

=cut


sub name {
  my $op = shift;
  my $v = $op->{VAR};
  if(ref($v) eq 'HASH') {
    bless($v);
  }
  if(ref($v) eq __PACKAGE__) {
    my $n = $v->name;
    return $n if(defined $n);
  }
  return $v || undef;
}

=heads3 op_explicit

get operator from the STASH
returns explicit operator


=cut

sub type_explicit {
  my $op = shift;
  my $op_e = $op->op_explicit;
  if(ref($op_e->{TYPE}) && ($op_e ne $op)) {
    return $op_e->type_explicit;
  }
  return $op_e->{TYPE};
}

sub op_explicit {
  my $op = shift;
  my $name = shift || $op->{TYPE} || return undef;
  return $name if(ref($name) eq __PACKAGE__);
  if(exists $ber_encoding_type_tag{$name}
     || (defined($op->{TAG}{TYPE})
	 && $op->{TAG}{TYPE} eq 'IMPLICITE')
    ) {
    # this is an UNIVERSAL TYPE... good
    # $op->{TAG}{VAR} = 'UNIVERSAL' unless defined($op->{TAG}{VAR});
    # UNIVERSAL TAG, can not be more explicite than that OP...
    return $op;
  }
  return $op->{STASH}{$name} || $op->{'...'}{STASH}{$name} || $op;
}


=heads3 operator

=item DESCRIPTION

descend into operators $op->{OPE}...{OPE} sub-hashes
to return the irreductible {OPE} value.

=cut


sub operator {
  my $op = shift;
  my $v = $op->{OPE};
  if(ref($v) eq 'HASH') {
    bless($v);
  }
  if(ref($v) eq __PACKAGE__) {
    my $n = $v->operator;
    return $n if(defined $n);
  }
  return $v || undef;
}


=heads3 compile_one

=item DESCRIPTION



=cut

sub compile_one {
  my $module = shift;
  my $op     = shift || $module;
  my $stash = $module->{STASH} || {};
  my $err = '';
  # here we might have a string ... or a number
  #
  unless(ref($op) eq __PACKAGE__) {
    # this is a value scalar...string or number
    warn __PACKAGE__, "::compile_one::<", $op, "> will not be compiled";
    return $err;
  }
  # if VERIFY left this HASH references in each operators
  # I uses this to check any redundancies of compilation.
  if(exists $op->{TODO}) {
    delete($op->{TODO});
  } else {
    return $err;
  }
  # get name (in VAR or TYPE-VAR)
  my $op_nm = $op->name;
  my $name  = shift || $op_nm;
  my $nm    = $name;

  my $group = defined($op->{CHILD})
    ? $op->{CHILD}
      : [];
  unless(ref($group) eq 'ARRAY') {
    # $group is a string...a number?... this is a setof, sequenceof, choiceof, from,
    # , OID path,...
    # get it from the stash?
    # check the stash
    if(defined(my $ref = $module->{STASH}{$group})) {
      $group = [ $ref ];
      # here complete verification links...
      if(defined($op->{CHILD})) {
	$op->{CHILD} = $group;
      }
    } else {
      # why not?
      $op->{CHILD} = $group = [ $group ];
    }
  }
  my $i = -1;
  my $auto_tag_val = ($module->{TAG}{TYPE} eq 'AUTOMATIC' ? 0 : -1);
  my @per_group_optional;
  my $type = $op->op_explicit;
  if(ref($type)
     && !defined($type->{OPE})
     && defined($type->{'...'})
     && ref($type->{'...'}) eq __PACKAGE__
     && ($type->{'...'} ne $op->{'...'})
    ) {# could be looping badly, this is why the last inequality.
    $err .= $type->{'...'}->compile_one($type);
  }
  if(ref($type) && defined($type->{OPE})) {
    #type OPE... pass it on to op.
    #and parse OPT, CHILD... TAG shall be linked in what_tag
    foreach my $k (qw(GROUP_OPTIONAL CHILD OPT)) {
      my $v = $op->{$k} || undef;
      unless(defined($v)
	     && ((ref($v) eq 'HASH' && %$v)
		 || (ref($v) eq 'ARRAY' && @$v))) {
	$op->{$k} = $type->{$k};
      }
    }
  } else {
    foreach my $op_c (@$group) {# op {CHILD}=>[..., op_c , ....]
      $i++;
      # check for NamedType...
      unless(ref($op_c)) {
	if (defined $module->{STASH}{$op_c}
	    && !($op->type_explicit eq 'ENUMERATED')
	   ) {
	  # not very very difficult to replace?!
	  #$op_c = $group->[$i] = $module->{STASH}{$op_c};
	  $op_c = $module->{STASH}{$op_c};
	}
      }
      if (ref($op_c) eq 'HASH') {
	bless $op_c;
      }
      #OID
      #ModuleIdentifier : modulereference DefinitiveIdentifier

      # here we have a Type...or a (named) variable
      next unless(ref($op_c) eq  __PACKAGE__);

      # 16 Type :
      # compile TYPE  then we can compile OPE... and TAG
      # TYPE is implicit here...
      if(defined($type = $op_c->{TYPE})) {
	# setup the parenting
	# we could restrict this only for composed TAGs...
	unless(defined $op_c->{'...'}) {
	  $op_c->{'...'} = $stash->{'.'};
	}
	if(ref($type) eq 'ARRAY') {
	  # bad news this is dodgy
	  carp(caller(), "::compile_one:: destroying bad {type} field ", Dumper($type));
	  delete($op_c->{TYPE});
	  # this is for...861 -9.5
	  #TypeFieldSpec ::=typefieldreference TypeOptionalitySpec?
	  #TypeOptionalitySpec ::= OPTIONAL | DEFAULT Type
	  #TypeFieldSpec, where Type is an arbitrary type (any kind of type!) ITUT X861_3.4.20
	} else {
	  #
	  # sub ref TYPE
	  if(defined(my $op_ref = $op_c->op_explicit($type) || $type)
	     && !exists($ber_encoding_type_tag{$type})
	     && !defined($op_c->{OPE})
	    ) {
	    if($op_ref ne $op_c) {
	      $op_c->{TYPE} = $op_ref;

	      #and parse OPT, CHILD... TAG shall be linked in what_tag
	      foreach (qw(CHILD OPT GROUP_OPTIONAL)) {
		my $v = $op_c->{$_} || undef;
		unless(defined($v)
		       && ((ref($v) eq 'HASH' && %$v)
			   || (ref($v) eq 'ARRAY' && @$v))) {
		  $op_c->{$_} = $op_ref->{$_};
		}
	      }
	    } elsif($type eq 'CLASS') {# add it to ber encoding type tag?
	    } elsif($op->type_explicit eq 'CLASS') {#CPM071112
	      # here we have a child op_c of a op CLASS
	      # type of type kind of object... 
	    } else {
	      warn "There is a looping type with TYPE=" . $type . "\n";
	      # need to find type in other parts?#$err .= $module->compile_one;
	      


	    }
	  }
	}
	#TODO0610: fortify this algorithm
	#here AUTO TAG...
	#shall be applied to SET/CHOICE/SEQUENCE?
	# here needs op_c, group, and an index auto_tag_val...
	if($auto_tag_val >= 0) {
	  if(defined($op_c->{TAG}{CHILD}) || $op_c->{TAG}{VAR}) {
	    # also be sure class is not UNIVERSAL-IMPLICITE? or get a greater number
	    if(($auto_tag_val <= 3) && !defined($op_c->{OPE})) {
	      #oops, revert the previous $op_c->{TAG}{CHILD}
	      my $j = $i;
	      while($j >= 0) {
		unless(defined($group->[$j]->{TAG}{VAR})
			&& ($auto_tag_val < $j)) {
		  undef($group->[$j]->{TAG}{CHILD});
		  $auto_tag_val--;
		}
		$j--;
	      }
	    }
	  } else {
	    $op_c->{TAG}{CHILD} = ++$auto_tag_val;
	  }
	}
	#DEFAULT or OPTIONAL
	if($op_c->is_optional || defined($op_c->is_default)) {
	  push(@per_group_optional, $i);
	}
	unless(defined($op_c->{OPE})) {
	  # might have to split OP, this is why TAG is calculated
	  # before compile...
	  $op_c->compile_tag;
	  $err .= $module->compile_one($op_c);
	}
      }
    }
    ;
  }
  #
  # OUT of the group...
  #
  # we might do this after compiling CHILD
  # compile TYPE  then we can compile OPE... and TAG
  # get to the Named Type... (explicit type name)
  if(defined($type = $op->type_explicit)) {
    if($type eq 'FROM') {# carry building up the stash
      # stash it...
      if(defined(my $v = $stash->{'..'}{$name} || undef)) {
	my $i = 0;
	my $e = $op->{CHILD};
	unless(ref($e) eq 'ARRAY') {
	  $e = [ $e ];
	}
	foreach (@$e) {
	  if(defined(my $vv = $v->{STASH}{$_} || $stash->{$_} || undef)) {
	      $e->[$i] = $stash->{$_} = $vv;
	    } #else zut still not yet processed after the verify.
	  $i++;
	};
      }
      # enough in FROM
      return $err;
    }
    #CHOICE
    if($type =~ /CHOICE|SET/) {
      #TODO:CPM071005 Here we need to flatten CHOICEs and check that SET and CHOICE do not contain duplicate tags
      # OID arc also shall fall here.
      #if($op->is_oid_arc) {
      my @gorder = _compile_order_tag($group);
      #}
    }
    if($#$group > 0 && $type =~ /SET|SEQUENCE/) {
      # canonical order by sorting the outermost  tag
      # In case we do PER/CER encoding we order the SET elements by their tags
      my @gorder = _compile_order_tag($group);
      #don't forget per_group_optional...
      # the PER encoding would need the bitmap truth
      # of possible absentee
      if($#per_group_optional >= 0) {
	push @{$op->{GROUP_OPTIONAL}}
	  , map($group->[$gorder[$_]], @per_group_optional);
      }
    }
    # set a default size constraint...for PER-unvisible
    # SIZE ... log(2, $tot_size)
    #
    $op->{OPE} = $ber_encoding_type_tag{$type};
    # here stash shall go if not a module...!
    undef $op->{STASH} unless($type eq 'DEFINITIONS');
    #
    # there shall be a TAG when a TYPE...
    # compile TAG
    $op->tag_ber;
    $op->compile_opt(undef, $type, $#$group);
    # also auto tag... 
    warn __PACKAGE__, "::compile_one::VAR=", $op->{VAR} || 'undef'
      , " TYPE=", $op->type_explicit
      , " TAG=x", unpack("H*", $op->{TAG}{BER}) if(defined $op->{TODO});
  }
  # shall return a ref ARRAY sub tree?! instead of an operators
  #
  # save name has been done in verify...
  # $module?
  return $err;
}


=heads2 compile

=item DESCRIPTION

 The tree should be valid enough to be able to
    - resolve references
    - encode tags
    - verify CHOICEs do not contain duplicate tags
 once references have been resolved, and also due to
 flattening of COMPONENTS, it is possible for an op
 to appear in multiple places. So once an op is
 compiled we bless it. This ensure we dont try to
 compile it again.
 tree is an array... of blessed HASH

=cut


sub compile {
  my $s = shift;
  my $t = shift;
  $t = [ $t ] unless(ref($t) eq 'ARRAY');
  foreach my $op (@$t) {
    if(ref($op) eq 'HASH') {
      bless $op;
    }
    if(ref($op) eq  __PACKAGE__) {
      $op->compile_one;
    }
  }
  $t;
}

=heads2 make_explicit

=item DESCRIPTION

 Given an OP, wrap it in a SEQUENCE

 the name is of the parent...

 why this???! EXPLICIT means the TAG is calculated using parent TAG
 and usually (like for CHOICE) the duo TAG/LENGTH could be duplicated if
 a tagging number exists

=cut

*explicit = \&make_explicit;

sub make_explicit {
  my $op = shift;
  # the new type is a descendant.
  my $op_i = bless {%{$op}};
  # with default (explicite) tag
  # However when op_i is implicite... now the children will be tagged might have problem in CHOICE since the AUTO tagging would be redone?
  undef $op_i->{VAR};
  undef $op_i->{TAG};
  undef $op->{OPT};
  $op->{CHILD} = [ $op_i ];
  $op->{TYPE}  = 'SEQUENCE';
  undef $op->{OPE}; #allows forward compilation...
  # forces local tagging
  $op->{TAG}{TYPE} = 'IMPLICITE';
  return $op_i;
}


sub find_in_stash {
  my $op = shift;
  my $stash = shift || return undef;
  if(defined(my $opt = $op->{STASH} || $op->{'...'}{STASH})) {
    (my @keys)
      = (ref($stash) eq 'ARRAY'
	 ? @$stash
	 : (ref($stash) eq 'HASH'
	    ? keys(%$stash)
	    : [ $stash ]
	   )
	);
    my $k = '';
    foreach (@keys) {
      $k = $_;
      last if(defined($opt->{$_}));
    };
    return $opt->{$k} || undef;
  }
  return undef;
}


sub find_in_sub_stash {
  my $op = shift;
  my $stash = shift || return undef;
  my $op_s = $op->{STASH}{'..'} || return undef;
  my $r;
  foreach (values(%$op_s)) {
    if(defined(my $s = $_->{STASH})) {
      return($r) if(defined($r = $op->find_in_stash($stash)));
    }
  };
  return undef;
}


#
# options available:
# BER DER CER
# PER x ALIGNED UNALIGNED x BASIC CANONICAL
# 
# 
sub encode {
  my $self  = shift;
  my $stash = shift;
  my $script = $self->{script};
  my $e = $self->create_delayed_object
    ('encoder'
     , script => (ref $script eq 'ARRAY'
		  ? $script
		  : [ $script ])
     , stash  => $stash
     , @_
    );
  #Convert::DParser::ASN1::Encode->new($stash, script => $self);
  #  eval {} or do { $self->{error} = $@; undef };
  return $e;
}

sub decode {
  my $self  = shift;
  my $stash = shift;
  my $script = $self->{script};
  my $e = $self->create_delayed_object
    ('decoder'
     , script => (ref $script eq 'ARRAY'
		  ? $script
		  : [ $script ])
     , buf    => \$stash
     , @_
    );
  return $e;
}


##
## Utilities
##

# How many bytes are needed to encode a number

*num_length = \&Convert::ASN1::num_length;

=pod

sub num_length {
  $_[0] >> 8
    ? $_[0] >> 16
      ? $_[0] >> 24
	? 4
	: 3
      : 2
    : 1
}

=cut

# Convert from a bigint to an octet string

*i2osp = \&Convert::ASN1::i2osp;

=pod

sub i2osp {
    my($num, $biclass) = @_;
    eval "use $biclass";
    $num = $biclass->new($num);
    my $neg = $num < 0
      and $num = abs($num+1);
    my $base = $biclass->new(256);
    my $result = '';
    while($num != 0) {
        my $r = $num % $base;
        $num = ($num-$r) / $base;
        $result .= chr($r);
    }
    $result ^= chr(255) x length($result) if $neg;
    return scalar reverse $result;
}

=cut


*os2ip = \&Convert::ASN1::os2ip;

=pod

# Convert from an octet string to a bigint
sub os2ip {
    my($os, $biclass) = @_;
    eval "require $biclass";
    my $base = $biclass->new(256);
    my $result = $biclass->new(0);
    my $neg = ord($os) >= 0x80
      and $os ^= chr(255) x length($os);
    for (unpack("C*",$os)) {
      $result = ($result * $base) + $_;
    }
    return $neg ? ($result + 1) * -1 : $result;
}

=cut

*asn_tag = \&Convert::ASN1::asn_tag;

=pod

# Given a class and a tag, calculate an integer which when encoded
# will become the tag. This means that the class bits are always
# in the bottom byte, so are the tag bits if tag < 30. Otherwise
# the tag is in the upper 3 bytes. The upper bytes are encoded
# with bit8 representing that there is another byte. This
# means the max tag we can do is 0x1fffff
sub asn_tag {
  my($class,$value) = @_;

  die sprintf "Bad tag class 0x%x",$class
    if $class & ~0xe0;

  unless ($value & ~0x1f or $value == 0x1f) {
    return (($class & 0xe0) | $value);
  }

  die sprintf "Tag value 0x%08x too big\n",$value
    if $value & 0xffe00000;

  $class = ($class | 0x1f) & 0xff;

  my @t = ($value & 0x7f);
  unshift @t, (0x80 | ($value & 0x7f)) while $value >>= 7;
  unpack("V",pack("C4",$class,@t,0,0));
}

=cut


=head2 white_space_fn

=head3 DESCRIPTION

    a default ASN1 white space function also detecting comments.

=TODO

to find a way linking nodes into comments, may be by using locy?

=cut


sub white_space_fn {
  my $pp = shift || die (__PACKAGE__ , "::my_white_space_fn::wehere is ppi?");
  my $loc = Parser::D::d_loc_t->new(shift, $pp);
  my $s = $loc->{buf};
  my $a = pos($$s) = $loc->tell;
  $$s =~ m/\G\s*/gcs;
  my (@comments) = $$s =~ m/\G\s*(--.*)\s*/gcm;
  #
  # trigger token in globals?
  $loc->seek(my $b = pos($$s));
  if(@comments) {
    my $p = $pp->interface;
    push @{$p->{comments}}, ($a, @comments);
  }
}

=head2 _make_graph

    a small debugging function generating a dot graph 
    of the grammar tree visualised in Xfig.
    use with <GraphViz>.

=head3 FLOW

=item    self
=item    file name
=item    dot 'fig' object  <GraphViz>.

=item    call &_iterate_graph


=cut

sub _make_graph {
  #use GraphViz;
  my $t = shift;
  my $n = shift || ".g." . $$;
  my $g = GraphViz->new(pagewidth => 1);
  _iterate_graph($t, 'root', $g);
  $g->as_fig($n . ".fig");
}

sub _iterate_graph {
  my ($t, $l, $g) = @_;
  if(ref($t)) {
    return if(grep({$t eq $_} keys(%{$g->{NODES}})));
    if(ref($t) eq 'ARRAY') {
      my $i = 0;
      #$g->add_node("$t", label => $l,  name => ref($t));
      foreach (@$t) {
	_iterate_graph($_, $l, $g);
	my $s = (defined($_) ? "$_" : 'undef');
	$g->add_edge("$t" => $s,  label => '[' . $i . ']');
	$i++;
      }
    } elsif(ref($t) eq 'Convert::DParser::ASN1' || ref($t) eq 'HASH') {
      my $i = 0;
      #$g->add_node("$t", label => $l, name => ref($t));
      foreach (keys(%$t)) {
	$i = $t->{"$_"} || 'undef';
	_iterate_graph($i, $_, $g);
	$g->add_edge("$t" => "$i",  label => '{' . $_ . '}');
      }
    }
  } elsif($t) {# string or number, no good!
    $g->add_node("$t", name => 'X');
  }
}




sub install_embededpdv {
  my $stash = shift;

  unless(exists($stash->{EMBEDEDPDV})) {
    my $epdv
      = $stash->{EMBEDEDPDV}
      = bless
	(
	 {VAR => 'EMBEDEDPDV', TYPE => 'SEQUENCE'
	  , CHILD =>
	  [{VAR	=> 'identification', TYPE	=> 'CHOICE'
	    , CHILD	=>
	    [{VAR	=> 'syntaxes', TYPE	=> 'SEQUENCE'
	      , CHILD	=>
	      [{VAR	=> 'abstract', TYPE	=> 'OBJECTIDENTIFIER'}
	       , {VAR	=> 'transfer', TYPE	=> 'OBJECTIDENTIFIER'}
	       #-- Abstract and transfer syntax object identifiers --,
	       , {VAR	=> 'syntax', TYPE	=> 'OBJECTIDENTIFIER'}
	       #-- A single object identifier for identification of the abstract
	       #-- and transfer syntaxes --,
	       , {VAR	=> 'presentation-context-id', TYPE	=> 'INTEGER'}
	       #-- (Applicable only to OSI environments)
	       #-- The negotiated OSI presentation context identifies the
	       #-- abstract and transfer syntaxes --,
	       , {VAR	=> 'context-negotiation', TYPE	=> 'SEQUENCE'
		  , CHILD	=>
		  [{VAR	=> 'presentation-context-id', TYPE	=> 'INTEGER'}
		   , {VAR	=> 'transfer-syntax', TYPE	=> 'OBJECTIDENTIFIER'}
		  ]}
	       #-- (Applicable only to OSI environments)
	       #-- Context-negotiation in progress, presentation-context-id
	       #-- identifies only the abstract syntax
	       #-- so the transfer syntax shall be specified --,
	       , {VAR	=> 'transfer-syntax', TYPE	=> 'OBJECTIDENTIFIER'}
	       #-- The type of the value (for example, specification that it is
	       #-- the value of an ASN.1 type)
	       #-- is fixed by the application designer (and hence known to both
	       #-- sender and receiver). This
	       #-- case is provided primarily to support
	       #-- selective-field-encryption (or other encoding
	       #-- transformations) of an ASN.1 type --,
	       , {VAR	=> 'fixed', TYPE	=> 'NULL'}
	       #-- The data value is the value of a fixed ASN.1 type (and hence
	       #-- known to both sender and receiver) --
	       , {VAR	=> 'data-value-descriptor'
		  , TYPE	=> 'ObjectDescriptor'
		  , OPT	=> [{TYPE => 'OPTIONAL'}]
		 }
	       #-- This provides human-readable identification of the class of the
	       #-- value --,
	       , { VAR	=> 'data-value', TYPE	=> 'OCTETSTRING'}
	      ]
	      , OPT	=>
	      [{TYPE	=> 'WITHCOMPONENTS'
		, CHILD	=>
		[{TYPE => '...'}
		 , {VAR	=> 'data-value-descriptor'
		    , OPT	=> 'ABSENT'}
		]
	       }]
	     }]
	   }]
	 }
	);
    $epdv->verify_array($stash);
  }
}

=heads3  install_external


cf. 34.5 Notation for the external type


=cut


sub install_external {
  my $stash = shift;
  unless(exists($stash->{EXTERNAL})) {
    my $exte
      = $stash->{EXTERNAL}
      = bless
	(
	 {VAR => 'EXTERNAL', TYPE => 'SEQUENCE'
	  , CHILD =>
	  [{VAR	=> 'identification', TYPE	=> 'CHOICE'
	    , CHILD	=>
	    [{VAR	=> 'syntaxes', TYPE	=> 'SEQUENCE'
	      , CHILD	=>
	      [{VAR	=> 'abstract', TYPE	=> 'OBJECTIDENTIFIER'}
	       , {VAR	=> 'transfer', TYPE	=> 'OBJECTIDENTIFIER'}
	       #-- Abstract and transfer syntax object identifiers --,
	       , {VAR	=> 'syntax', TYPE	=> 'OBJECTIDENTIFIER'}
	       #-- A single object identifier for identification of the abstract
	       #-- and transfer syntaxes --,
	       , {VAR	=> 'presentation-context-id', TYPE	=> 'INTEGER'}
	       #-- (Applicable only to OSI environments)
	       #-- The negotiated OSI presentation context identifies the
	       #-- abstract and transfer syntaxes --,
	       , {VAR	=> 'context-negotiation', TYPE	=> 'SEQUENCE'
		  , CHILD	=>
		  [{VAR	=> 'presentation-context-id', TYPE	=> 'INTEGER'}
		   , {VAR	=> 'transfer-syntax', TYPE	=> 'OBJECTIDENTIFIER'}
		  ]}
	       #-- (Applicable only to OSI environments)
	       #-- Context-negotiation in progress, presentation-context-id
	       #-- identifies only the abstract syntax
	       #-- so the transfer syntax shall be specified --,
	       , {VAR	=> 'transfer-syntax', TYPE	=> 'OBJECTIDENTIFIER'}
	       #-- The type of the value (for example, specification that it is
	       #-- the value of an ASN.1 type)
	       #-- is fixed by the application designer (and hence known to both
	       #-- sender and receiver). This
	       #-- case is provided primarily to support
	       #-- selective-field-encryption (or other encoding
	       #-- transformations) of an ASN.1 type --,
	       , {VAR	=> 'fixed', TYPE	=> 'NULL'}
	       #-- The data value is the value of a fixed ASN.1 type (and hence
	       #-- known to both sender and receiver) --
	       , {VAR	=> 'data-value-descriptor'
		  , TYPE	=> 'ObjectDescriptor'
		  , OPT	=> [{TYPE => 'OPTIONAL'}]
		 }
	       #-- This provides human-readable identification of the class of the
	       #-- value --,
	       , { VAR	=> 'data-value', TYPE	=> 'OCTETSTRING'}
	      ]
	      , OPT	=>
	      [{TYPE	=> 'WITHCOMPONENTS'
		, CHILD	=>
		[{VAR => '...'}
		 , {VAR	=> 'identification'
		    , OPT	=>
		    [{TYPE	=> 'WITHCOMPONENTS'
		    , CHILD	=>
		      [{VAR	=> '...'}
		      , {VAR	=> 'syntaxes', TYPE	=> 'ABSENT'}
		      , {VAR	=> 'transfer-syntax', TYPE	=> 'ABSENT'}
		      , {VAR	=> 'fixed', TYPE	=> 'ABSENT'}
		      ]
		     }]
		   }]
	       }]
	     }]
	   }]
	 }
	);
    $exte->verify_array($stash);
  }
}

=head3 44.3 The type is defined, using ASN.1, as follows:


=cut

sub install_objectdescriptor {
  my $stash = shift;
  unless(exists($stash->{ObjectDescriptor})) {
    my $objd
      = $stash->{ObjectDescriptor}
      = bless
	({
	  VAR => 'ObjectDescriptor'
	  , OPT => [{TYPE =>  'UNIVERSAL', CHILD => 7}
		    , TYPE => 'IMPLICIT'
		   ]
	  , CHILD => 'GraphicString'
	 }
	);
  }
}

=head3 extensions

ExtensionAndException ::= "..." | "..." ExceptionSpec

ExtensionAdditionGroup ::= "[[" VersionNumber ComponentTypeList "]]"


=cut


=head3

ObjectClassAssignment (see 9.1);
ObjectAssignment (see 11.1);
ObjectSetAssignment (see 12.1).
UsefulObjectClassReference ::= TYPE-IDENTIFIER | ABSTRACT-SYNTAX
of which the first alternative is specified in Annex A, and the second in Annex B.
NOTE  The names TYPE-IDENTIFIER and ABSTRACT-SYNTAX are listed in ITU-T Rec. X.680 | ISO/IEC 8824-1, 11.27, as
reserved words.

OPERATION ::= CLASS
{
&ArgumentType OPTIONAL,
&ResultType OPTIONAL,
&Errors ERROR OPTIONAL,
&Linked OPERATION OPTIONAL,
&resultReturned BOOLEAN DEFAULT TRUE,
&code INTEGER UNIQUE
}
ERROR ::= CLASS
{
&ParameterType OPTIONAL,
&code INTEGER UNIQUE
}

=cut

=heads3

A.2 The TYPE-IDENTIFIER information object class is defined as:
TYPE-IDENTIFIER ::= CLASS
{
&id OBJECT IDENTIFIER UNIQUE,
&Type
}
WITH SYNTAX {&Type IDENTIFIED BY &id}


MHS-BODY-CLASS ::= TYPE-IDENTIFIER
g4FaxBody MHS-BODY-CLASS ::= {BIT STRING IDENTIFIED BY {mhsbody 3}}



INSTANCE OF MHS-BODY-CLASS
has an associated sequence type of:
SEQUENCE
{
type-id MHS-BODY-CLASS.&id,
value [0] MHS-BODY-CLASS.&Type
}

=cut


sub install_type_identifier {
}



=head3


has an associated sequence type of:
B.2 The ABSTRACT-SYNTAX information object class is defined as:
ABSTRACT-SYNTAX ::= CLASS
{
&id OBJECT IDENTIFIER UNIQUE,
&Type,
&property BIT STRING {handles-invalid-encodings(0)} DEFAULT {}
}
WITH SYNTAX {
&Type IDENTIFIED BY &id [HAS PROPERTY &property]
}
The &id field of each ABSTRACT-SYNTAX is the abstract syntax name, while the &Type field contains the single ASN.1
type whose values make up the abstract syntax. The property handles-invalid-encodings indicates that the invalid
encodings are not to be treated as an error during the decoding process, and the decision on how to treat such invalid
encodings is left up to the application.
B.3 This information object class is defined as being "useful" because it is of general utility, and is available in any
module without the necessity for importing it.
B.4 Example
If an ASN.1 type has been defined called XXX-PDU, then an abstract syntax can be specified which contains all the
values of XXX-PDU by the notation:
xxx-Abstract-Syntax ABSTRACT-SYNTAX ::=
{ XXX-PDU IDENTIFIED BY {xxx 5} }
See ITU-T Rec. X.680 | ISO/IEC 8824-1, E.3, for a detailed example of use of the ABSTRACT-SYNTAX information
object class.


=cut

sub install_abstract_syntax {

}




1;

__END__

=head1 COPYRIGHTS, LICENCES, and DISCLAIMERS

the squeleton shall be  borrowed from  <Convert::ASN1> (c)2000-2005 Graham Barr <gbarr@pobox.com>

thee flesh and a few more functions is Copyright (c) 2006-2007 <christian.montanari@sharp.eu>, Sharp-Telecommunication of Europe Ltd. . All rights reserved.

This program is free software; you can redistribute it and/or  modify it under the same terms as Perl itself.

use at your own risks.yo.


=cut
