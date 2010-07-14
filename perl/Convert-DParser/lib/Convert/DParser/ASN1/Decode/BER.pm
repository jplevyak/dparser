# Copyright (c) 2000-2005 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Convert::DParser::ASN1::Decode::BER;
use strict;
require POSIX;
use constant CHECK_UTF8 => $] > 5.007;
use Convert::DParser::ASN1 qw(:decode);

BEGIN {
  local $SIG{__DIE__};
  eval { require bytes and 'bytes'->import };
}

use Devel::Peek;
use Data::Dumper;

# BER decoding...
our @decode
  = (
     sub { die "internal error\n" }
     , \&boolean
     , \&integer
     , \&bitstring
     , \&bcd      #4 also octet string used to be string...
     , \&null
     , \&object_id
     , \&any      #7 ?ObjectDescriptor
     , undef      #8
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

     , \&string  #30 BMP
     , \&decode  #31 reserved...
    );


our @ctrs;
@ctrs[3, 4, 12] = (\&_ctr_bitstring,\&_ctr_string,\&_ctr_string);

sub decode {
  # 0   1    2       3     4     5     6     7
  # $s, $op, $stash, $pos, $end, $larr
  my $s     = shift;
  my $ops   = shift || $s->{script};
  my $stash = shift || $s->{stash};
  my $buf   = $s->{buf};
  my $pos   = shift || 0;
  my $pos_0 = $pos;
  my $end   = shift || length($$buf);
  my $larr  = shift || [];
  # get TAG in buffer
  my ($tag, $len, $npos, $indef) = _decode_tl($buf, $pos, $end, $larr)
    or do {
      warn  __PACKAGE__, "::decode in buffer TAG/LENGTH decode ERROR";
      return -1;
    };
  my $nend = $npos + $len + $indef;

  # niggles
  unless(ref($ops) eq 'ARRAY') {
    $ops = [ $ops ];
  }
  #match tag and OPS
  my $idx = -1;
  my $l = -1;
 OP:
  foreach my $op (@{$ops}) {
    $idx++;
    unless(ref $op) { # here the script is missing a reference...
      warn __PACKAGE__, "::decode ERROR: operator type <", $op, "> is not compiled";
      next OP;
    }
    my $v = $op->name || $op->type_explicit;
    my $optg = $op->{TAG}{BER};
    # get to any/choice...
    unless(defined $optg) {#TODO really
      if($op->operator == opANY) {
	  $len += $npos - $pos;
	  my $handler = ($s->{oidtable} && $op->{DEFINE}) ?
	    $s->{oidtable}{$stash->{$op->{DEFINE}}} : undef;
	  #($seqof ? $seqof->[$idx++] : ref($stash) eq 'SCALAR' ? $$stash : $stash->{$var})
	  #  = $handler ? $handler->decode(substr($$buf, $pos, $len)) : substr($$buf, $pos, $len);
	  $pos += $len + $indef;
	  #redo ANYLOOP if $seqof && $pos < $end;
	} else {
	  # its a choice...
	  # find which?
	}
      next OP;
    }
    # its a match operation on the way..
    if($tag eq $optg) {
      my $ope = $op->operator;
      if(($tag & chr(ASN_CONSTRUCTOR))
	 and my $ctr = $ctrs[$ope]) {# strings concatenation..
	$l = $s->decode($op, \(my @ctrlist), $npos, $nend, $indef ? $larr : undef);
	$$stash->{$v} = &{$ctr}(@ctrlist);

      } else {
	$l = &{$decode[$ope]}($s, $op, \(my $res), $npos, $nend, $indef ? $larr : undef);
	$$stash->{$v} = $res;
      }
      unless($l >= 0) {
	delete($$stash->{$v});
	next OP;
      }
      $pos = $npos + $l + $indef;
      unshift(@$larr, $len) if($indef); # doutfull it would work now...
      # problem with sequence.
      # more likely used in case of loops...
      #redo TAGLOOP if($seqof && $pos < $end);
      next OP;
    }
  }
  unless(($end >= $pos) && ($nend == $pos)) {
    warn __PACKAGE__, "::decode error ", "@", $pos;
    #. unpack("H*",$tag) ."<=>" . unpack("H*", $op->{TAG})
    #," ",$op->operator," ",$op->{VAR}
    return -1;
  }
  return $nend - $pos_0;
}


sub boolean {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $buf = $s->{buf};
  $$var = ord(substr($$buf, $pos, 1)) ? 1 : 0;
  1;
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
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  unless(ref($var) eq 'SCALAR') {
    warn __PACKAGE__, "::integer:: ERROR compilation error on "
      , $op->name
	, " type:", $op->{TYPE};
    #return $op->is_optional?0:-1;
  }
  $buf = substr($$buf, $pos, $len);
  my $tmp = ord($buf) & 0x80 ? chr(255) : chr(0);
  if($len > 4) {
      $tmp = os2ip($tmp x (4 - $len) . $buf, $s->{decode_bigint});
  } else {
      # N unpacks an unsigned value
      $tmp = unpack("l", pack("l", unpack("N", $tmp x (4-$len) . $buf)));
  }
  #check range
  $$var = $op->constrain($tmp);
  return $len;
}


sub bitstring {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  $$var = [substr($$buf, $pos + 1, $len - 1)
	   , ($len - 1) * 8 - ord(substr($$buf, $pos, 1))
	  ];
  return $len;
}


sub string {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  $$var = substr($$buf, $pos, $len);
  return $len;
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
  my ($s, $op, $stash, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $op_c = $op->{CHILD};
  my $v = $op->name || $op->type_explicit;
  my $of = ($op->type_explicit =~ /OF/);
  my $size = ($of ? $op->constrain($len) : $#$op_c);
  my $idx = 0;
  my $l = -1;
  while($pos < $end
	&& $#{$$stash} < $size) {
    my $cop = $op_c->[$idx];
    $l = $s->decode($cop, \(my $res), $pos, $end, $larr);
    if($l >= 0) {
      # it's good, stash it
      $pos += $l;
    } elsif($res = $cop->is_default) {
      #not this one is it optional or has it a default?
    } elsif($cop->is_optional) {#pass	
      $res = ();
    } else {
      #it is an error
      last; #return -1;
    }
    push(@{$$stash}, $res);
    if(++$idx > $#$op_c) {
      $idx = 0; #loop?
    }
  }
  # have we done it all?
  unless($end == $pos || (!$idx)) {#shall always end on idx = 0.
    warn __PACKAGE__, "::sequence:: decode error on ", $op->name
      , "[", $idx, "]"
      , " type:", $op->type_explicit, "stashed:", Dumper($stash);
    return -1;
  }
  return $len;
}

sub set {
  # 0      1    2       3     4     5     6     7
  # $optn, $op, $stash, $pos, $end, $larr
  my ($s, $op, $stash, $pos, $end, $larr) = @_;
  # decode SET OF the same as SEQUENCE OF
  my $len = $end - $pos;
  my $op_c = $op->{CHILD};
  my @op_c = @$op_c;
  my $of = ($op->type_explicit =~ /OF/);
  my $size = ($of ? $op->constrain($len) : $#$op_c);
  my $idx = $size;
  while($pos < $end && $idx >= 0) {
    my $cop = shift @op_c;
    my $l = $s->decode($cop, \(my $res), $pos, $end, $larr);
    if($l >= 0) {
      $idx = $#op_c;
      $pos += $l;
      my $v = $cop->name || $cop->type_explicit;
      $$stash->{$v} = $res;

    } else {#not this one
      $idx--;
      push @op_c, $op_c;
    }
    if(($of && ($idx < 0)) || ($pos == $end)) {
      # all of them shal be optional or have defaults...
      while(my $cop = shift @op_c) {
	if(my $res = $cop->is_default) {
	  #not this one is it optional or has it a default?
	  my $v = $cop->name || $cop->type_explicit;
	  $$stash->{$v} = $res;
	} elsif($cop->is_optional) {#pass
	} else {#error
	  warn __PACKAGE__, "::set decode error on ", $op->name
	    , " type:", $op->type_explicit;
	  undef $$stash;
	  return -1;
	}
      }
      #restart?
      $idx = $size;
      @op_c = @$op_c;
    }
  }
  # have we done it all?
  unless($end == $pos) {
    warn __PACKAGE__, "::set decode error on ", $op->name
      , " type:", $op->type_explicit;
    undef $$stash;
    return -1;
  }
  return $len;
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


sub _decode_tl {
  my($buf,$pos,$end,$larr) = @_[0,1,2,3];
  my $indef = 0;
  my $tag = substr($$buf, $pos++, 1);
  if((ord($tag) & 0x1f) == 0x1f) {
    my $b;
    my $n=1;
    do {
      $tag .= substr($$buf,$pos++,1);
      $b = ord substr($tag,-1);
    } while($b & 0x80);
  }
  return if $pos >= $end;
  my $len = ord substr($$buf,$pos++,1);
  if($len & 0x80) {
    $len &= 0x7f;
    if ($len) {
      return if $pos+$len > $end ;
      ($len,$pos) = (
		     unpack("N"
			    , "\0" x (4 - $len) . substr($$buf,$pos,$len)
			   )
		     , $pos + $len
		    );
    } else {
      unless (@$larr) {
        _scan_indef($buf,$pos,$end,$larr) or return;
      }
      $indef = 2;
      $len = shift @$larr;
    }
  }
  return if $pos+$len+$indef > $end;
  # return the tag, the length of the data, the position of the data
  # and the number of extra bytes for indefinate encoding
  return ($tag, $len, $pos, $indef);
}

sub _scan_indef {
  my($buf, $pos, $end, $larr) = @_[0,1,2,3];
  @$larr = ( $pos );
  my @depth = ( \$larr->[0] );
  while(@depth) {
    return if $pos+2 > $end;
    if(substr($$buf, $pos, 2) eq "\0\0") {
      my $end = $pos;
      my $stref = shift @depth;
      # replace pos with length = end - pos
      $$stref = $end - $$stref;
      $pos += 2;
      next;
    }
    my $tag = substr($$buf, $pos++, 1);
    if((ord($tag) & 0x1f) == 0x1f) {
      my $b;
      do {
	$tag .= substr($$buf, $pos++, 1);
	$b = ord substr($tag, -1);
      } while($b & 0x80);
    }
    return if $pos >= $end;
    my $len = ord substr($$buf,$pos++,1);
    if($len & 0x80) {
      if ($len &= 0x7f) {
	return if $pos+$len > $end ;
	$pos += $len + unpack("N", "\0" x (4 - $len) . substr($$buf, $pos, $len));
      } else {
        # reserve another list element
        push @$larr, $pos; 
        unshift @depth, \$larr->[-1];
      }
    } else {
      $pos += $len;
    }
  }
  1;
}

sub _ctr_string { join '', @_ }

sub _ctr_bitstring {
  [ join('', map { $_->[0] } @_), $_[-1]->[1] ]
}

sub bcd {
  # 0      1    2       3     4     5     6
  # $optn, $op, $stash, $var, $buf, $pos, $len
  my ($s, $op, $var, $pos, $end, $larr) = @_;
  my $len = $end - $pos;
  my $buf = $s->{buf};
  ($$var = unpack("H*", substr($$buf, $pos, $len))) =~ s/[fF]$//;
  1;
}
1;
__END__
