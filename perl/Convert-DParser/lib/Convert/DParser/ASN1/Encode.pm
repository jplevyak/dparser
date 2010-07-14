# Copyright (c) 2000-2005 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Convert::DParser::ASN1::Encode;
use strict;
use Convert::DParser::ASN1 qw(:encode);
use base qw(Class::Container);
require POSIX;

BEGIN {
  use constant CHECK_UTF8 => $] > 5.007;
  unless(CHECK_UTF8) {
    local $SIG{__DIE__};
    eval { require bytes } and 'bytes'->import
  }
}

# These are the subs which do the encoding, they are called with
# 0      1    2       3     4     5
# $opt, $op, $stash, $var, $buf, $loop
# The order in the array must match the op definitions above

our @encode
  = (
     sub { die "internal error\n" }
     , \&boolean
     , \&integer
     , \&bitstring
     , \&bcd #4 also octet string
     , \&null
     , \&object_id
     , \&any     #7 ?ObjectDescriptor
     , undef     #8
     , \&real

     , \&enum #10
     , undef  #11
     , \&utf8
     , undef  #13 relative_oid
     , \&sequence #14
     , \&set      #15 SET is the same encoding as sequence
     , \&sequence #16
     , \&set      #17 SET is the same encoding as sequence
     , \&string   #numeric_string 18, printable string
     , undef      #19

     , \&string #20 teletex
     , \&string #21 videotext
     , \&string #22 IA5 srtring
     , \&time   #23 utc TIME
     , \&time   #24 gen time
     , \&string #25
     , \&string #26
     , \&string #27
     , \&string #28
     , \&string #29

     , \&string #30 BMP
     , \&encode  #31 reserved...
    );

use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   stash             => {default => {}}
   , encode_bigint   => {default => 'Math::BigInt'}
   , encode_real     => {default => 'binary'}
   , encode_timezone => {optional => 1}
   , encode_time     => {default => 'withzone'}
   , script          => {type => ARRAYREF}
   , type            => {default => [qw(BER PER DER PERALIGNED PERUNALIGNED)]}
  );

__PACKAGE__->contained_objects
  (
   #compiler => {class => 'Convert::DParser::ASN1', delayed => 1}
  );


sub new {
  my $class = shift || __PACKAGE__;
  my $s = $class->SUPER::new(@_);
  if(%{$s->{stash}}) {
    $s->encode;
  }
  return $s;
}

# encode is like a CHOICE/SET
sub encode {
  my $s     = shift;
  my $ops   = shift || $s->{script};
  my $stash = shift || $s->{stash};
  my $var   = shift || undef;
  my $buf   = shift || \ ${$s->{buf}};
  my $path  = shift || [];
  unless(ref($ops) eq 'ARRAY') {
    $ops = [ $ops ];
  };
  my $k = undef;
  if(defined($var)) {
    # then var is an index number or a key, get from stash?
  }
  # if var is present then we would select the right operators
  my $idx = -1;
  foreach (@$ops) {
    $idx++;
    # here OPT shall be VAR instead?! oops
    # I thought OPT is not an operator
    # STASH also contains all the VARs...
    # VAR is more like a path of OPT.
    my $op = $_;
    # if we starts with an array of modules,
    # we would need to find the rigth one?
    if($op->{TYPE} eq 'DEFINITIONS') {
      next unless(defined($op = $_->find_in_stash($stash)));
    }
    my $enc = $op->operator;
    if(defined($var = $op->{VAR}) && !defined($op->{TAG}{BER})) {
      #push @$path, $var;
      #warn(join(".", @$path)," is undefined in operator:" , $op->{TYPE})
      #	unless(defined($stash->{$var}) && ($enc != opENCODE));
      warn __PACKAGE__,"::encode undefined TAG with type:", $op->{TYPE};
      #
      # is stash is HASH and no $var... then we have a trouble....
      # because we do not know how to reduce the tree
      # hopfully this is a sequence/set/choice business with explicit TAGs
    }
    # we have to have an OPE to start tagging?#if(defined $op->{OPE});
    ${$buf} .= $op->{TAG}{BER};
    push(@$path, $var) if(defined($var));
    &{$encode[$enc]}
      ($s
       , $op # could be a way of doing it. ref($op->{OPE}) ? $op->{OPE} : $op
       , ref($stash)
       ? (UNIVERSAL::isa($stash, 'HASH')
	  ? (defined $var
	     #TODO0610c
	     # {..., 'cn-DomainIdentity' => 'cs-domain', ...} sends 'cs-domain', 'cn-DomainIdentity'
	     # instead of stash ... 'cn-DomainIdentity', var = 'cs-domain'
	     ? ($stash->{$var} || $stash, $var)
	     : ($stash, undef))
	  : ($stash->[$idx], $idx))
       : ($stash, undef) # here more or less the final encoding IMPLICIT encoding.
       # I think also $var is not defined., and the {TAG}{VAR} could be UNIVERSAL
       , $buf
       , $path
    );
    pop @$path if(defined($var));
  };
}


sub boolean {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $path
  $_[4] .= pack("CC",1, $_[2] ? 0xff : 0);
}



sub enum {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $path
  my($s, $op, $stash, $var, $buf) = @_;
  # it is an enumaration
  my $ops = $op->{CHILD} || $op->{OPE}{CHILD} || [];
  unless(ref($ops) eq 'ARRAY') {
    $ops = [ $ops ];
  }
  # check var is an integer or string...in array of tokens...
  if(ref $var) {
    # yo problemo
    warn __PACKAGE__ . "::enum ERROR operation on ". Dumper($var) . "  shall be a scalar...";
    # anyway rectifying with something!
    if(ref($var) eq 'ARRAY') {
      $var = $var->[0];
    } elsif(ref($var) eq 'HASH') {
      $var = (values(%$stash))[0]->[0];
    }
  } else {
    if($op->{VAR} eq $var) {#need to change?!
      # in fact it has been sent ...,stash{var}, var,...
      $var = $stash;
    }
  }
  # succession of strings or HASHs
  my $min = 2**32;
  my $enum = 0;
  foreach my $op_c (@$ops) {
    if(ref($op_c)) {
      # really here CHILD shall be an integer.
      $enum = $op_c->{CHILD};
      if($var eq $op_c->{VAR}) {
	$var = $enum;
	last;
      } elsif($var == $enum) {
	last;
      }
    } else {
      if($var eq $op_c) {
	$var = $enum;
	last;
      }
    }
    if($min > $enum) {
      $min = $enum;
    }
    $enum++;
  }
  if($min > $enum) {
    $min = $enum;
  }
  # be gentle, crop...
  unless(ref($var) or ($var == $enum)) {
    $var = $min;
  }
  if($var > $enum) {
    $var = $enum;
  } elsif($var < $min) {
    $var = $min;
  }
  integer($s, $op, undef, $var, $buf, undef);
  # or bits...?
}


sub integer {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $stash, $buf, $path
  my ($s, $op, $stash,  $buf) = @_[0,1,2,4];
  # check for constraints...
  $stash = $op->constrain($stash);
  my ($os, $len);
  if(abs($stash) >= 2**31) {
    $os = i2osp($stash, ref($stash) || $s->{encode_bigint});
    $len = length $os;
    my $msb = (vec($os, 0, 8) & 0x80) ? 0 : 255;
    $len++, $os = chr($msb) . $os if $msb xor $stash > 0;
  } else {
    my $val = int($stash);
    my $neg = ($val < 0);
    $len = num_length($neg ? ~$val : $val);
    my $msb = $val & (0x80 << (($len - 1) * 8));
    $len++ if($neg ? !$msb : $msb);
    $os = substr(pack("N", $val), -$len);
  }
  ${$buf} .= asn_encode_length($len) . $os;
}


sub bitstring {
# 0      1    2       3     4     5      6
# $optn, $op, $stash, $var, $buf, $loop, $path
  #my $s = $_[0];
  #my $op = $_[1];
  my $stash = $_[2];
  #my $var = $_[3];
  my $buf = $_[4];
  #my $path = $_[5];
  my $vref = ref($stash) ? \($stash->[0]) : \$stash;
  if (CHECK_UTF8 and Encode::is_utf8($$vref)) {
    utf8::encode(my $tmp = $$vref);
    $vref = \$tmp;
  }
  if(ref($stash)) {
    my $less = (8 - ($stash->[1] & 7)) & 7;
    my $len = ($stash->[1] + 7) >> 3;
    ${$buf} .= asn_encode_length(1+$len)
      . chr($less)
	. substr($$vref, 0, $len);
    if ($less && $len) {
      substr(${$buf}, -1) &= chr((0xff << $less) & 0xff);
    }
  }
  else {
    ${$buf} .= asn_encode_length(1+length $$vref)
      . chr(0) . $$vref;
  }
}


sub string {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $stash, $buf, $loop, $path
  my ($op, $stash, $buf)  = @_[1,2,4];
  if(CHECK_UTF8 and Encode::is_utf8($stash)) {
    utf8::encode($stash);
  }
  # check for constraints...
  my $l = $op->constrain(length $stash);
  $stash = substr($stash . "\0" x $l, 0, $l);
  ${$buf} .= asn_encode_length($l) . $stash;
}


sub null {
# 0      1    2       3     4     5      6
# $optn, $op, $stash, $var, $buf, $loop, $path
  my $buf = $_[4];
  ${$buf} .= chr(0);
}


sub object_id {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $loop, $path
  #my $s = $_[0];
  my $op = $_[1];
  my $stash = $_[2];
  #my $var = $_[3];
  my $buf = $_[4];
  #my $path = $_[5];

  my @data = ($stash =~ /(\d+)/g);
  if ($op->{TYPE} eq 'OBJECTIDENTIFIER' ) {
    if(@data < 2) {
      @data = (0);
    } else {
      my $first = $data[1] + ($data[0] * 40);
      splice(@data,0,2,$first);
    }
  }
  my $l = length ${$buf};
  ${$buf} .= pack("cw*", 0, @data);
  substr(${$buf},$l,1) = asn_encode_length(length(${$buf}) - $l - 1);
}



sub real {
# 0      1    2       3     4     5      6
# $optn, $op, $stash, $var, $buf, $loop, $path
  my $s = $_[0];
  my $stash = $_[3];
  my $buf = $_[4];

  # Zero
  unless ($stash) {
    ${$buf} .= chr(0);
    return;
  }
  # +oo (well we use HUGE_VAL as Infinity is not avaliable to perl)
  if ($stash >= POSIX::HUGE_VAL()) {
    ${$buf} .= pack("C*",0x01,0x40);
    return;
  }
  # -oo (well we use HUGE_VAL as Infinity is not avaliable to perl)
  if ($stash <= - POSIX::HUGE_VAL()) {
    ${$buf} .= pack("C*",0x01,0x41);
    return;
  }
  if($s->{encode_real} ne 'binary') {
    my $tmp = sprintf("%g",$stash);
    ${$buf} .= asn_encode_length(1+length $tmp);
    ${$buf} .= chr(1); # NR1?
    ${$buf} .= $tmp;
    return;
  }
  # We have a real number.
  my $first = 0x80;
  my($mantissa, $exponent) = POSIX::frexp($stash);
  if ($mantissa < 0.0) {
    $mantissa = -$mantissa;
    $first |= 0x40;
  }
  my($eMant,$eExp);
  while($mantissa > 0.0) {
    ($mantissa, my $int) = POSIX::modf($mantissa * (1<<8));
    $eMant .= chr($int);
  }
  $exponent -= 8 * length $eMant;

  #todo: check this....
  integer(undef, undef, undef, $exponent, $eExp);

  # $eExp will br prefixed by a length byte
  
  if (5 > length $eExp) {
    $eExp =~ s/\A.//s;
    $first |= length($eExp)-1;
  } else {
    $first |= 0x3;
  }
  ${$buf}
    .= asn_encode_length(1 + length($eMant) + length($eExp))
      . chr($first) . $eExp . $eMant;
}

=pod sequence


=cut

sub sequence {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $loop, $path
  my ($s, $op, $stash, $var, $buf, $path) = @_;
  my $l = length ${$buf}; #pos in buffer to remember
  ${$buf} .= "\0\0"; # length coded in 16 bits ! (<64k)
  my $ops = $op->{CHILD};
  if($op->{TYPE} =~ /OF/) {#loop
    # which shall have been compiled into an array of operator...
    push @{$path}, -1;
    # $var shall be then an array... for a SEQUENCE or CHOICE
    (my @k)
      = ref $stash eq 'ARRAY'
	? @$stash
	  : values(%$stash);
    my $l = $op->constrain($#k + 1);
    foreach my $v (@k) {
      last unless($l--);
      $path->[-1]++;
      $s->encode($ops, $v, undef, $buf, $path);
    };
    while($l-- > 0) {
      $path->[-1]++;
      $s->encode($ops, $stash, undef, $buf, $path);
    }
    pop @{$path};
  } elsif(defined($ops)) {
    #ref $stash eq 'ARRAY' ? $stash->[$var] : $stash->{$var}
    $s->encode($ops
	       , $stash
	       , undef
	       , $buf
	       , $path);
  } else {# no childrens/loop  in sequence... this is what happens with an explicite tag + class number!, child is lost?!
    ${$buf} .= $var;
  }
  substr(${$buf}, $l, 2) = asn_encode_length(length(${$buf}) - $l - 2);
}


=pod set

unordered group of coding...

=cut

sub set {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $loop, $path
  my ($s, $op, $stash, $var, $buf, $path) = @_;
  my $l = length ${$buf};
  ${$buf} .= "\0\0"; # length coded in 16 bits ! (64k)
  my $ops = $op->{CHILD};
  if($op->{TYPE} =~ /OF/) {# loop
    # $var shall be then an array... for a SEQUENCE or CHOICE
    (my @k)
      = ref $stash eq 'ARRAY'
	? @$stash
	  : values(%$stash);
    my $l = $op->constrain($#k + 1);
    push @{$path}, -1;
    foreach my $v (@k) {
      last unless($l--);
      $path->[-1]++;
      $s->encode($ops, $v, undef, $buf, $path);
    };
    while($l-- > 0) {
      $path->[-1]++;
      $s->encode($ops, $stash, undef, $buf, $path);
    }
    pop @{$path};
  } elsif(defined($ops)) {
    $s->encode($ops
	       , $stash
	       , undef
	       , $buf
	       , $path);
  } else {# no childrens  in sequence...oops 
    ${$buf} .= $var;
  }
  #BER length encoding....
  substr(${$buf}, $l, 2) = asn_encode_length(length(${$buf}) - $l - 2);
}


my %time_opt = ( utctime => 1, withzone => 0, raw => 2);

sub time {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $loop, $path
  my $s = $_[0];
  my $op = $_[1];
  my $stash = $_[2];
  my $var = $_[3];
  my $buf = $_[4];
  #my $path = $_[5];

  my $mode = $time_opt{$s->{encode_time}};

  if($mode == 2) {
    ${$buf} .= asn_encode_length(length $stash) . $stash;
    return;
  }

  my @time;
  my $offset;
  my $time = $stash;
  my $isgen = $op->{OPE} == opGTIME;

  if(ref($stash)) {
    $offset = int($stash->[1] / 60);
    $time = $stash->[0] + $stash->[1];
  
  } elsif($mode == 0) {
    if($s->{encode_timezone}) {
      $offset = int($s->{encode_timezone} / 60);
      $time = $stash + $s->{encode_timezone};
    } else {
      @time = localtime($stash);
      my @g = gmtime($stash);
      $offset = ($time[1] - $g[1]) + ($time[2] - $g[2]) * 60;
      $time = $stash + $offset * 60;
    }
  }
  @time = gmtime($time);
  $time[4] += 1;
  $time[5] = $isgen ? ($time[5] + 1900) : ($time[5] % 100);

  my $tmp = sprintf("%02d"x6, @time[5,4,3,2,1,0]);
  if ($isgen) {
    my $sp = sprintf("%.03f",$time);
    $tmp .= substr($sp,-4) unless $sp =~ /\.000$/;
  }
  $tmp .= $offset ? sprintf("%+03d%02d", $offset / 60, abs($offset % 60)) : 'Z';
  ${$buf} .= asn_encode_length(length $tmp) . $tmp;
}


sub utf8 {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $loop, $path
  #my $s = $_[0];
  #my $op = $_[1];
  my $stash = $_[2];
  
  my $buf = $_[4];
  #my $path = $_[5];
  # I do think this $tmp and var are the same!
  #my $tmp = $var;
  if(CHECK_UTF8) {
    utf8::upgrade($stash) unless Encode::is_utf8($stash);
    utf8::encode($stash);
  }
  ${$buf} .= asn_encode_length(length $stash) . $stash;
}


sub any {
# 0      1    2       3     4     5      6
# $optn, $op, $stash, $var, $buf, $loop, $path
  my $s = $_[0];
  my $op = $_[1];
  my $stash = $_[2];
  my $var = $_[3];
  my $buf = $_[4];
  my $handler;
  ## bof bof define is an operator and OPT (or ATTR)
  ## leading to the defined VAR (or OPT?!)
  my $def = $op->{DEFINE};
  if ($def && $stash->{$def}) {
    $handler = $s->{oidtable}{$stash->{$def}};
  }
  if($handler) {
    # it assumes HANDLER has its own compiler???
    # and where is the size parameter???
    ${$buf} .= $handler->encode($stash);
  } else {
    ${$buf} .= $stash;
  }
}


sub choice {
  # 0      1    2       3     4     5      6
  # $optn, $op, $stash, $var, $buf, $loop, $path
  my $s = $_[0];
  my $op = $_[1];
  my $stash = $_[2];
  #my $var = $_[3];
  my $buf = $_[4];
  my $path = $_[5];
  for my $op_c (@{$op->{CHILD}}) {
    my $var = $op_c->{VAR} || $op_c->{CHILD}->[0]->{VAR};
    if(exists $stash->{$var}) {
      push @{$path}, $var;
      $s->encode($op_c, $stash->{$var}, $var, $buf, $path);
      pop @{$path};
      return;
    }
  }
  require Carp;
  Carp::croak("No value found for CHOICE " . join(".", @{$path}));
}


sub bcd {
# 0      1    2       3     4     5      6

# $optn, $op, $stash, $var, $buf, $loop, $path
  my $stash = $_[2];
  my $buf = $_[4];

  my $str = ("$stash" =~ /^(\d+)/) ? $1 : "";
  $str .= "F" if length($str) & 1;
  ${$buf} .= asn_encode_length(length($str) / 2)
   . pack("H*", $str);
}
1;
__END__
