#!/usr/bin/perl -I t
# $File: //member/autrijus/Module-Signature/t/0-signature.t $ $Author: cmont $
# $Revision: 1.1.1.1 $ $Change: 1871 $ $DateTime: 2002/11/03 19:22:02 $


BEGIN {
    require tests;
}
END {
    done_testing(14 + 3);
}
use_ok('Convert::DParser::ASN1');

#
#
# the new test
$test =  'Convert::DParser::ASN1';
is(ref($a = Convert::DParser::ASN1->new), $test, $test)
  or diag("new() failed. all is desesperate", $test);

#
# check this simple preparation
#
my $desc=<<ESD
Constant-definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
hiPDSCHidentities                       INTEGER ::= 64
END
ESD
;
$test =  'Convert::DParser::ASN1::prepare';
$stest =  $test . ':: small  scalar description';
is(ref($a->prepare(\$desc)), 'Convert::DParser::ASN1', $stest);
is(ref($t = $a->{script}), 'Convert::DParser::ASN1', $stest);

$stest =  $test . ':: small description names ok';
is($t->name, 'Constant-definitions', $stest)
  or diag('here is the asn1 object::', Dumper($a));
is($t->{CHILD}[0]->name, 'hiPDSCHidentities', $stest)
  or diag('screewy tree::', Dumper($t));


TODO: {
$test =  'Convert::DParser::ASN1::verify';
#$a = Convert::DParser::ASN1->new->prepare(\$desc);
$test =  'Convert::DParser::ASN1::compile';

}


# test 21 comments
$desc=<<ESD
InformationElements DEFINITIONS AUTOMATIC TAGS ::=

-- ***************************************************
--
--     CORE NETWORK INFORMATION ELEMENTS (10.3.1)
--
-- *************************************************** -- double comment shall be ignored

BEGIN -- BEGIN it is a comment

CN-DomainIdentity ::=				ENUMERATED {
										cs-domain,
										ps-domain }

CN-DomainInformation ::=			SEQUENCE {
	cn-DomainIdentity					CN-DomainIdentity,
	cn-DomainSpecificNAS-Info			NAS-SystemInformationGSM-MAP
}
--
-- ...
--
Digit ::=							INTEGER (0..9)

IMEI ::=							SEQUENCE (SIZE (15)) OF
										IMEI-Digit

IMEI-Digit ::=						INTEGER (0..15)

--
-- ...
--

NAS-SystemInformationGSM-MAP ::= 	OCTET STRING (SIZE (1..8))


END

ESD
;

ok($a = Convert::DParser::ASN1->new
  (d_debug_level => 0
   , d_verbose_level => 0
   , description => $desc
   , initial_skip_space_fn => sub  {
     my $p = shift || die (__PACKAGE__ , "::my_white_space_fn::wehere is ppi?");
     my $loc = Parser::D::d_loc_t->new(shift, $p);
     my $g = shift || undef;
     my $s = ${$loc->{buf}};
     my $a = pos($s) = $loc->tell;
     $s =~ m/\G\s*/gcs;
     my (@comments) = $s =~ m/\G\s*(--.*)\s*/gcm;
     #
     # trigger token in globals?
     #
     $loc->seek(my $b = pos($s));
     if(@comments && defined $g) {
       push @{$g->{comments}}, @comments;
     }
   }
  )
  , $test);

#TODO comments are not yet linked to there modules etc...
is($#{$a->{comments}}, 10, $stest . '::found all comments');
is(${$a->{comments}}[0]
   , '-- ***************************************************'
   , $stest . ':: is this a good comment');

#
$test =  'Convert::DParser::ASN1::encode';
$stest =  $test . ':: my first encoding';
$stest = $test . "::encode of digit with range";
ok($r = $a->encode({Digit => 0b0110001}), $stest);
is(unpack("H*", ${$r->{buf}}), '830109', $stest)
  or diag("is to have... '020109' what is right to wrong?");

#
#test 19 ENUM
$stest = $test . " of Enumeration";
ok($r = $a->encode({'CN-DomainIdentity' => 'cs-domain' }), $stest);
is(unpack("H*", ${$r->{buf}}), '0a0100', $stest);
ok($r = $a->encode({'CN-DomainIdentity' => 'ps-domain' }), $stest);
is(unpack("H*", ${$r->{buf}}), '0a0101', $stest);

#test 20 SEQUENCE enumerator , and OCTET STRING (SIZE (1..8))
$stest = $test . " of SEQUENCE";
ok($r = $a->encode
   ({'CN-DomainInformation' =>
     {
      'cn-DomainIdentity' => 'ps-domain'  # also a number shall do? 0b1
      , 'cn-DomainSpecificNAS-Info' => 'hellohello'
     }
    }), $stest);
is(unpack("H*", ${$r->{buf}})
   , 'a205a101008200'
   #estimated '300a0a0101040568656c6c6f68656c'
   , $stest);

$test = 'Convert::DParser::ASN1::decode';
$stest = $test . " of SEQUENCE";
ok($r = $a->decode(pack("H*", '300a0a0101040568656c6c6f68656c')), $test);

is_deeply($r->{stash}
	  , {'InformationElements' =>
	     {'CN-DomainInformation' =>
	      {'cn-DomainSpecificNAS-Info' => 'hello'
	       , 'cn-DomainIdentity' => 'ps-domain'
	      }
	     }
	    }, $stest);




$stest = $test . " of SEQUENCE OF (LOOPs)";
ok($r = $a->decode(pack("H*", '302D0201000201010201020201040201'
. '05020106020107020108020109020100'
. '02010D02010F020100020100020100')), $test);

is_deeply($r->{stash}
	  , {
	     'InformationElements' => {
				       'IMEI' => [
						  0,
						  1,
						  2,
						  4,
						  5,
						  6,
						  7,
						  8,
						  9,
						  0,
						  13,
						  15,
						  0,
						  0,
						  0
						 ],
				       'CN-DomainInformation' => {}
				      }
	    }
	  , $stest);

$stest = $test . "encode of SEQUENCE OF (LOOPs) with range and size";
ok($r = $a->encode({'IMEI' => [ 0, 1, 2,4,5,6,7,8,9,0, 13, 100 ]}), $stest);
ok(unpack("H*", ${$r->{buf}}) eq '302d0201000201010201020201040201'
. '05020106020107020108020109020100'
. '02010d02010f020100020100020100', $stest);



$desc=<<ESD
Class-definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
DL-DCCH-Message ::= SEQUENCE {
	integrityCheckInfo		IntegrityCheckInfo		OPTIONAL,
	message					DL-DCCH-MessageType
}
END
ESD
;
$desc=<<ESD
Class-definitions DEFINITIONS AUTOMATIC TAGS ::=

BEGIN


IMPORTS


	ActiveSetUpdate,
	ActiveSetUpdateComplete,
	ActiveSetUpdateFailure,	
	AssistanceDataDelivery,
	CellChangeOrderFromUTRAN,
	CellChangeOrderFromUTRANFailure

FROM PDU-definitions

-- User Equipment IEs :
	IntegrityCheckInfo
FROM InformationElements;
	maxCNdomains,
	maxNoOfMeas,
	maxRB,
	maxSRBsetup
FROM Constant-definitions;

DL-DCCH-Message ::= SEQUENCE {
	integrityCheckInfo		IntegrityCheckInfo		OPTIONAL,
	message					DL-DCCH-MessageType
}
END

ESD
;


#OID test 0273
$test = 'Convert::DParser::ASN1::compile';
$stest = $test . " of OID";
$desc=<<ESD
ASN1-Object-Identifier-Module { oid asn1 }
DEFINITIONS ::= BEGIN
asn1 OBJECT IDENTIFIER ::= { joint-iso-itu-t asn1 }
numericString OBJECT IDENTIFIER ::= { joint-iso-itu-t asn1(1) specification(0) characterStrings(1) numericString(0) }
END
ESD
;
$a = Convert::DParser::ASN1->new
  (
   description => \$desc
  );
$t = $a->{script};
is($t->{VAR}{CHILD}[1]{VAR}, 'asn1', $stest);
is($t->{VAR}{CHILD}[1]{TYPE}, 'CHOICE', $stest);
is($t->{STASH}{asn1}{TYPE}, 'OBJECTIDENTIFIER', $stest);
#-- is the asn1 an OID type and also is asn1 OID arc ordered to 1  after all.
is($t->{STASH}{asn1}{CHILD}[1]{TAG}{ORDER}, 1, $stest);
is($t->{STASH}{numericString}{CHILD}[1], $t->{STASH}{asn1}{CHILD}[1], $stest);
is($t->{STASH}{OID}{CHILD}[0]{VAR}, 'oid', $stest);
is($t->{STASH}{OID}{CHILD}[1]{VAR}, 'joint-iso-itu-t', $stest);


#ROID test 0320
$stest = $test . " of ROID";
$desc=<<EOL
Example-Module DEFINITIONS ::= BEGIN
firstgroup RELATIVE-OID ::= {science-fac(4) maths-dept(3)}
END
EOL
;
$a = Convert::DParser::ASN1->new
  (
   description => \$desc
  );
$t = $a->{script};
$stest = $test . " of ROID links";
is($t->{STASH}{firstgroup}{CHILD}[-1]{'..'}{'..'}{VAR}, 'set', $stest);
$stest = $test . " of ROID tag";
is($t->{STASH}{firstgroup}{CHILD}[-1]{TAG}{CHILD}, 3, $stest);


#ROID test 0321
$stest = $test . " of ROID default OID taken into account";
$desc=<<EOL
Example-Module DEFINITIONS ::= BEGIN
thisUniversity OBJECT IDENTIFIER ::= {iso member-body country(29) universities(56) thisuni(32)}
firstgroup RELATIVE-OID ::= {science-fac(4) maths-dept(3)}
END
EOL
;
$a = Convert::DParser::ASN1->new
  (
   description => \$desc
  );
$t = $a->{script};
is($t->{STASH}{firstgroup}{CHILD}[-1]{'..'}{'..'}{VAR}, 'thisuni', $stest);

#ROID test 0322
$desc=<<EOL
Example-Module DEFINITIONS ::= BEGIN
thisUniversity OBJECT IDENTIFIER ::= {iso(1) member-body(2) country(29) universities(56) thisuni(32)}
firstgroup RELATIVE-OID ::= {science-fac(4) maths-dept(3)}
relOID RELATIVE-OID ::= {firstgroup room(4) socket(6)}
sameOID OBJECT IDENTIFIER ::=  {1 2 29 56 32 4 3 4 6}
END
EOL
;
$a = Convert::DParser::ASN1->new(description => \$desc);
$t = $a->{script};
$stest = $test . " of ROID first arc mapped possibly to a named type"
  . " and of OID number forms properly linked";
is($t->{STASH}{sameOID}{CHILD}[-1]{VAR}, 'socket', $stest);



#test-asn-class-000.pl
$stest = $test . ":: simple CLASS definition";
$desc=<<EOL
ObjectClass-definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN OPERATION ::= CLASS {&code INTEGER UNIQUE} END
EOL
;
$a = Convert::DParser::ASN1->new(description => \$desc);
$t = $a->{script};
is($t->{STASH}{OPERATION}{TYPE}, 'CLASS', $stest);
is($t->{STASH}{'&code'}{OPT}[0], 'UNIQUE', $stest);



#test-asn-class-001.pl
$stest = $test . ":: CLASS definition composite";
$desc=<<EOL
ObjectClass-definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
OPERATION ::= CLASS {
&ArgumentType OPTIONAL,
&Errors ERROR OPTIONAL,
&Linked OPERATION OPTIONAL,
&resultReturned BOOLEAN DEFAULT TRUE,
&code INTEGER UNIQUE
}
END
EOL
;
$a = Convert::DParser::ASN1->new(description => \$desc);
$t = $a->{script};
is($t->{STASH}{'&Linked'}{TYPE}, $t->{STASH}{OPERATION}, $stest);
is($t->{STASH}{'&resultReturned'}{OPT}[-1]{CHILD}, 'TRUE', $stest);
ok(!defined($t->{STASH}{'&ArgumentType'}{TYPE}), $stest);

#test-asn-class-002.pl
$stest = $test . "::CLASS definition with syntax";
$desc=<<EOL
ObjectClass-definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN OPERATION ::= CLASS {&ArgumentType OPTIONAL} WITH SYNTAX
{[ARGUMENT &ArgumentType]} END
EOL
;
$a = Convert::DParser::ASN1->new(description => \$desc);
$t = $a->{script};



#test 24
$desc=<<ESD
Constant-definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
IntegrityProtectionStatus ::=		ENUMERATED {
										started, notStarted }
InterRATHandoverInfoWithInterRATCapabilities ::= CHOICE {
	r3								SEQUENCE {
		-- IE InterRATHandoverInfoWithInterRATCapabilities-r3-IEs also
		-- includes non critical extensions
		interRAThandoverInfo-r3			InterRATHandoverInfoWithInterRATCapabilities-r3-IEs,
		v390NonCriticalExtensions			SEQUENCE {
			interRATHandoverInfoWithInterRATCapabilities-v390ext			InterRATHandoverInfoWithInterRATCapabilities-v390ext-IEs,
			-- Reserved for future non critical extension
			nonCriticalExtensions			SEQUENCE {}	OPTIONAL
		}		OPTIONAL
	},
	criticalExtensions				SEQUENCE {}
}

NAS-SystemInformationANSI-41 ::=		ANSI-41-NAS-Parameter

END
ESD
;



$desc=<<ESD
Constant-definitions DEFINITIONS AUTOMATIC TAGS ::=

BEGIN

hiPDSCHidentities                       INTEGER ::= 64
hiPUSCHidentities			INTEGER ::= 64
hiRM					INTEGER	::= 256
maxAC					INTEGER ::= 16
maxAdditionalMeas			INTEGER	::= 4
maxASC					INTEGER ::= 8
maxASCmap				INTEGER ::= 7
maxASCpersist				INTEGER ::= 6
maxCCTrCH				INTEGER	::= 8
maxCellMeas				INTEGER	::= 32
maxCellMeas-1				INTEGER ::= 31
maxCNdomains				INTEGER	::= 4

END




Class-definitions DEFINITIONS AUTOMATIC TAGS ::=

BEGIN

IMPORTS

	ActiveSetUpdate,
	ActiveSetUpdateComplete,
	ActiveSetUpdateFailure,	
	AssistanceDataDelivery,
	CellChangeOrderFromUTRAN,
	CellChangeOrderFromUTRANFailure

FROM PDU-definitions

-- User Equipment IEs :
	IntegrityCheckInfo
FROM InformationElements;


--**************************************************************
--
-- Downlink DCCH messages
--
--**************************************************************

DL-DCCH-Message ::= SEQUENCE {
	integrityCheckInfo		IntegrityCheckInfo		OPTIONAL,
	message					DL-DCCH-MessageType
}

DL-DCCH-MessageType ::= CHOICE {
	activeSetUpdate						ActiveSetUpdate,
	assistanceDataDelivery				AssistanceDataDelivery,
	cellChangeOrderFromUTRAN			CellChangeOrderFromUTRAN,
	cellUpdateConfirm					CellUpdateConfirm,
	counterCheck						CounterCheck,
	downlinkDirectTransfer				DownlinkDirectTransfer,
	handoverFromUTRANCommand-GSM		HandoverFromUTRANCommand-GSM,
	handoverFromUTRANCommand-CDMA2000	HandoverFromUTRANCommand-CDMA2000,
	measurementControl					MeasurementControl,
	pagingType2							PagingType2,
	physicalChannelReconfiguration		PhysicalChannelReconfiguration,
	physicalSharedChannelAllocation		PhysicalSharedChannelAllocation,
	radioBearerReconfiguration			RadioBearerReconfiguration,
	radioBearerRelease					RadioBearerRelease,
	radioBearerSetup					RadioBearerSetup,
	rrcConnectionRelease				RRCConnectionRelease,
	securityModeCommand					SecurityModeCommand,
	signallingConnectionRelease			SignallingConnectionRelease,
	transportChannelReconfiguration		TransportChannelReconfiguration,
	transportFormatCombinationControl	TransportFormatCombinationControl,
	ueCapabilityEnquiry					UECapabilityEnquiry,
	ueCapabilityInformationConfirm		UECapabilityInformationConfirm,
	uplinkPhysicalChannelControl		UplinkPhysicalChannelControl,
	uraUpdateConfirm					URAUpdateConfirm,
	utranMobilityInformation			UTRANMobilityInformation,
	spare7								NULL,
	spare6								NULL,
	spare5								NULL,
	spare4								NULL,
	spare3								NULL,
	spare2								NULL,
	spare1								NULL
}

--**************************************************************
--
-- Uplink DCCH messages
--
--**************************************************************

UL-DCCH-Message ::= SEQUENCE {
	integrityCheckInfo		IntegrityCheckInfo		OPTIONAL,
	message					UL-DCCH-MessageType
}

--**************************************************************
--
-- BCCH messages sent on BCH
--
--**************************************************************

BCCH-BCH-Message ::= SEQUENCE {
	message				SystemInformation-BCH
}

END



InformationElements DEFINITIONS AUTOMATIC TAGS ::=

-- ***************************************************
--
--     CORE NETWORK INFORMATION ELEMENTS (10.3.1)
--
-- ***************************************************

BEGIN

IMPORTS

	hiPDSCHidentities,
	hiPUSCHidentities,
	hiRM,
	maxTS-1,
	maxURA
FROM Constant-definitions;

Ansi-41-IDNNS ::=							BIT STRING (SIZE (14))

CN-DomainIdentity ::=				ENUMERATED {
										cs-domain,
										ps-domain }


Digit ::=							INTEGER (0..9)

Gsm-map-IDNNS ::=							SEQUENCE {
	routingbasis									CHOICE {
		localPTMSI										SEQUENCE {
			routingparameter								RoutingParameter
		},
		tMSIofsamePLMN									SEQUENCE {
			routingparameter								RoutingParameter
		},
		tMSIofdifferentPLMN							SEQUENCE {
			routingparameter								RoutingParameter
		},
		iMSIresponsetopaging							SEQUENCE {
			routingparameter								RoutingParameter
		},
		iMSIcauseUEinitiatedEvent						SEQUENCE {
			routingparameter								RoutingParameter
		},
		iMEI											SEQUENCE {
			routingparameter								RoutingParameter
		},
		spare2											SEQUENCE {
			routingparameter								RoutingParameter
		},
		spare1											SEQUENCE {
			routingparameter								RoutingParameter
		}
	},
	enteredparameter									BOOLEAN
}

IMEI ::=							SEQUENCE (SIZE (15)) OF
										IMEI-Digit

IMEI-Digit ::=						INTEGER (0..15)

IMSI-GSM-MAP ::=					SEQUENCE (SIZE (6..21)) OF
										Digit


NAS-SystemInformationANSI-41 ::=		ANSI-41-NAS-Parameter
NID ::=									BIT STRING (SIZE (16))

P-REV ::=								BIT STRING (SIZE (8))

SID ::=									BIT STRING (SIZE (15))

END



Internode-definitions DEFINITIONS AUTOMATIC TAGS ::=

BEGIN

IMPORTS

	HandoverToUTRANCommand,
	MeasurementReport,
	PhysicalChannelReconfiguration,
	RadioBearerReconfiguration,
	RadioBearerRelease,
	RadioBearerSetup,
	RRC-FailureInfo,
	TransportChannelReconfiguration
FROM PDU-definitions
-- Core Network IEs :
	CN-DomainIdentity,
	CN-DomainInformationList,
	CN-DRX-CycleLengthCoefficient,
	NAS-SystemInformationGSM-MAP,
-- UTRAN Mobility IEs :
	CellIdentity,
	URA-Identity,
-- User Equipment IEs :
	C-RNTI,
	DL-PhysChCapabilityFDD-v380ext,
	FailureCauseWithProtErr,
	RRC-MessageSequenceNumber,
	STARTList,
	STARTSingle,
	START-Value,
	U-RNTI,
	UE-RadioAccessCapability,
	UE-RadioAccessCapability-v370ext,
	UE-RadioAccessCapability-v380ext,
	UE-RadioAccessCapability-v3a0ext,
	UESpecificBehaviourInformation1interRAT,
	UESpecificBehaviourInformation1idle,
-- Radio Bearer IEs :
	PredefinedConfigStatusList,
	PredefinedConfigValueTag,
	RAB-InformationSetupList,
	RB-Identity,
	SRB-InformationSetupList,
-- Transport Channel IEs :
	CPCH-SetID,
	DL-CommonTransChInfo,
	DL-AddReconfTransChInfoList,
	DRAC-StaticInformationList,
	UL-CommonTransChInfo,
	UL-AddReconfTransChInfoList,
-- Measurement IEs :
	MeasurementIdentity,
	MeasurementReportingMode,
	MeasurementType,
	AdditionalMeasurementID-List,
	PositionEstimate,
-- Other IEs :
	InterRAT-UE-RadioAccessCapabilityList
FROM InformationElements

	maxCNdomains,
	maxNoOfMeas,
	maxRB,
	maxSRBsetup
FROM Constant-definitions;


-- Part 1: Class definitions similar to what has been defined in 11.1 for RRC messages
-- Information that is tranferred in the same direction and across the same path is grouped

-- ***************************************************
--
-- RRC information, to target RNC
--
-- ***************************************************
-- RRC Information to target RNC sent either from source RNC or from another RAT

ToTargetRNC-Container ::= CHOICE {
	interRAThandover					InterRATHandoverInfoWithInterRATCapabilities,
	srncRelocation						SRNC-RelocationInfo,
	extension							NULL
}

-- ***************************************************
--
-- RRC information, target RNC to source RNC
--
-- ***************************************************


TargetRNC-ToSourceRNC-Container::= CHOICE {
	radioBearerSetup					RadioBearerSetup,
	radioBearerReconfiguration			RadioBearerReconfiguration,
	radioBearerRelease					RadioBearerRelease,
	transportChannelReconfiguration		TransportChannelReconfiguration,
	physicalChannelReconfiguration		PhysicalChannelReconfiguration,
	rrc-FailureInfo						RRC-FailureInfo,
	-- IE dl-DCCHmessage consists of an octet string that includes
	-- the IE DL-DCCH-Message
	dL-DCCHmessage						OCTET STRING,
	extension							NULL
}

-- Part2: Container definitions, similar to the PDU definitions in 11.2 for RRC messages
-- In alphabetical order


-- ***************************************************
--
-- Handover to UTRAN information
--
-- ***************************************************

InterRATHandoverInfoWithInterRATCapabilities ::= CHOICE {
	r3								SEQUENCE {
		-- IE InterRATHandoverInfoWithInterRATCapabilities-r3-IEs also
		-- includes non critical extensions
		interRAThandoverInfo-r3			InterRATHandoverInfoWithInterRATCapabilities-r3-IEs,
		v390NonCriticalExtensions			SEQUENCE {
			interRATHandoverInfoWithInterRATCapabilities-v390ext			InterRATHandoverInfoWithInterRATCapabilities-v390ext-IEs,
			-- Reserved for future non critical extension
			nonCriticalExtensions			SEQUENCE {}	OPTIONAL
		}		OPTIONAL
	},
	criticalExtensions				SEQUENCE {}
}

InterRATHandoverInfoWithInterRATCapabilities-r3-IEs::=		SEQUENCE {
		-- The order of the IEs may not reflect the tabular format
		-- but has been chosen to simplify the handling of the information in the BSC
	--	Other IEs
		ue-RATSpecificCapability		InterRAT-UE-RadioAccessCapabilityList	OPTIONAL,
		-- interRATHandoverInfo, Octet string is used to obtain 8 bit length field prior to
		-- actual information.  This makes it possible for BSS to transparently handle information
		-- received via GSM air interface even when it includes non critical extensions.
		-- The octet string shall include the InterRATHandoverInfo information
		-- The BSS can re-use the 04.18 length field received from the MS
		interRATHandoverInfo			OCTET STRING (SIZE (0..255))
}

InterRATHandoverInfoWithInterRATCapabilities-v390ext-IEs ::= SEQUENCE {
	-- User equipment IEs
		failureCauseWithProtErr				FailureCauseWithProtErr					OPTIONAL
}

-- ***************************************************
--
-- SRNC Relocation information
--
-- ***************************************************

SRNC-RelocationInfo ::= CHOICE {
	r3								SEQUENCE {
		sRNC-RelocationInfo-r3			SRNC-RelocationInfo-r3-IEs,
		v380NonCriticalExtensions			SEQUENCE {
			sRNC-RelocationInfo-v380ext	SRNC-RelocationInfo-v380ext-IEs,
			-- Reserved for future non critical extension
			v390NonCriticalExtensions			SEQUENCE {
				sRNC-RelocationInfo-v390ext			SRNC-RelocationInfo-v390ext-IEs,
				v3a0NonCriticalExtensions			SEQUENCE {
					sRNC-RelocationInfo-v3a0ext			SRNC-RelocationInfo-v3a0ext-IEs,
					v3b0NonCriticalExtensions			SEQUENCE {
						sRNC-RelocationInfo-v3b0ext			SRNC-RelocationInfo-v3b0ext-IEs,
						v3c0NonCriticalExtensions			SEQUENCE {
							sRNC-RelocationInfo-v3c0ext			SRNC-RelocationInfo-v3c0ext-IEs,
							laterNonCriticalExtensions			SEQUENCE {
								sRNC-RelocationInfo-v3d0ext			SRNC-RelocationInfo-v3d0ext-IEs,
								-- Container for additional R99 extensions 
								sRNC-RelocationInfo-r3-add-ext		BIT STRING	OPTIONAL,
								-- Reserved for future non critical extension
								nonCriticalExtensions			SEQUENCE {}	OPTIONAL
							}		OPTIONAL
						}		OPTIONAL
					}		OPTIONAL
				}		OPTIONAL
			}		OPTIONAL
		}		OPTIONAL
	},
	criticalExtensions				SEQUENCE {}
}

SRNC-RelocationInfo-r3-IEs ::=				SEQUENCE {
	-- Non-RRC IEs
		stateOfRRC						StateOfRRC,
		stateOfRRC-Procedure			StateOfRRC-Procedure,
	-- Ciphering related information IEs
	-- If the extension v380 is included use the extension for the ciphering status per CN domain
		cipheringStatus					CipheringStatus,
		calculationTimeForCiphering		CalculationTimeForCiphering			OPTIONAL,
		-- The order of occurrence in the IE cipheringInfoPerRB-List is the
		-- same as the RBs in SRB-InformationSetupList in RAB-InformationSetupList.
		-- The signalling RBs are supposed to be listed
		-- first. Only UM and AM RBs that are ciphered are listed here
		cipheringInfoPerRB-List			CipheringInfoPerRB-List				OPTIONAL,
		count-C-List					COUNT-C-List						OPTIONAL,
		integrityProtectionStatus		IntegrityProtectionStatus,
     -- In the IE srb-SpecificIntegrityProtInfo, the first information listed corresponds to
     -- signalling radio bearer RB0 and after the order of occurrence is the same as the SRBs in
     -- SRB-InformationSetupList
		srb-SpecificIntegrityProtInfo	SRB-SpecificIntegrityProtInfoList,
		implementationSpecificParams	ImplementationSpecificParams		OPTIONAL,
	-- User equipment IEs
		u-RNTI							U-RNTI,
		c-RNTI							C-RNTI								OPTIONAL,
		ue-RadioAccessCapability		UE-RadioAccessCapability,
		ue-Positioning-LastKnownPos		UE-Positioning-LastKnownPos			OPTIONAL,
	-- Other IEs
		ue-RATSpecificCapability		InterRAT-UE-RadioAccessCapabilityList	OPTIONAL,
	-- UTRAN mobility IEs
		ura-Identity					URA-Identity						OPTIONAL,
	-- Core network IEs
		cn-CommonGSM-MAP-NAS-SysInfo	NAS-SystemInformationGSM-MAP,
		cn-DomainInformationList		CN-DomainInformationList			OPTIONAL,
	-- Measurement IEs
		ongoingMeasRepList				OngoingMeasRepList					OPTIONAL,
	-- Radio bearer IEs
		predefinedConfigStatusList		PredefinedConfigStatusList,
		srb-InformationList				SRB-InformationSetupList,
		rab-InformationList				RAB-InformationSetupList			OPTIONAL,
	-- Transport channel IEs
		ul-CommonTransChInfo			UL-CommonTransChInfo				OPTIONAL,
		ul-TransChInfoList				UL-AddReconfTransChInfoList			OPTIONAL,
		modeSpecificInfo				CHOICE {
			fdd								SEQUENCE {
				cpch-SetID						CPCH-SetID					OPTIONAL,
				transChDRAC-Info				DRAC-StaticInformationList	OPTIONAL
			},
			tdd								NULL
		},
		dl-CommonTransChInfo			DL-CommonTransChInfo				OPTIONAL,
		dl-TransChInfoList				DL-AddReconfTransChInfoList			OPTIONAL,
	-- Measurement report
		measurementReport				MeasurementReport					OPTIONAL
}

SRNC-RelocationInfo-v380ext-IEs ::= SEQUENCE {
	-- Ciphering related information IEs
		cn-DomainIdentity					CN-DomainIdentity,
		cipheringStatusList					CipheringStatusList
}

SRNC-RelocationInfo-v390ext-IEs ::= SEQUENCE {
		cn-DomainInformationList-v390ext	CN-DomainInformationList-v390ext		OPTIONAL,
		ue-RadioAccessCapability-v370ext	UE-RadioAccessCapability-v370ext		OPTIONAL,
		ue-RadioAccessCapability-v380ext	UE-RadioAccessCapability-v380ext		OPTIONAL,
		dl-PhysChCapabilityFDD-v380ext		DL-PhysChCapabilityFDD-v380ext,
		failureCauseWithProtErr				FailureCauseWithProtErr					OPTIONAL
}

SRNC-RelocationInfo-v3a0ext-IEs ::= SEQUENCE {
		cipheringInfoForSRB1-v3a0ext		CipheringInfoPerRB-List-v3a0ext,
		ue-RadioAccessCapability-v3a0ext	UE-RadioAccessCapability-v3a0ext		OPTIONAL,
		-- cn-domain identity for IE startValueForCiphering-v3a0ext is specified
		-- in subsequent extension (SRNC-RelocationInfo-v3b0ext-IEs)
		startValueForCiphering-v3a0ext		START-Value
}

SRNC-RelocationInfo-v3b0ext-IEs ::= SEQUENCE {
		-- cn-domain identity for IE startValueForCiphering-v3a0ext included in previous extension
		cn-DomainIdentity				CN-DomainIdentity,
		-- the IE startValueForCiphering-v3b0ext contains the start values for each CN Domain. The 
		-- value of start indicated by the IE startValueForCiphering-v3a0ext should be set to the
		-- same value as the start-Value for the corresponding cn-DomainIdentity in the IE 
		-- startValueForCiphering-v3b0ext
		startValueForCiphering-v3b0ext		STARTList2								OPTIONAL
}

SRNC-RelocationInfo-v3c0ext-IEs ::= SEQUENCE {
		-- IE rb-IdentityForHOMessage includes the identity of the RB used by the source SRNC
		-- to send the message contained in the IE "TargetRNC-ToSourceRNC-Container".
		-- Only included if type is "UE involved"
		rb-IdentityForHOMessage				RB-Identity  		OPTIONAL
}

SRNC-RelocationInfo-v3d0ext-IEs ::= SEQUENCE {
	-- User equipment IEs
		uESpecificBehaviourInformation1idle		UESpecificBehaviourInformation1idle		OPTIONAL,
		uESpecificBehaviourInformation1interRAT		UESpecificBehaviourInformation1interRAT		OPTIONAL
}

STARTList2 ::=						SEQUENCE (SIZE (2..maxCNdomains)) OF
										STARTSingle

CipheringInfoPerRB-List-v3a0ext ::= SEQUENCE {
		dl-UM-SN						BIT STRING (SIZE (7))
}

CipheringStatusList ::=				SEQUENCE (SIZE (1..maxCNdomains)) OF
										CipheringStatusCNdomain

CipheringStatusCNdomain ::=			SEQUENCE {
		cn-DomainIdentity				CN-DomainIdentity,
		cipheringStatus					CipheringStatus
}

-- IE definitions

CalculationTimeForCiphering ::=		SEQUENCE {
	cell-Id								CellIdentity,
	sfn									INTEGER (0..4095)
}

CipheringInfoPerRB ::=				SEQUENCE {
	dl-HFN								BIT STRING (SIZE (20..25)),
	ul-HFN								BIT STRING (SIZE (20..25))
}

-- TABULAR: CipheringInfoPerRB-List, multiplicity value numberOfRadioBearers
-- has been replaced with maxRB.
CipheringInfoPerRB-List ::=			SEQUENCE (SIZE (1..maxRB)) OF
										CipheringInfoPerRB

CipheringStatus ::=					ENUMERATED {
										started, notStarted }

CN-DomainInformation-v390ext ::=		SEQUENCE {
	cn-DRX-CycleLengthCoeff				CN-DRX-CycleLengthCoefficient
}

CN-DomainInformationList-v390ext ::=	SEQUENCE (SIZE (1..maxCNdomains)) OF
										CN-DomainInformation-v390ext

COUNT-C-List ::=						SEQUENCE (SIZE (1..maxCNdomains)) OF
										COUNT-CSingle

COUNT-CSingle ::=						SEQUENCE {
	cn-DomainIdentity					CN-DomainIdentity,
	count-C								BIT STRING (SIZE (32))			
}

ImplementationSpecificParams ::=	BIT STRING (SIZE (1..512))


IntegrityProtectionStatus ::=		ENUMERATED {
										started, notStarted }

MeasurementCommandWithType ::=		CHOICE {
	setup								MeasurementType,
	modify								NULL,
	release								NULL
}

OngoingMeasRep ::=					SEQUENCE {
	measurementIdentity			MeasurementIdentity,
	-- TABULAR: The CHOICE Measurement in the tabular description is included
	-- in MeasurementCommandWithType
	measurementCommandWithType			MeasurementCommandWithType,
	measurementReportingMode			MeasurementReportingMode			OPTIONAL,
	additionalMeasurementID-List		AdditionalMeasurementID-List		OPTIONAL
}

OngoingMeasRepList ::=				SEQUENCE (SIZE (1..maxNoOfMeas)) OF
										OngoingMeasRep

SRB-SpecificIntegrityProtInfo ::=	SEQUENCE {
	ul-RRC-HFN							BIT STRING (SIZE (28)),
	dl-RRC-HFN							BIT STRING (SIZE (28)),
	ul-RRC-SequenceNumber				RRC-MessageSequenceNumber,
	dl-RRC-SequenceNumber				RRC-MessageSequenceNumber
}

SRB-SpecificIntegrityProtInfoList ::= SEQUENCE (SIZE (4..maxSRBsetup)) OF
										SRB-SpecificIntegrityProtInfo

StateOfRRC ::=						ENUMERATED {
										cell-DCH, cell-FACH,
										cell-PCH, ura-PCH }

StateOfRRC-Procedure ::=			ENUMERATED {
										awaitNoRRC-Message,
										awaitRB-ReleaseComplete,
										awaitRB-SetupComplete,
										awaitRB-ReconfigurationComplete,
										awaitTransportCH-ReconfigurationComplete,
										awaitPhysicalCH-ReconfigurationComplete,
										awaitActiveSetUpdateComplete,
										awaitHandoverComplete,
										sendCellUpdateConfirm,
										sendUraUpdateConfirm,
										-- dummy is not used in this version of specification
										-- It should not be sent
										dummy,
										otherStates
}

UE-Positioning-LastKnownPos ::=		SEQUENCE {
		sfn								INTEGER (0..4095),
		cell-id							CellIdentity,
		positionEstimate				PositionEstimate
}

END


ESD
;


#test 25
=pod

{ 'InformationElements' => {
    'routingbasis' => {
      'localPTMSI' => {}
    },
    'IMEI' => \[
        \0,
        \1,
        \2,
        \4,
        \5,
        \6,
        \7,
        \8,
        \9,
        \0,
        \13,
        \15,
        \0,
        \0,
        \0
      ],
    'tMSIofsamePLMN' => \undef,
    'IMSI-GSM-MAP' => \[
        \0,
        \1,
        \2,
        \4,
        \5,
        \6,
        \7,
        \8,
        \9,
        \0,
        \9,
        \9,
        \0,
        \0,
        \0
      ],
    'localPTMSI' => \undef,
    'iMSIresponsetopaging' => \undef,
    'tMSIofdifferentPLMN' => \undef,
    'iMSIcauseUEinitiatedEvent' => \undef,
    'spare2' => \undef,
    'spare1' => \undef,
    'iMEI' => \undef
  },
  'Class-definitions' => {
    'BCCH-BCH-Message' => \undef,
    'DL-DCCH-Message' => \undef,
    'UL-DCCH-Message' => \undef
  },
  'Constant-definitions' => {},
  'Internode-definitions' => {
    'cipheringStatusList' => \' 	    ',
    'sRNC-RelocationInfo-v390ext' => \' 	    ',
    'sfn' => \0,
    'cn-DomainInformationList-v390ext' => \' 	    ',
    'nonCriticalExtensions' => \' 	    ',
    'startValueForCiphering-v3b0ext' => \' 	    ',
    'OngoingMeasRep' => \undef,
    'InterRATHandoverInfoWithInterRATCapabilities-v390ext-IEs' => \undef,
    'sRNC-RelocationInfo-v3b0ext' => \' 	    ',
    'CalculationTimeForCiphering' => \undef,
    'sRNC-RelocationInfo-v3a0ext' => \' 	    ',
    'interRATHandoverInfoWithInterRATCapabilities-v390ext' => \' 	    ',
    'CN-DomainInformation-v390ext' => \undef,
    'ue-Positioning-LastKnownPos' => \' 	    ',
    'sRNC-RelocationInfo-v3c0ext' => \' 	    ',
    'SRB-SpecificIntegrityProtInfoList' => \[],
    'OngoingMeasRepList' => \[],
    'STARTList2' => \[],
    'cipheringInfoForSRB1-v3a0ext' => \' 	    ',
    'CN-DomainInformationList-v390ext' => \[],
    'SRNC-RelocationInfo-v3d0ext-IEs' => \undef,
    'ongoingMeasRepList' => \' 	    ',
    'sRNC-RelocationInfo-v3d0ext' => \' 	    ',
    'CipheringInfoPerRB-List' => \[],
    'criticalExtensions' => \' 	    ',
    'srb-SpecificIntegrityProtInfo' => \' 	    ',
    'cipheringInfoPerRB-List' => \' 	    ',
    'modeSpecificInfo' => {
      'fdd' => {}
    },
    'interRAThandoverInfo-r3' => \' 	    ',
    'sRNC-RelocationInfo-v380ext' => \' 	    ',
    'sRNC-RelocationInfo-r3' => \' 	    ',
    'UE-Positioning-LastKnownPos' => \undef,
    'count-C-List' => \' 	    ',
    'COUNT-C-List' => \[],
    'fdd' => \undef,
    'SRNC-RelocationInfo-v3c0ext-IEs' => \undef,
    'CipheringStatusList' => \[],
    'calculationTimeForCiphering' => \' 	    '
  }
}
}










=pod test35 OCTECT STRING and SIZES with RANGES



my $desc=<<ESD

InformationElements DEFINITIONS AUTOMATIC TAGS ::=

BEGIN


NAS-SystemInformationGSM-MAP ::= 	OCTET STRING (SIZE (1..8))


END

ESD
;


my $r = $asn->encode({'NAS-SystemInformationGSM-MAP' => 'yoyoyiyixx'});

=pod test19 ENUMERATED

my $desc=<<ESD

InformationElements DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
CN-DomainIdentity ::=	ENUMERATED {
				cs-domain,
				ps-domain }
END
ESD
;

my $asn = Convert::DParser::ASN1->new
  (d_debug_level => 1
   , d_verbose_level => 1
   , description => $desc
  );
$r = $asn->encode({'CN-DomainIdentity' => 'ps-domain' });
print Dumper($r), hexdump(data => ${$r->{buf}}, end_position => 100);
$r = $asn->encode({'CN-DomainIdentity' => 'cs-domain' });


=cut


