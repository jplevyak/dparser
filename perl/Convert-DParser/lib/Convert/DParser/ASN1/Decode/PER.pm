# Copyright (c) 2000-2005 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=heads2

ASN1 . PER (unaligned) decoding.

=cut

package Convert::DParser::ASN1::Decode::PER;
use strict;
use Convert::DParser::ASN1 qw(:decode);
require POSIX;
use constant CHECK_UTF8 => $] > 5.007;

#BEGIN {
#  local $SIG{__DIE__};
#  eval { require bytes and 'bytes'->import };
#}
#use Bit::Vector;

use Bit::Vector::String;
use Devel::Peek;
use Data::Dumper;

# BER decoding...
our @decode
  = (
     sub {warn __PACKAGE__ . ":: internal ERROR\n";
	  return $_[3];
	 }
     , \&boolean
     , \&integer
     , \&bitstring
     , \&string   #4 also octet string used to be string...
     , \&null
     , \&object_id
     , \&any      #7 ?ObjectDescriptor oid
     , undef      #8 odescriptor
     , \&real     #9

     , \&enum     #10
     , undef      #11
     , \&utf8
     , undef      #13 relative_oid
     , undef      #14
     , undef      #15
     , \&sequence #16
     , \&set      #17 SET is the same encoding as sequence
     , \&string   #18 numeric_string, printable string
     , \&string   #19

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

     , \&string  #30 BMP
     , \&decode  #31 reserved... object identifier
     , \&choice  #32
    );

sub _get_binary {
  my ($buf, $pos, $size)  = @_;
  my $max_end = $buf->Size;
  my $rpos = $max_end - $pos - $size;
  if($rpos < 0) {
    if($max_end < $pos) {
      $pos = $max_end;
    }
    return _get_binary($buf, $pos, $max_end - $pos);
  }
  # always positive...
  my $sbv = Bit::Vector->new($size + 1);
  eval {
    $sbv->Interval_Copy($buf, 0, $rpos, $size)
  };
  return $sbv;

}


sub _get_binary_ord {
  return _get_binary(@_)->to_Dec;
}

sub _get_binary_string {
  my $v = _get_binary(@_);
  $v->Resize($_[2]);
  return $v->to_Bin;
}

=pod

    my $nposd = $npos >> 3;
    my $nposr = $npos & 0x000007;
    my $str = unpack('B*', substr($$buf, $nposd, ($size >> 3) + 1));
    return substr($str, $nposr, $size);

=cut



sub _length_determinant {
}

sub _decode_tl {
  my($op, $buf, $pos) = @_;
  #preamble
  my @preamble = ();
  # checks for size/options for components type set or sequence (9.1.2)
  if(defined(my $tag = $op->{GROUP_OPTIONAL})) {
    if((my $size = $#$tag + 1) > 0) {
      @preamble = split(//, _get_binary_string($buf, $pos, $size));
      $pos += $size;
    }
  }
  my @len = ();
  my $end = $buf->Size;
  if($end < $pos) {
    push(@len, ($pos, 0));
    return(\@preamble, \@len);
  }

  my $npos = $pos;
  #length
  # is it PER-visible?
  #my $l = $op->constrain($end - $pos);
  #  number of items
  # this is for...
  # (10.9)
  # bitstring,  octetstring, setof/sequenceof/, explicit string?
  my $size = 0;
  my $isize = defined($op->{LOG2SIZE}) ?  $op->{LOG2SIZE} : -1;
  if($isize < 0) {# it is a range and we need to decode it.
    while($pos < $end) {
      # do not know...put shall be present
      # then uses rules 10.9.3.4
      if(_get_binary_ord($buf, $pos, 1) == 0) {# some n < 64
	$size = _get_binary_ord($buf, $pos, 8);
	last;
      } else {# is it '10' or '11'....
	if(_get_binary_ord($buf, $pos + 1, 1) == 0) {# some n < 128
	  $size = _get_binary_ord($buf, $pos + 1, 7);
	  last;
	} else {#16K items and multiple lengths..
	  $size = _get_binary_ord($buf, $pos + 2, 6) << 14;
	  #shall be less than 4...anyhow
	  # really not sure about this...
	  $size = $op->convert_size_range($size);
	  if(defined(my $bsize = $op->{ITEMBITSIZE})) {
	    $size *= $bsize;
	  }
	  push @len, ($pos, $size);
	  $pos += $size + 8;
	  $size = 0;
	}
      }
    }
    $pos += 8;
    
  } elsif($isize == 0) {
    # fixed one size constrain shall be handled with LOG2SIZE = 0
    # no size! No not really,
    # it needs to be decoded by looking at the 2 first bits...
    # like
    $size = 1;
    
  } elsif($isize > 0 && $isize < 8) {
    # 10.3 non negative binary
    # I have the nasty feeling that it shall be encoded in 8 bits...anyway
    $size = _get_binary_ord($buf, $pos, $isize);
    $pos += $isize;

  } elsif($isize >= 8 && $isize < 16) {
    # there, the  length
    if(_get_binary_ord($buf, $pos, 1) == 0) {# some n < 128
      $size = _get_binary_ord($buf, $pos, 8);
      $pos += 8;
    } elsif(_get_binary_ord($buf, $pos, 2) == 0b10) {
      $size = _get_binary_ord($buf, $pos + 2, 14);	
      $pos += 14;
    } else {#'11' shall not have been coded like this according to 10.9.3.8
	# oops
      $size = _get_binary_ord($buf, $pos, $isize);
      $pos += $isize;
    }
    #
    #$size = pack("B*", _get_binary_string($buf, $pos, $isize));
    # defines if it is a else it is fixed and therefore well defined...PER-invisible?
    #
  }
  # size might have to be converted after range does not start from 0!
  #
  $size = $op->convert_size_range($size);
  if(defined(my $bsize = $op->{ITEMBITSIZE})) {
    $size *= $bsize;
  }
  push @len, ($pos, $size);

  # can it be translated into bit-length?
  # not is setof/sequenceof since these are component count.
  # then use $larr...?
  return(\@preamble, \@len);
}



# here pos and $end are bit-numbers....
sub decode {
  # 0   1    2       3     4     5     6     7
  # $s, $op, $stash, $pos, $end, $larr
  my $s     = shift;
  my $buf   = $s->{buf};
  my $end = undef;
  #
  # not that gooood... buffer needs to be converted...
  unless(ref($buf) eq 'Bit::Vector') {
    my $up = unpack('B*', $$buf);
    $end = length($up);
    my ($b, $tp) = Bit::Vector->new_String($end, $up);
    #   B*0000.0100.1000.0010.0100.1010   //b* 0010.0000.0100.0001.0101.0010   //h*B*->0100.0000.0010.1000.1010.0100
    #                                           -> '04824A'
    #000000000000000000000000.0000.0100.1000.0010.0100.1010
    #000001001000001001001010
    $buf = $s->{buf} = $b;
  }
  my $op = shift;
  unless(ref $op) { # here the script is missing a reference...
    warn __PACKAGE__, "::decode ERROR: operator type <", $op, "> is not compiled";
    return  -1;
  }
  my $stash = shift;
  my $pos   = shift || 0;
  my $pos_0 = $pos;
  $end      = shift || $end || $buf->Size;
  #
  # get TAG/LEN in buffer
  my($preamb, $lens) = _decode_tl($op, $buf, $pos);
  #round pairs/ npos.len
  my $nend  = $pos;
  while(@$lens) {
    #TODO: in fact this does not work yet with deconcatenation
    #      concatenation of multiple segments..., then decode the new vector?
    my $npos = shift @$lens;
    my $len  = shift @$lens;
    $nend = $npos + $len; #len is negative when item-bit size is not known.
    if($end < abs($nend)) {# no way! not enough bits to carry decoding
      $pos = abs($nend);
      last;
    }
    # stuff a bit vector...
    # get to any/choice...
    # its a match operation on the way..
    my $ope = $op->operator || 0;
    $pos = &{$decode[$ope]}($s, $op, \(my $res), $npos, $nend, $preamb);
    # problem with sequence.
    # more likely used in case of loops...
    if($pos <= $end) {
      my $v = $op->name || $op->type_explicit;
      $$stash->{$v} = $res;
    }
  }
  return $pos;
}


sub bitstring {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  if($len < 0 || $end > $buf->Size) {
    return $pos;
  }
  $$var = _get_binary_string($s->{buf}, $pos, $len);
  # might wnat to convert with named strings...
  return $end;
}

sub boolean {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end) = @_;
  my $buf = $s->{buf};
  if(($pos + 1 !=  $end) || $end > $buf->Size) {
    return $pos;
  }
  $$var = _get_binary_ord($s->{buf}, $pos, 1);
  return $end;
}


sub choice {
  my ($s, $op, $stash, $pos, $end) = @_;
  my $len = $end - $pos;
  if($end < $pos) {
    # oops
    return $pos;
  }
  my $op_c = $op->{CHILD};
  my $idx = _get_binary_ord($s->{buf}, $pos, $end - $pos);
  if($idx > $#$op_c) {
    warn __PACKAGE__, "::choice:: choice index too big on ", $op->name
      , "[", $idx, "]"
	, " type:", $op->type_explicit, "stashed:", Dumper($stash);
    #oops
    return $pos;
  }
  $pos = $end;
  my $res;
  my $cop = $op_c->[$idx];
  $end = $s->decode($cop, \$res, $pos);
  if($end >= $pos) {
    # it's good, stash it
    $pos = $end;
    push(@{$$stash}, $res);
  }
  return $pos;
}


sub enum {
  #my ($optn, $op, $stash, $var, $buf, $pos, $len, $larr) = @_;
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $buf = $s->{buf};
  my $l = integer(@_);
  # then  change into string if exists.
  # could be set at compile time.
  my $ops = $op->{CHILD} || $op->{OPE}{CHILD} || return;
  unless(ref($ops) eq 'ARRAY') {
    $ops = [ $ops ];
  }
  my $enum = 0;
  foreach my $op_c (@$ops) {
    if(ref($op_c)) {#this is eq 'Convert::DParser::ASN1'
      # really here CHILD shall be an integer.
      $enum = $op_c->{VAR};
      if($$var <= $enum) {
	$$var = $op_c->{CHILD};
	last;
      }
    } else { # OP_C is a scalar/string
      if($$var <= $enum) {
	$$var = $op_c;
	last;
      }
    }
    $enum++;
  }
  # be gentle, crop...not!
  return $l;
}



sub integer {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $end
  my ($s, $op, $var, $pos, $end) = @_;
  if($end < $pos) {
    return $pos;
  }
  my $tmp = _get_binary_ord($s->{buf}, $pos, $end - $pos);
  #check range and matching...
  $$var = $op->convert_range(undef, $tmp);
  return $end;
}



sub string {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  if($len < 0 || $end > $buf->Size) {
    return $pos;
  }
  # compose the string according to...
  my $bsize = $op->{ITEMBITSIZE} || 8;
  my $bv = Bit::Vector->new_Bin($len, _get_binary_string($buf, $pos, $len));
  $$var = join('', reverse map(chr, $bv->Chunk_List_Read($bsize)));
  return $end;
}


sub null {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $len, $larr) = @_;
  my $buf = $s->{buf};
  $$var = 0;
  #problemo! is -1 a better return for wrong len..?
  0;
}


sub object_id {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  my @data = unpack("w*",substr($$buf, $pos, $len));
  splice(@data,0,1,int($data[0]/40),$data[0] % 40)
    if(($op->operator == opOBJID) and (@data > 1));
  $$var = join(".", @data);
  return $len;
}


our @real_base = (2, 8, 16);

sub real {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  #my ($optn, $op, $stash, $var, $buf, $pos, $len) = @_;
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  $$var = 0.0, return -1 unless $len;
  my $first = ord(substr($$buf, $pos, 1));
  if($first & 0x80) {
    # A real number
    my $exp;
    my $expLen = $first & 0x3;
    my $estart = $pos + 1;
    if($expLen == 3) {
      $estart++;
      $expLen = ord(substr($$buf, $pos + 1, 1));
    } else {
      $expLen++;
    }
    $len = $s->integer($op, $exp, $estart, $expLen);
    my $mant = 0.0;
    for (reverse unpack("C*",substr($$buf, $estart + $expLen, $len - 1 - $expLen))) {
      $exp +=8, $mant = (($mant+$_) / 256) ;
    }
    $mant *= 1 << (($first >> 2) & 0x3);
    $mant = - $mant if $first & 0x40;
    $$var = $mant * POSIX::pow($real_base[($first >> 4) & 0x3], $exp);
    return $len;
  } elsif($first & 0x40) {
    $$var =   POSIX::HUGE_VAL(),return $len if $first == 0x40;
    $$var = - POSIX::HUGE_VAL(),return $len if $first == 0x41;
  } elsif(substr($$buf, $pos, $len) =~ /^.([-+]?)0*(\d+(?:\.\d+(?:[Ee][-+]?\d+)?)?)$/s) {
    $$var = eval "$1$2";
    return $len;
  }
  warn "REAL decode error\n";
  return -1;
}

sub sequence {
  # 0      1    2       3     4     5     6     7
  # $optn, $op, $stash, $pos, $end, $larr
  my ($s, $op, $stash, $pos, $end, $preambs) = @_;
  my $pos_0 = $end - $pos;
  if($pos_0 < 0) {
    # it is an itemised length: a size...
    $end = $s->{buf}->Size;
  }
  my $op_c = $op->{CHILD};
  my $v = $op->name || $op->type_explicit;
  my $of = ($op->type_explicit =~ /OF/);
  my $size = ($of ? abs($pos_0) - 1 : $#$op_c);
  $pos_0 = $pos;
  my $l = -1;
  my $idx = 0;
  my $ops = $op->{GROUP_OPTIONAL} || [];
  my $i_preambs = 0;
  my $cop_preambs = $$ops[$i_preambs] || '';

  while($pos <= $end
	&& $#{$$stash} < $size) {
    my $cop = $op_c->[$idx];
    my $res;
    #is it in optional?
    if($cop eq $cop_preambs) {
      if($preambs->[$i_preambs] eq '1') {#present
	$l = $s->decode($cop, \$res, $pos, $end);
      } else {
	$l = -1;
      }
      # turn to the next one
      if(++$i_preambs > $#$preambs) {
	$i_preambs = 0;
      }
      $cop_preambs = $$ops[$i_preambs];
    } else {# no options, but present
      # CHECK FOR ellipsis (extended marker...)
      # then a presence bit is nescessary...
      $l = $s->decode($cop, \$res, $pos, $end);
    }
    if($l >= $pos) {
      # it's good, stash it
      $pos = $l;
    } elsif($res = $cop->is_default) {
      #not this one is it optional or has it a default?

    } elsif($cop->is_optional) {#pass	
      $res = ();
    } else {
      #it is an error
      last;
    }
    push(@{$$stash}, $res);
    if(++$idx > $#$op_c) {
      $idx = 0; #loop?
    }
  }

=pod

  # have we done it all?
  unless(($pos <= $end) || (!$idx)) {#shall always end on idx = 0.
    warn __PACKAGE__, "::sequence:: decode error on ", $op->name
      , "[", $idx, "]"
      , " type:", $op->type_explicit, "stashed:", Dumper($stash);
  }

=cut

  return $pos;
}

sub set {
  # decode SET(OF) the same as SEQUENCE(OF) with a tag order
  return &sequence;
}

sub _stash_result {
  my $stash = shift;
  my $v = shift;
  my $res = shift;

  if(ref($res) eq 'HASH') {
    if(exists $res->{$v}) {
      $$stash = $res;
      return;
    }
  }
  $$stash->{$v} = $res;
  
}

my %time_opt = ( unixtime => 0, withzone => 1, raw => 2);

sub time {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  my $mode = $time_opt{$_[0]->{'decode_time'} || ''} || 0;
  if ($mode == 2 or $len == 0) {
    $$var = substr($$buf,$pos,$len);
    return;
  }
  my @bits = (substr($$buf,$pos,$len)
     =~ /^((?:\d\d)?\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)((?:\.\d{1,3})?)(([-+])(\d\d)(\d\d)|Z)/)
     or die "bad time format";
  if ($bits[0] < 100) {
    $bits[0] += 100 if $bits[0] < 50;
  } else {
    $bits[0] -= 1900;
  }
  $bits[1] -= 1;
  require Time::Local;
  my $time = Time::Local::timegm(@bits[5,4,3,2,1,0]);
  $time += $bits[6] if length $bits[6];
  my $offset = 0;
  if ($bits[7] ne 'Z') {
    $offset = $bits[9] * 3600 + $bits[10] * 60;
    $offset = -$offset if $bits[8] eq '-';
    $time -= $offset;
  }
  $$var = $mode ? [$time,$offset] : $time;
  return $len;
}


sub utf8 {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  BEGIN {
    unless (CHECK_UTF8) {
      local $SIG{__DIE__};
      eval { require bytes } and 'bytes'->unimport;
      eval { require utf8  } and 'utf8'->import;
    }
  }
  if (CHECK_UTF8) {
    $$var = Encode::decode('utf8', substr($$buf, $pos, $len));
  } else {
    $$var = (substr($$buf, $pos, $len) =~ /(.*)/s)[0];
  }
  return $len;
}

sub bcd {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  if($len < 0 || $end > $buf->Size) {
    return $pos;
  }
  ($$var = unpack("H*", substr($$buf, $pos, $len))) =~ s/[fF]$//;
  return $end;
}

1;

__END__
