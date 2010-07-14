# Copyright (c) 2000-2005 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Convert::DParser::ASN1::Decode;
use strict;
use base qw(Class::Container);
use Params::Validate qw(:types);

=heads5   Universal decoding...mapping.



=cut



__PACKAGE__->valid_params
  (
   stash             => {default => []}
   , decode_bigint   => {default => 'Math::BigInt'}
   , decode_real     => {default => 'binary'}
   , decode_timezone => {optional => 1}
   , decode_time     => {default => 'withzone'}
   , script          => {type => ARRAYREF}
   , buf             => {type => SCALARREF}
   , type            => {default => [qw(PER BER DER PERALIGNED PERUNALIGNED)]}
   , regexp          => {default => qr/.*/}
   );


sub new {
  my $class = shift || __PACKAGE__;
  my $s = $class->SUPER::new(@_);
  if(length(${$s->{buf}})) {
    $s->decode;
  }
  return $s;
}

sub decode {
  my $s     = shift;
  my $ops   = shift || $s->{script};
  # niggles
  unless(ref($ops) eq 'ARRAY') {
    $ops = [ $ops ];
  }
  my $maxl  = -1;
  my $end   = length(${$s->{buf}}) * 8; # in bits?
  my $idx   = -1;
  my $rgx = $s->{regexp};

  foreach my $op (@{$ops}) {
    $idx++;
    unless(ref $op) { # here the script is missing a reference...
      warn __PACKAGE__, "::decode ERROR: operator type <", $op, "> is not compiled";
      next;
    }
    # op could be a module dont do if already stashed away...
    #next OP if((ref($stash) eq 'HASH') && defined($stash->{$v}));
    if($op->{TYPE} eq 'DEFINITIONS') {
      # go and decode in the stash...[values(%{$op->{STASH}})]
      my $l = $s->decode($op->{CHILD});
      if($maxl < $l) {
	$maxl = $l;
      }
    } elsif($op->{VAR} =~ /$rgx/) {
      foreach my $type (@{$s->{type}}) {
	my $tp = __PACKAGE__ . "::" . $type;
	eval {
	  require $tp;
	};
	my $d = bless {%$s}, $tp || next;
	my $l = $d->decode($op, \(my $res));
	if($l <= $end) {# a good decode...
	  push(@{$s->{stash}}, [$l, $type, $res]);
	  if($maxl < $l) {
	    $maxl = $l;
	  }
	}
      };
    }
  }
  return $maxl;
}


1;
__END__
