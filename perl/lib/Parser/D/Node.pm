#
#
# The Node business
#
#
# dpn->user is its associated SV* of a Parser::D::Node
#

=heads2 D_ParseNodePtr


  #creates Parser::D::Node in make_pl_node




=cut

package D_ParseNodePtr;
use Devel::Peek;
use Data::Dumper;

sub new {
  my $class = shift || __PACKAGE__;
  my $t = $class->SUPER::new(@_);
  return $t;
}



=pod

  static void
free_ParseTreeBelow(Parser *p, PNode *pn) {
  int i;
  PNode *amb;

  for (i = 0; i < pn->children.n; i++) 
    unref_pn(p, pn->children.v[i]);
  vec_free(&pn->children);
  if ((amb = pn->ambiguities)) {
    pn->ambiguities = NULL;
    free_PNode(p, amb);
  }
}

=cut

# unreferences user parts of nodes...free_node_fn...
sub free_D_ParseTreeBelow {
}


sub free_D_ParseNode {
}



=heads3 D_ParseNodePtr::symbol

=heads4 DESCRIPTION

	set or get the symbol index value of the current Parse Node Pointer.

=heads4 ARGUMENTS

INPUT:

=item	D_ParseNode*

	Now, this is difficult to find a pointer like this!
	D_ParseNodePtr can be returned from Parser::D::run.
	there might be other instances when this pointer is available externaly.
	
	
=item   D_ParseNode.symbol

	this argument is optional and when inserted, the node symbol will be modified by the given value.


RETURNS:

=item   D_ParseNode.symbol


=heads4 SYNOPSIS

$p = Parser::D->new(grammar => 'hello::="hello"');
$r = $p->run('hello');
my($i) = $r->symbol;


=heads2 Parser::D::Node

	this is the 


=cut

package Parser::D::Node;
use Parser::D;
use Devel::Peek;
use Data::Dumper;


=heads3  Parser::D::Node:new

 since this class object is refering a C-object D_ParseNode
 it requires a pointer to D_ParseNodePtr (this accessor object)

 a buffer pointer is also nescesary ?!

=cut

sub new {
  my $class = shift ||  __PACKAGE__;
  my ($dp, $this) = @_;
  return undef unless(ref($this) eq 'D_ParseNodePtr');
  return undef unless(ref($dp) eq 'Parser::D');
  my $self
    = {
       papa => $dp
       , this => $this #this is actually the "D_ParseNodePtr" structure...?
       , d_parser => $dp # back reference to Parser::D
       , buf => $dp->{buf_start}
       , name => ''
       #try a tie... or shall be read only...
       , action_index =>  $this->action_index
       , children_list => $this->children_list
       , user => $this->user
       , val => $this->val
       , symbol => $this->symbol
       , globals =>  $this->globals
       , d_get_number_of_children => $this->d_get_number_of_children
       , final_code =>  $this->final_code
       , speculative_code => $this->speculative_code
      };

=pod

  foreach $_ (qw( action_index)) {
     $self{$_} = eval {  $this->{ $_ } };
  }

=cut

  # do a bit of blessing...
  bless  $self, $class;
}


sub dump {
  my $dpn = shift;
  print Dumper($dpn);
}



sub dump_branch {

}


sub dump_tree {

}
1;
__END__
