
# needs to be after... those declararions?

=pod

/*CPM070925 I removed this condition ref($0)
 * ref(string) is null.
 * DefinitiveIdentifier is an OID
 * try to avoid     VAR => {
 *      VAR => AnyOddName,
 *      CHILD => {}
 *    },
 * defined($1) or ($1) alwasy true....
 * but not...if((ref($1) eq HASH) and %$1)
 * VAR null object is a string.
 * any composed is an HASH node.
 */

=cut

our $grammar =<<'_GRAM_'
{#!perl}
_ : {#!perl
 if($# == 0) {
    $$(defined($0) ? $0 : $n0->val || {});
 } elsif($# > 0) {
    #CPM071108 flattens array of one element
    $$(
       [grep(!/^[,\.]/
	    , map(
		  (defined($_->user)
		   ? ((ref($_->user) eq 'ARRAY')
		     && ($_->user->[-1] eq $_->user->[0])
                      ? $_->user->[-1]
                      : $_->user
                     )
		   : $_->val
		  ) || {}
	          , @{$_[1]}
	      )
        )]
       );
    warn('==no rule for children[#'. $# . ']' . Dumper($_[1], $$, $g));
 } else {
    warn('==no child['. $# . '] globals=' . Dumper($g));
 }
};

top : ModuleDefinition*;

/*
 * 12.1 A "ModuleDefinition" is specified by the following productions:
 */

ModuleDefinition :
ModuleIdentifier DEFINITIONS TagDefault ExtensionDefault "::=" BEGIN ModuleBody END
{ $$({CHILD => $6
   , TAG => $2
   , OPT  => [$3]
   , VAR  => $0
   , TYPE => $n1->val
  });
 $$->{TAG}{TYPE} = 'EXPLICITE' unless defined $$->{TAG}{TYPE};
}
;
ModuleIdentifier : modulereference DefinitiveIdentifier
{
 if((ref($1) eq 'HASH') and %{$1}) {
  $$({VAR => $0, CHILD => [$1]});
 } elsif((ref($1) eq 'ARRAY') and @{$1}) {
  $$({VAR => $0, CHILD => $1});
 } else	{
  $$($0);
 }
}
;
DefinitiveIdentifier :
'{' DefinitiveObjIdComponentList '}' {$$($1);}
| empty
;
DefinitiveObjIdComponentList :
DefinitiveObjIdComponent {$$([$0]);}
| DefinitiveObjIdComponent DefinitiveObjIdComponentList
{unshift(@{$$($1)}, $0);}
;
DefinitiveObjIdComponent :
NameForm
| DefinitiveNumberForm
| DefinitiveNameAndNumberForm
;
DefinitiveNumberForm : number
;
DefinitiveNameAndNumberForm :
identifier '(' DefinitiveNumberForm ')'
{$$({VAR => $0, OPT => [$2]});}
;

TagDefault :
EXPLICIT    TAGS {$$({TYPE => $n0->val});}
| IMPLICIT  TAGS {$$({TYPE => $n0->val});}
| AUTOMATIC TAGS {$$({TYPE => $n0->val});}
| empty
;
ExtensionDefault : EXTENSIBILITY IMPLIED | empty
;
ModuleBody : Exports Imports AssignmentList
{
 $$($2);
 push(@{$$}, $0) if(defined($0));
 push(@{$$}, $1) if(defined($1));
}
| empty
;
Exports : EXPORTS SymbolsExported ';'
| EXPORTS ALL ';'
| empty
;
SymbolsExported : SymbolList
| empty
;
Imports : IMPORTS SymbolsImported ';' {$$({TYPE => $n0->val, CHILD => $1});}
| empty
;
SymbolsImported : SymbolsFromModuleList
| empty
;
SymbolsFromModuleList : SymbolsFromModule {$$([$0]);}
| SymbolsFromModuleList SymbolsFromModule {push(@{$$($0)}, $1);}
;
SymbolsFromModule : SymbolList FROM GlobalModuleReference
{$$({CHILD => $0, TYPE => $n1->val, VAR => $2});}
;

//CPM0609a try removing var=>{var=> child=>} but not easy?
GlobalModuleReference : modulereference AssignedIdentifier
{if(%{$1}){$$({VAR => $0, OPT => $1})}
 else
{$$($0);}}
;
AssignedIdentifier : ObjectIdentifierValue
| DefinedValue
| empty
;
//CPM071008 we would need trying to stop constructions =>[ [] ]
SymbolList : Symbol {$$([$0]);}
| SymbolList ',' Symbol {push(@{$$($0)},$2);}
;
Symbol : Reference | ParameterizedReference
;
Reference :
typereference
| valuereference
| objectclassreference
| objectreference
| objectsetreference
;
AssignmentList :
Assignment {$$([$0]);}
| AssignmentList Assignment {push(@{$$($0)},$1);}
;
Assignment :
TypeAssignment
| ValueAssignment
| XMLValueAssignment
| ValueSetTypeAssignment
| ObjectClassAssignment
| ObjectAssignment
| ObjectSetAssignment
| ParameterizedAssignment
;


/*
 * 13 Referencing type and value definitions
 */

DefinedType :
ExternalTypeReference
| typereference
| ParameterizedType
| ParameterizedValueSetType
;
ExternalTypeReference :
modulereference '.' typereference
;
NonParameterizedTypeName :
ExternalTypeReference
| typereference
| xmlasn1typename
;
DefinedValue :
ExternalValueReference
| valuereference
| ParameterizedValue
;
ExternalValueReference :
modulereference '.' valuereference
;

/*
 * 14 Notation to support references to ASN.1 components
 */

AbsoluteReference :
'@' ModuleIdentifier '.' ItemSpec
;
ItemSpec :
typereference
| ItemId '.' ComponentId
;
ItemId : ItemSpec
;
ComponentId :
identifier | number | '*'
;


/*
 * 15 Assigning types and values
 */

TypeAssignment : typereference "::=" Type
{$$($2); $$->{VAR} = $0;}
;

ValueAssignment : valuereference Type "::=" Value
// cannot use $#{} as $# is interpreted as children number...
{
  if(%{$1}) {
   $$($1);
  } else {
   $$({TYPE => $1});
  }
  $$->{VAR} = $0;
  my $e = $3;
  if((ref($e) eq 'ARRAY')
     && (ref($e->[0]) eq 'ARRAY')
     && (!defined($e->[1]))
    )
    #&& ($#{$e} == 0)
    {
      $e = $e->[0];
      warn('-> reduced assignment' . Dumper($e));
    }
  $$->{CHILD} = $e;
}
;

XMLValueAssignment : valuereference "::=" XMLTypedValue
;
XMLTypedValue :
"<" NO_SPACE NonParameterizedTypeName ">"
XMLValue
"</" NO_SPACE NonParameterizedTypeName ">"
| "<" NO_SPACE NonParameterizedTypeName "/>"
;

ValueSetTypeAssignment : typereference Type "::=" ValueSet
;

ValueSet : '{' ElementSetSpecs '}'
;



/*
 * 16 Definition of types and values
 */

Type :
BuiltinType
| ReferencedType
| ConstrainedType
;
BuiltinType :
BitStringType
| BooleanType
| CharacterStringType
| ChoiceType
| EmbeddedPDVType
| EnumeratedType
| ExternalType
| InstanceOfType
| IntegerType
| NullType
| ObjectClassFieldType
| ObjectIdentifierType
| OctetStringType
| RealType
| RelativeOIDType
| SequenceType
| SequenceOfType
| SetType
| SetOfType
| TaggedType
;

NamedType : identifier Type
{
  if(%{$1}) {
   $$($1);
  } else {
    $$({TYPE => $1});
  }
  $$->{VAR} = $0;
};

ReferencedType :
DefinedType
| UsefulType
| SelectionType
| TypeFromObject
| ValueSetFromObjects
;
Value :
BuiltinValue
| ReferencedValue
| ObjectClassFieldValue
;
//CPM071011 Value , BuiltinValue is a real nightmare.
// too many "or"ed nodes, so it is likely to missinterpreted
// I have already found 3 infinite loops,
// then CharacterStringValue could match ObjectIdentifierValue,
// but the trace is not identical.
// { a b } is translated into by ... (only for case of 2 elements by the way!)
// ObjectIdentifierValue {CHILD} => [HASH{VAR=>a, CHILD} , HASH{VAR=>b, CHILD}]
// CharacterStringValue  {CHILD} => [HASH{VAR=>a, CHILD=>b}]
// oops! what is best we know... it has to be unified to "CharacterStringValue"
// it is corrected later in verify_oid?
BuiltinValue :
BitStringValue
| BooleanValue
| CharacterStringValue
| ChoiceValue
| EmbeddedPDVValue
| EnumeratedValue
| ExternalValue
| IntegerValue
| NullValue
| ObjectIdentifierValue
| OctetStringValue
| RealValue
| RelativeOIDValue
| SequenceValue
| SequenceOfValue
| SetValue
| SetOfValue
// loop Value <- TaggedValue/InstanceOfValue <- BuiltinValue <- Value
| TaggedValue
| InstanceOfValue
;
XMLValue : XMLBuiltinValue | XMLObjectClassFieldValue
;
XMLBuiltinValue :
XMLBitStringValue
| XMLBooleanValue
| XMLCharacterStringValue
| XMLChoiceValue
| XMLEmbeddedPDVValue
| XMLEnumeratedValue
| XMLExternalValue
| XMLInstanceOfValue
| XMLIntegerValue
| XMLNullValue
| XMLObjectIdentifierValue
| XMLOctetStringValue
| XMLRealValue
| XMLRelativeOIDValue
| XMLSequenceValue
| XMLSequenceOfValue
| XMLSetValue
| XMLSetOfValue
| XMLTaggedValue
;

ReferencedValue :
DefinedValue
| ValueFromObject
;

NamedValue : identifier Value
//CPM071008 may be? it must have some implications...to check
{$$({VAR => $0, CHILD => $1});}
;

XMLNamedValue :
"<" NO_SPACE identifier ">" XMLValue "</" NO_SPACE identifier ">"
;

/*17 Notation for the boolean type*/

BooleanType : BOOLEAN;

BooleanValue : TRUE | FALSE;

XMLBooleanValue :
"<" NO_SPACE "true" "/>"
| "<" NO_SPACE "false" "/>"
;



/*
 * 18 Notation for the integer type
 */
IntegerType : INTEGER
{$$({TYPE => $n0->val});}
| INTEGER '{' NamedNumberList '}'
{$$({TYPE => $n0->val, CHILD => $2});}
;
NamedNumberList : NamedNumber
| NamedNumberList ',' NamedNumber
;
NamedNumber : identifier '(' SignedNumber ')'
| identifier '(' DefinedValue ')'
;
SignedNumber : number
| '-' number {$$(-$1);}
;
IntegerValue
: SignedNumber
| identifier
;
XMLIntegerValue :
SignedNumber
| "<" NO_SPACE identifier "/>"
;


/*
 * 19 Notation for the enumerated type
 */
EnumeratedType : ENUMERATED '{' Enumerations '}'
{$$({TYPE => $n0->val, CHILD => $2});}
;
Enumerations : RootEnumeration
| RootEnumeration ',' '...' ExceptionSpec
| RootEnumeration ',' '...' ExceptionSpec ',' AdditionalEnumeration
;
RootEnumeration : Enumeration
;
AdditionalEnumeration : Enumeration
;
Enumeration : EnumerationItem {$$([$0]);} // used var=>$0 here
| EnumerationItem ',' Enumeration {unshift(@{$$($2)}, $0);}
;
EnumerationItem : identifier
| NamedNumber
;
EnumeratedValue : identifier
;
XMLEnumeratedValue : "<" NO_SPACE identifier "/>"
;


/*
 * 20 Notation for the real type
 */
RealType : REAL
;
RealValue : NumericRealValue | SpecialRealValue
;
NumericRealValue :
realnumber
| '-' realnumber
{$$(-$1);}
| SequenceValue
;
SpecialRealValue : PLUS_INFINITY | MINUS_INFINITY
;
XMLRealValue :
XMLNumericRealValue
| XMLSpecialRealValue
;
XMLNumericRealValue :
realnumber
| '-' realnumber
{$$(-$1);}
;
XMLSpecialRealValue :
"<" NO_SPACE PLUS_INFINITY "/>"
| "<" NO_SPACE MINUS_INFINITY "/>"
;

/*
 * 21 Notation for the bitstring type
 */

BitStringType : BIT STRING
{$$({TYPE => $n0->val . $n1->val});}
| BIT STRING '{' NamedBitList '}'
{
  $$({TYPE => $n0->val . $n1->val, OPT => $3});
}
;
NamedBitList : NamedBit {$$([$0]);}
| NamedBitList ',' NamedBit {push(@{$$($0)}, $2);}
;
NamedBit :
identifier '(' number ')'
{$$({TYPE => 'BIT', CHILD => $2, VAR => $0});}
| identifier '(' DefinedValue ')'
{$$({TYPE => 'BIT', CHILD => $2, VAR => $0});}
;
BitStringValue : bstring | hstring
| '{' IdentifierList '}' | '{' '}' | CONTAINING Value
;
IdentifierList : identifier {$$([$0]);}
| IdentifierList ',' identifier {push(@{$$($0)}, $2);}
;
XMLBitStringValue :
XMLTypedValue
| xmlbstring
| XMLIdentifierList
| empty
;

XMLIdentifierList :
"<" NO_SPACE identifier "/>"
| XMLIdentifierList "<" NO_SPACE identifier "/>"
;

/*
 * 22 Notation for the octetstring type
 */

OctetStringType : OCTET STRING
//CPM0610c well, I have to change all ...Type $$(val) into $$({TYPE=>val})
{$$({TYPE => $n0->val . $n1->val});}
;
OctetStringValue : bstring | hstring | CONTAINING Value
;
XMLOctetStringValue : XMLTypedValue | xmlhstring
;

/*
 * 23 Notation for the null type
 */
//CPM0609a changed again var/type=> to direct values...
NullType : NULL {$$({TYPE => $n0->val});}
;
NullValue : NULL {$$(0);}
;
XMLNullValue : empty
;

/*
 * 24 Notation for sequence types
 */
SequenceType : SEQUENCE '{' '}'
{$$({TYPE => $n0->val});}
| SEQUENCE '{' ExtensionAndException OptionalExtensionMarker '}'
{$$({TYPE => $n0->val, CHILD => [$2, $3]});}
| SEQUENCE '{' ComponentTypeLists '}'
{$$({TYPE => $n0->val, CHILD => $2});}
;
ExtensionAndException : '...' | '...' ExceptionSpec
;
OptionalExtensionMarker : ',' '...' | empty
;
ComponentTypeLists :
RootComponentTypeList
| RootComponentTypeList ',' ExtensionAndException ExtensionAdditions OptionalExtensionMarker
| RootComponentTypeList ',' ExtensionAndException ExtensionAdditions ExtensionEndMarker ',' RootComponentTypeList
| ExtensionAndException ExtensionAdditions ExtensionEndMarker ',' RootComponentTypeList
| ExtensionAndException ExtensionAdditions OptionalExtensionMarker
;
RootComponentTypeList : ComponentTypeList
;
ExtensionEndMarker : ',' '...'
;
ExtensionAdditions : ',' ExtensionAdditionList {$$($1);} | empty
;
ExtensionAdditionList : ExtensionAddition {$$([$0]);}
| ExtensionAdditionList ',' ExtensionAddition {push(@{$$($0)},$2);}
;
ExtensionAddition : ComponentType | ExtensionAdditionGroup
;
ExtensionAdditionGroup : "[[" VersionNumber ComponentTypeList "]]"
;
VersionNumber : empty | number ":"
;
ComponentTypeList : ComponentType {$$([$0]);}
| ComponentTypeList ',' ComponentType {push(@{$$($0)},$2);}
;
//CPM0609a avoiding var=>(var=> type=>)
ComponentType : NamedType
| NamedType OPTIONAL
{$$($0); push @{$$->{OPT}}, $n1->val;}
| NamedType DEFAULT Value
{
 if(defined($0->{VAR})) {
   $$($0);
 } else {
   $$({VAR => $0});
 }
 push(@{$$->{OPT}}, {TYPE => $n1->val, CHILD => $2});
 #warn "***stuff default:", Dumper($$);
}
| COMPONENTS OF Type
//CPM0609b here traded VAR to a CHILD... since Type is going to be "duplicated" over...
// its TAGS can be different from the parent type.
{$$({TYPE => $n0->val . $n1->val, CHILD => $2, VAR => $2});}
;
SequenceValue : '{' ComponentValueList '}'
{$$($1);}
| '{' '}'
{$$();}
;
ComponentValueList : NamedValue {$$([$0]);}
| ComponentValueList ',' NamedValue {push(@{$$($0)},$2);}
;
XMLSequenceValue :
XMLComponentValueList
| empty
;
XMLComponentValueList :
XMLNamedValue
| XMLComponentValueList XMLNamedValue
;
SequenceOfType : SEQUENCE OF Type
{$$({TYPE => $n0->val . $n1->val, CHILD => $2});}
| SEQUENCE OF NamedType
{$$({TYPE => $n0->val . $n1->val, CHILD => $2});}
;



/*
 * 25 Notation for sequence-of types
 */
SequenceOfValue : '{' ValueList '}'
{$$($1);}
| '{' NamedValueList '}'
{$$($1);}
| '{' '}'
{$$();}
;
ValueList : Value {$$([$0]);}
| ValueList ',' Value {push(@{$$($0)},$2);}
;
NamedValueList : NamedValue {$$([$0]);}
| NamedValueList ',' NamedValue {push(@{$$($0)},$2);}
;
XMLSequenceOfValue :
XMLValueList
| XMLDelimitedItemList
| XMLSpaceSeparatedList
| empty
;
XMLValueList :
XMLValueOrEmpty
| XMLValueOrEmpty XMLValueList
;
XMLValueOrEmpty :
XMLValue
| "<" NO_SPACE NonParameterizedTypeName "/>"
;
XMLSpaceSeparatedList :
XMLValueOrEmpty
| XMLValueOrEmpty " " XMLSpaceSeparatedList
;
XMLDelimitedItemList :
XMLDelimitedItem
| XMLDelimitedItem XMLDelimitedItemList
;
XMLDelimitedItem :
"<" NO_SPACE NonParameterizedTypeName ">" XMLValue
"</" NO_SPACE NonParameterizedTypeName ">"
| "<" NO_SPACE identifier ">" XMLValue "</" NO_SPACE identifier ">"
;


/*
 * 26 Notation for set types
 */

SetType : SET '{' '}'
{$$({TYPE => $n0->val});}
| SET '{' ExtensionAndException OptionalExtensionMarker '}'
{$$({TYPE => $n0->val, OPT => [$2, $3]});}
| SET '{' ComponentTypeLists '}'
{
 $$({TYPE => $n0->val, CHILD => $2});
}
;
SetValue : '{' ComponentValueList '}'
{$$($1);}
| '{' '}' //  "{" "}" is a real killer crasher......
{$$([]);}
;
XMLSetValue : XMLComponentValueList | empty
;


/*
 * 27 Notation for set-of types
 */

SetOfType : SET OF Type | SET OF NamedType
;
SetOfValue : '{' ValueList '}' | '{' NamedValueList '}' | '{' '}'
;
XMLSetOfValue :
XMLValueList
| XMLDelimitedItemList
| XMLSpaceSeparatedList
| empty
;



/*
 * 28 Notation for choice types
 */

ChoiceType : CHOICE '{' AlternativeTypeLists '}'
{$$({TYPE => $n0->val, CHILD => $2});}
;
AlternativeTypeLists : RootAlternativeTypeList
| RootAlternativeTypeList ',' ExtensionAndException ExtensionAdditionAlternatives OptionalExtensionMarker
{push(@{$$([])}, ($0, $2, $3, $4));}
;
RootAlternativeTypeList : AlternativeTypeList
;
ExtensionAdditionAlternatives : ',' ExtensionAdditionAlternativesList | empty
;
ExtensionAdditionAlternativesList : ExtensionAdditionAlternative
| ExtensionAdditionAlternativesList ',' ExtensionAdditionAlternative
;
ExtensionAdditionAlternative : ExtensionAdditionAlternativesGroup | NamedType
;
ExtensionAdditionAlternativesGroup : "[[" VersionNumber AlternativeTypeList "]]"
;
AlternativeTypeList :     NamedType {$$([$0]);}
| AlternativeTypeList ',' NamedType {push(@{$$($0)},$2);}
;
ChoiceValue : identifier ":" Value
;
XMLChoiceValue : "<" NO_SPACE identifier ">" XMLValue "</" NO_SPACE identifier ">"
;
SelectionType : identifier "<" Type
;


/*
 *  30 Notation for tagged types
 */

TaggedType : Tag Type
{if(%{$1}) {
   $$($1);
  } else {
    $$({TYPE => $1});
  }
  $$->{TAG} = $0;
}
| Tag IMPLICIT Type
{if(%{$2}) {
   $$($2);
  } else {
    $$({TYPE => $2});
  }
 $$->{TAG} = $0;
 $$->{TAG}{TYPE} = $n1->val;
}
| Tag EXPLICIT Type
{if(%{$2}) {
   $$($2);
  } else {
    $$({TYPE => $2});
  }
 $$->{TAG} = $0;
 $$->{TAG}{TYPE} = $n1->val;
}
;
Tag : '[' Class ClassNumber ']'
{
  $$({CHILD => $2});
  $$->{VAR} = $1 unless(ref($1));
}
;
ClassNumber : number | DefinedValue
;
Class : UNIVERSAL
| APPLICATION
| PRIVATE
| empty
;

TaggedValue ::= 'Value' $term -100;
//CPM0610a used to be Value
// but creates a loop... Value  BuiltinValue TaggedValue
// which stops the parser.
//TODO: need to work is that out there?

XMLTaggedValue : XMLValue
;


/*
 * 33 Notation for the embedded-pdv type
 */

EmbeddedPDVType : EMBEDDED PDV
;
EmbeddedPDVValue : SequenceValue
;
XMLEmbeddedPDVValue : XMLSequenceValue
;


/*
 * 34 Notation for the external type
 */

ExternalType : EXTERNAL
;
ExternalValue : SequenceValue
;
XMLExternalValue : XMLSequenceValue
;

/*
 * 31 Notation for the object identifier type
 */
ObjectIdentifierType : OBJECT IDENTIFIER
{$$($n0->val . $n1->val);}
;
ObjectIdentifierValue : '{' ObjIdComponentsList '}'
{$$($1);}
/*CPM070924 check this out... */
| '{' DefinedValue ObjIdComponentsList '}'
{$$({VAR => $1, CHILD => $2});}
;
ObjIdComponentsList : ObjIdComponents {$$([$0]);}
| ObjIdComponents ObjIdComponentsList {unshift(@{$$($1)}, $0);}
;
ObjIdComponents : NameForm
| NumberForm
| NameAndNumberForm
| DefinedValue
;
NameForm : identifier
;
/*31.4 The "valuereference" in "DefinedValue" of "NumberForm" shall be of type integer, and assigned a nonnegative value.*/
NumberForm : number | DefinedValue
;
NameAndNumberForm : identifier '(' NumberForm ')'
{$$({VAR => $0, OPT => [$2]});}
;
XMLObjectIdentifierValue :
XMLObjIdComponentList
;
XMLObjIdComponentList :
XMLObjIdComponent
| XMLObjIdComponent NO_SPACE '.' NO_SPACE XMLObjIdComponentList
;
XMLObjIdComponent :
NameForm
| XMLNumberForm
| XMLNameAndNumberForm
;
XMLNumberForm : number
;
XMLNameAndNumberForm :
identifier NO_SPACE '(' NO_SPACE XMLNumberForm NO_SPACE ')'
;


/*
 * 32 Notation for the relative object identifier type
 */
RelativeOIDType : RELATIVE_OID
;
RelativeOIDValue :
'{' RelativeOIDComponentsList '}' {$$($1);}
;
RelativeOIDComponentsList :
RelativeOIDComponents {$$([$0]);}
| RelativeOIDComponents RelativeOIDComponentsList
{unshift(@{$$($1)}, $0);}
;
RelativeOIDComponents : NumberForm
| NameAndNumberForm
| DefinedValue
;
XMLRelativeOIDValue :
XMLRelativeOIDComponentList
;
XMLRelativeOIDComponentList :
XMLRelativeOIDComponent
| XMLRelativeOIDComponent NO_SPACE '.' NO_SPACE XMLRelativeOIDComponentList
;
XMLRelativeOIDComponent :
XMLNumberForm
| XMLNameAndNumberForm
;


/*
 * 34 Notation for the external type
 */
CharacterStringType :
RestrictedCharacterStringType  {$$({TYPE => $n0->val});}
| UnrestrictedCharacterStringType
;



/*
 * 37 Definition of restricted character string types
 */
RestrictedCharacterStringType :
BMPString
| GeneralString
| GraphicString
| IA5String
| ISO646String
| NumericString
| PrintableString
| TeletexString
| T61String
| UniversalString
| UTF8String
| VideotexString
| VisibleString
;

RestrictedCharacterStringValue : cstring | CharacterStringList | Quadruple | Tuple
;
CharacterStringList : '{' CharSyms '}' {$$($1);}
;
CharSyms : CharsDefn | CharSyms ',' CharsDefn
;
CharsDefn : cstring | Quadruple | Tuple | DefinedValue
;
Quadruple : '{' Group ',' Plane ',' Row ',' Cell '}'
;
Group : number
;
Plane : number
;
Row : number
;
Cell : number
;
Tuple : '{' TableColumn ',' TableRow '}'
;
TableColumn : number
;
TableRow : number
;
XMLRestrictedCharacterStringValue : xmlcstring
;


/*40 Definition of unrestricted character string types*/


UnrestrictedCharacterStringType : CHARACTER STRING
;
CharacterStringValue : RestrictedCharacterStringValue | UnrestrictedCharacterStringValue
;
XMLCharacterStringValue :
XMLRestrictedCharacterStringValue
|XMLUnrestrictedCharacterStringValue
;
UnrestrictedCharacterStringValue : SequenceValue
;
XMLUnrestrictedCharacterStringValue : XMLSequenceValue
;
UsefulType : typereference
;
/*
The following character string types are defined in 37.1:
NumericString VisibleString
PrintableString ISO646String
TeletexString IA5String
T61String GraphicString
VideotexString GeneralString
UniversalString BMPString
The following useful types are defined in clauses 42 to 44:
GeneralizedTime
UTCTime
ObjectDescriptor
The following productions are used in clauses 45 to 47:
*/


/*42 Generalized time*/

GeneralizedTime : ('[' UNIVERSAL '24' ']')? IMPLICIT VisibleString;

/*43 Universal time*/

UTCTime : ('[' UNIVERSAL '23' ']')? IMPLICIT VisibleString;


/*
 * 45 Constrained types
 */

ConstrainedType : Type Constraint
//CPM0610 OPT is somewhat an array and could already be defined by Type.
//CPM071024 Constraint also could be a number (as in OID)
{
 if(ref($0)) {
  $$($0);
 } else {#this is a string
  $$({VAR => $0});
 }
 if(ref($1) eq 'ARRAY') {
   push(@{$$->{OPT}}, @{$1});
 } else {
   push(@{$$->{OPT}}, $1);
 }
 #warn("ConstrainedType::", $n->val, "::", Dumper($$));
}
| TypeWithConstraint
;

TypeWithConstraint :
SET Constraint OF Type
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SET SizeConstraint OF Type
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SEQUENCE Constraint OF Type
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SEQUENCE SizeConstraint OF Type
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SET Constraint OF NamedType
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SET SizeConstraint OF NamedType
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SEQUENCE Constraint OF NamedType
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
| SEQUENCE SizeConstraint OF NamedType
{$$({TYPE => $n0->val . $n2->val, OPT => $1, CHILD => $3});}
;

Constraint : '(' ConstraintSpec ExceptionSpec ')'
{$$([$1,$2]);}
;

ConstraintSpec : SubtypeConstraint
| GeneralConstraint
;
ExceptionSpec : '!' ExceptionIdentification | empty
;
ExceptionIdentification : SignedNumber
| DefinedValue
| Type ':' Value
;

SubtypeConstraint : ElementSetSpecs
;



/*
 * 46 Element set specification
 */

ElementSetSpecs :
RootElementSetSpec //{$$({VAR => $0});} removed because VAR shall not be arrays...?!
| RootElementSetSpec ',' '...'
| RootElementSetSpec ',' '...' ',' AdditionalElementSetSpec
;
RootElementSetSpec : ElementSetSpec
;
AdditionalElementSetSpec : ElementSetSpec
;
ElementSetSpec : Unions | ALL Exclusions
;
Unions : Intersections
| UElems UnionMark Intersections
;
UElems : Unions
;
Intersections : IntersectionElements
| IElems IntersectionMark IntersectionElements
;
IElems : Intersections
;
IntersectionElements : Elements | Elems Exclusions
;
Elems : Elements
;
Exclusions : EXCEPT Elements
;
UnionMark : '|' | UNION
;
IntersectionMark : '^' | INTERSECTION
;

Elements : SubtypeElements
| ObjectSetElements
| '(' ElementSetSpec ')'
;


/*
 * 47 Subtype elements
 */

SubtypeElements : SingleValue
| ContainedSubtype
| ValueRange
| PermittedAlphabet
| SizeConstraint
| TypeConstraint
| InnerTypeConstraints
| PatternConstraint
;
SingleValue : Value
;
ContainedSubtype : Includes Type
;
Includes : INCLUDES | empty
;
ValueRange : LowerEndpoint '..' UpperEndpoint
{
  $$({TYPE => 'RANGE', CHILD => [$0, $2]});
}
;
LowerEndpoint : LowerEndValue | LowerEndValue "<"
;
UpperEndpoint : UpperEndValue | "<" UpperEndValue
;
LowerEndValue : Value | MIN
;
UpperEndValue : Value | MAX
;
SizeConstraint : SIZE Constraint
//CPM0610 TODO here to change SIZE+RANGE into SIZERANGE?
{$$({TYPE => $n0->val, CHILD => $1});}
;
PermittedAlphabet : FROM Constraint
;
TypeConstraint : Type
;
InnerTypeConstraints :
WITH COMPONENT SingleTypeConstraint
| WITH COMPONENTS MultipleTypeConstraints
;

SingleTypeConstraint : Constraint
;

MultipleTypeConstraints : FullSpecification | PartialSpecification
;
FullSpecification : '{' TypeConstraints '}'
;
PartialSpecification : '{' '...' ',' TypeConstraints '}'
;
TypeConstraints : NamedConstraint
| NamedConstraint ',' TypeConstraints
;
NamedConstraint : identifier ComponentConstraint
;
ComponentConstraint : ValueConstraint PresenceConstraint
;
ValueConstraint : Constraint | empty
;
PresenceConstraint : PRESENT | ABSENT | OPTIONAL | empty
;
PatternConstraint : PATTERN Value
;


/*
 * 49 The exception identifier
 */
ExceptionSpec : EXCLAMATION_MARK ExceptionIdentification
| empty
;
ExceptionIdentification :
SignedNumber
| DefinedValue
| Type COLON Value
;
EnumeratedValue : identifier
;
XMLEnumeratedValue : "<" NO_SPACE identifier "/>"
;

/*
 * 15 Information from objects
 */
DefinedObjectClass :
ExternalObjectClassReference
| objectclassreference
| UsefulObjectClassReference
;
ExternalObjectClassReference :
modulereference '.' objectclassreference
//CPM071031 not sure of this
{$$({CHILD => [$0, $2]});}
;
UsefulObjectClassReference :
TYPE_IDENTIFIER
| ABSTRACT_SYNTAX
;
ObjectClassAssignment :
objectclassreference "::=" ObjectClass
{
  if(%{$2}) {
    $$($2);
  } else {
    $$({TYPE => $2});
  }
  $$->{VAR} = $0;
}
;
ObjectClass :
DefinedObjectClass
| ObjectClassDefn
| ParameterizedObjectClass
;
ObjectClassDefn :
CLASS '{' FieldSpec (',' FieldSpec)* '}' WithSyntaxSpec?
{
  $$({TYPE => $n0->val, CHILD => $3, OPT => $5});
  unshift(@{$$->{CHILD}}, $2);
  #grep(/^[^\,]/, @{$3});
  warn("OBJCLASSDEFN::".Dumper($2,$3,$4));
}
;
FieldSpec :
TypeFieldSpec
| FixedTypeValueFieldSpec
| VariableTypeValueFieldSpec
| FixedTypeValueSetFieldSpec
| VariableTypeValueSetFieldSpec
| ObjectFieldSpec
| ObjectSetFieldSpec
;
PrimitiveFieldName :
typefieldreference
| valuefieldreference
| valuesetfieldreference
| objectfieldreference
| objectsetfieldreference
;
FieldName :
PrimitiveFieldName ('.' PrimitiveFieldName)*
{
  if(defined($1) && (ref($1) eq 'ARRAY')) {
    $$($1);
    unshift(@{$$}, $0);
  } else {
    $$([$0]);
  }
}
;
TypeFieldSpec :
typefieldreference TypeOptionalitySpec?
{$$({OPT => $1, VAR => $0});}
;
TypeOptionalitySpec : OPTIONAL
| DEFAULT Type
{$$({CHILD => $1, VAR => $n0->val});}
;
FixedTypeValueFieldSpec :
valuefieldreference Type UNIQUE ? ValueOptionalitySpec ?
{
 if(%{$1}) {
   $$($1);
 } else {
   $$({TYPE => $1});
 }
 $$->{VAR} = $0;
 $$->{OPT} = [$2, $3];
}
;
ValueOptionalitySpec :
OPTIONAL
| DEFAULT Value
{$$({CHILD => $1, VAR => $n0->val});}
;
VariableTypeValueFieldSpec :
valuefieldreference FieldName ValueOptionalitySpec ?
{$$({VAR => $0
  , TYPE => ((ref($1) eq 'ARRAY') ? pop(@{$1}) : $1)
  , OPT => $2});}
;
FixedTypeValueSetFieldSpec :
valuesetfieldreference Type ValueSetOptionalitySpec ?
{$$({VAR => $0
  , TYPE => ((ref($1) eq 'ARRAY') ? pop(@{$1}) : $1)
  , OPT => $2});
}
;
ValueSetOptionalitySpec :
OPTIONAL
| DEFAULT ValueSet
{$$({CHILD => $1, VAR => $n0->val});}
;
VariableTypeValueSetFieldSpec :
valuesetfieldreference FieldName ValueSetOptionalitySpec?
{$$({VAR => $0
  , TYPE => ((ref($1) eq 'ARRAY') ? pop(@{$1}) : $1)
  , OPT => $2});}
;
ObjectFieldSpec : objectfieldreference DefinedObjectClass ObjectOptionalitySpec?
;
ObjectOptionalitySpec :
OPTIONAL
| DEFAULT Object
{$$({CHILD => $1, VAR => $n0->val});}
;
ObjectSetFieldSpec : objectsetfieldreference DefinedObjectClass ObjectSetOptionalitySpec ?
;
ObjectSetOptionalitySpec : OPTIONAL
| DEFAULT ObjectSet
{$$({VAR => $n0->val, CHILD => $1});}
;
WithSyntaxSpec : WITH SYNTAX SyntaxList
{$$({VAR => $n0->val .  $n1->val, CHILD => $2});}
;
SyntaxList : '{' TokenOrGroupSpec + '}'
{$$($1);}
;


//reduce_action:: why skipping speculative reduction ?    dpn@1140569c sym[274]pn@[0x11405640 OptionalGroup]      redu@1d07270c rscode@0 pscode@6f182020
//goto 254 (OptionalGroup) -> 1325 0x1153b190
//goto 254 (OptionalGroup) -> 1325 0x1153b190
//goto 254 (OptionalGroup) -> 1325 0x1153b190
//reduce 1325 0x1153b190 1
//reduce_action:: why skipping speculative reduction ?    dpn@114055ec sym[273]pn@[0x11405590 TokenOrGroupSpec]   redu@1d0726e8 rscode@0 pscode@6f182020
//goto 254 (TokenOrGroupSpec) -> 1324 0x1153b070
//commit_tree::   skipping final reduction        dpn@11403d7c sym[670]pn@[0x11403d20 []  redu@0 rfcode@ffffffff pfcode@6f181f70
//fail: circular parse: unable to fixup internal symbol
// TokenOrGroupSpec -> OptionalGroup -> TokenOrGroupSpec
TokenOrGroupSpec :
RequiredToken
| OptionalGroup
;
OptionalGroup : '[' TokenOrGroupSpec + ']'
{$$($1);}
;
RequiredToken : Literal
| PrimitiveFieldName
;
Literal : word
| ','
;
DefinedObject : ExternalObjectReference
| objectreference
;
ExternalObjectReference : modulereference FULL_STOP objectreference
;
ObjectAssignment : objectreference DefinedObjectClass Assignment_lexical_item Object
{
  $$({VAR => $0
     , CHILD => $3
     , TYPE  => $1
     });
}
;
Object : DefinedObject
| ObjectDefn
| ObjectFromObject
| ParameterizedObject
;
ObjectDefn : DefaultSyntax
| DefinedSyntax
;
DefaultSyntax : '{' FieldSetting (',' FieldSetting)* '}'
;
FieldSetting : PrimitiveFieldName Setting
;
DefinedSyntax : '{' DefinedSyntaxToken * '}'
{$$($1);}
;
DefinedSyntaxToken : Literal
| Setting
;
Setting : Type
| Value
| ValueSet
| Object
| ObjectSet
;
DefinedObjectSet : ExternalObjectSetReference | objectsetreference
;
ExternalObjectSetReference : modulereference '.' objectsetreference
;
ObjectSetAssignment : objectsetreference DefinedObjectClass "::=" ObjectSet
;
ObjectSet : '{' ObjectSetSpec '}'
;
ObjectSetSpec :
RootElementSetSpec
| RootElementSetSpec ',' '...'
| '...'
| '...' ',' AdditionalElementSetSpec
| RootElementSetSpec ',' '...' ',' AdditionalElementSetSpec
;
ObjectSetElements :
Object | DefinedObjectSet | ObjectSetFromObjects | ParameterizedObjectSet
;
ObjectClassFieldType : DefinedObjectClass '.' FieldName
;
ObjectClassFieldValue : OpenTypeFieldVal | FixedTypeFieldVal
;
OpenTypeFieldVal : Type ":" Value
;
FixedTypeFieldVal : BuiltinValue | ReferencedValue
;
XMLObjectClassFieldValue :
XMLOpenTypeFieldVal
| XMLFixedTypeFieldVal
;
XMLOpenTypeFieldVal : XMLTypedValue
;
XMLFixedTypeFieldVal : XMLBuiltinValue
;
InformationFromObjects : ValueFromObject | ValueSetFromObjects |
TypeFromObject | ObjectFromObject | ObjectSetFromObjects
;
ReferencedObjects :
DefinedObject | ParameterizedObject |
DefinedObjectSet | ParameterizedObjectSet
;
ValueFromObject : ReferencedObjects '.' FieldName
;
ValueSetFromObjects : ReferencedObjects '.' FieldName
;
TypeFromObject : ReferencedObjects '.' FieldName
;
ObjectFromObject : ReferencedObjects '.' FieldName
;
ObjectSetFromObjects : ReferencedObjects '.' FieldName
;
InstanceOfType : INSTANCE OF DefinedObjectClass
;
InstanceOfValue ::= 'Value' $term -100;
;
//CPM0710a used to be : Value
// but creates a loop... Value  BuiltinValue InstanceOfValue
//TODO: need to work is that out there?

XMLInstanceOfValue : XMLValue
;

GeneralConstraint : UserDefinedConstraint
| TableConstraint
| ContentsConstraint
;

UserDefinedConstraint : CONSTRAINED BY '{' UserDefinedConstraintParameter? (',' UserDefinedConstraintParameter)* '}'
;

UserDefinedConstraintParameter :
Governor ":" Value
| Governor ":" ValueSet
| Governor ":" Object
| Governor ":" ObjectSet
| Type
| DefinedObjectClass
;

TableConstraint:SimpleTableConstraint | ComponentRelationConstraint
;

SimpleTableConstraint : ObjectSet
;

ComponentRelationConstraint : '{' DefinedObjectSet '}' '{' AtNotation (','  AtNotation)* '}'
;

AtNotation : "@" ComponentIdList | "@." Level ComponentIdList
;

Level: '.' Level | empty
;

ComponentIdList : identifier ('.' identifier)*
;

ContentsConstraint :
CONTAINING Type
| ENCODED BY Value
| CONTAINING Type ENCODED BY Value
;

ParameterizedAssignment :
ParameterizedTypeAssignment
| ParameterizedValueAssignment
| ParameterizedValueSetTypeAssignment
| ParameterizedObjectClassAssignment
| ParameterizedObjectAssignment
| ParameterizedObjectSetAssignment
;
ParameterizedTypeAssignment :
typereference ParameterList "::=" Type
;
ParameterizedValueAssignment :
valuereference ParameterList Type "::=" Value
;
ParameterizedValueSetTypeAssignment :
typereference ParameterList Type "::=" ValueSet
;
ParameterizedObjectClassAssignment :
objectclassreference ParameterList "::=" ObjectClass
;
ParameterizedObjectAssignment :
objectreference ParameterList DefinedObjectClass "::=" Object
;
ParameterizedObjectSetAssignment :
objectsetreference ParameterList DefinedObjectClass "::=" ObjectSet
;
ParameterList : '{' Parameter (',' Parameter)* '}'
;
Parameter : ParamGovernor ":" DummyReference | DummyReference
;
ParamGovernor : Governor | DummyGovernor
;
Governor : Type | DefinedObjectClass
;
DummyGovernor : DummyReference
;
DummyReference : Reference
;
ParameterizedReference :
Reference | Reference '{' '}'
;
SimpleDefinedType : ExternalTypeReference | typereference
;
SimpleDefinedValue : ExternalValueReference | valuereference
;
ParameterizedType : SimpleDefinedType ActualParameterList
;
ParameterizedValue : SimpleDefinedValue ActualParameterList
;
ParameterizedValueSetType :
SimpleDefinedType ActualParameterList
;
ParameterizedObjectClass :
DefinedObjectClass ActualParameterList
{$$({TYPE => $0, CHILD => $1});}
;
ParameterizedObjectSet : DefinedObjectSet ActualParameterList
;
ParameterizedObject : DefinedObject ActualParameterList
;
ActualParameterList :
'{' ActualParameter (',' ActualParameter)* '}'
{
  $$([$1]);
  push @{$$}, grep(/^[^\,]/, @{$2});
}
;
ActualParameter :
Type
| Value
| ValueSet
| DefinedObjectClass
| Object
| ObjectSet
;


/*
 * 11 ASN.1 lexical items
 */
//& means not space! oops
/* except that no lower-case letters or digits shall be included. */

objectreference : valuereference
;
objectsetreference : typereference
;
typefieldreference : AMPERSAND typereference
{$$($n0->val . $1);}
;
valuefieldreference : AMPERSAND valuereference
{$$($n0->val . $1);}
;
valuesetfieldreference : AMPERSAND typereference
{$$($n0->val . $1);}
;
objectsetfieldreference : AMPERSAND objectsetreference
{$$($n0->val . $1);}
;
objectfieldreference : AMPERSAND objectreference
{$$($n0->val . $1);}
;
//CPM071121 got closer to specs.
/* only upper cases*/
//X6811 s7.1
objectclassreference ::= "[A-Z][A-Z0-9_\-]*" $term -2
;
//X6801 s11.2
typereference ::= "[A-Z][a-zA-Z0-9_\-]*" $term -1
;
//changed from LWORD?
identifier : WORD {$$($n0->val);}
;
valuereference  : LWORD
;
modulereference : typereference
;
comment    ::= COMMENT
;
number     : NUMBER     {$$(int(0 + $n0->val));}
;
realnumber : REALNUMBER {$$(0.0 + $n0->val);}
;

//X6801 s11.10
bstring    : QUOTATION_MARK "[0-1]"* QUOTATION_MARK 'B'
// BSTRING
;
xmlbstring : XMLBSTRING
;
hstring    : HSTRING
;
cstring    : CSTRING
;
xmlhstring : XMLHSTRING | XMLBSTRING
;
xmlcstring : XMLCSTRING | xmlhstring
;
xmlasn1typename: typereference
;
Assignment_lexical_item ::= "::="
;
Range_separator         ::= '..' $term 2
;
XML_end_tag_start_item  ::= "</"
;
XML_single_tag_end_item ::= "/>"
;
Ellipsis                ::= '...' $term 3
;
Left_version_brackets   ::= '[[' $term 2
;
Right_version_brackets  ::= ']]' $term 2
;
XML_boolean_true_item   ::= "true"
;
XML_boolean_false_item  ::= "false"
;

/* reserved words and ASN things */
ABSENT          ::= 'ABSENT'
;
ENCODED         ::= 'ENCODED'
;
INTEGER         ::= 'INTEGER'
;
RELATIVE_OID    ::= 'RELATIVE-OID'
;
ABSTRACT_SYNTAX ::= 'ABSTRACT-SYNTAX'
;
END             ::= 'END'
;
INTERSECTION    ::= 'INTERSECTION'
;
SEQUENCE        ::= 'SEQUENCE'
;
ALL             ::= 'ALL'
;
ENUMERATED      ::= 'ENUMERATED'
;
ISO646String    ::= 'ISO646String'
;
SET             ::= 'SET'
;
APPLICATION     ::= 'APPLICATION'
;
EXCEPT          ::= 'EXCEPT'
;
MAX             ::= 'MAX';
SIZE            ::= 'SIZE';
AUTOMATIC       ::= 'AUTOMATIC';
EXPLICIT        ::= 'EXPLICIT';
MIN             ::= 'MIN';
STRING          ::= 'STRING';
BEGIN           ::= 'BEGIN';
EXPORTS         ::= 'EXPORTS';
MINUS_INFINITY  ::= 'MINUS-INFINITY';
SYNTAX          ::= 'SYNTAX';
BIT             ::= 'BIT';
EXTENSIBILITY   ::= 'EXTENSIBILITY';
NULL            ::= 'NULL' $term 10
;
T61String       ::= 'T61String';
BMPString       ::= 'BMPString';
EXTERNAL        ::= 'EXTERNAL';
NumericString   ::= 'NumericString';
TAGS            ::= 'TAGS';
BOOLEAN         ::= 'BOOLEAN';
FALSE           ::= 'FALSE';
OBJECT          ::= 'OBJECT';
TeletexString   ::= 'TeletexString';
BY              ::= 'BY'
;
FROM            ::= 'FROM'
;
ObjectDescriptor ::= 'ObjectDescriptor' $term 10
;
TRUE            ::= 'TRUE'
;
CHARACTER       ::= 'CHARACTER'
;
GeneralizedTime : 'GeneralizedTime'
;
OCTET           ::= 'OCTET';
TYPE_IDENTIFIER ::= 'IDENTIFIER';
CHOICE          ::= 'CHOICE';
GeneralString   ::= 'GeneralString';
OF              ::= 'OF';
UNION           ::= 'UNION';
CLASS           ::= 'CLASS';
GraphicString   ::= 'GraphicString';
OPTIONAL        ::= 'OPTIONAL';
UNIQUE          ::= 'UNIQUE';
COMPONENT       ::= 'COMPONENT';
IA5String       ::= 'IA5String';
PATTERN         ::= 'PATTERN';
UNIVERSAL       ::= 'UNIVERSAL';
COMPONENTS      ::= 'COMPONENTS';
IDENTIFIER      ::= 'IDENTIFIER';
PDV             ::= 'PDV';
UniversalString ::= 'UniversalString';
CONSTRAINED     ::= 'CONSTRAINED';
IMPLICIT        ::= 'IMPLICIT';
PLUS_INFINITY   ::= 'PLUS_INFINITY'
;
UTCTime : 'UTCTime'
;
CONTAINING      ::= 'CONTAINING';
IMPLIED         ::= 'IMPLIED';
PRESENT         ::= 'PRESENT';
UTF8String      ::= 'UTF8String';
DEFAULT         ::= 'DEFAULT';
IMPORTS         ::= 'IMPORTS';
PrintableString ::= 'PrintableString';
VideotexString  ::= 'VideotexString';
DEFINITIONS     ::= 'DEFINITIONS' ;
INCLUDES        ::= 'INCLUDES';
PRIVATE         ::= 'PRIVATE';
VisibleString   ::= 'VisibleString';
EMBEDDED        ::= 'EMBEDDED';
INSTANCE        ::= 'INSTANCE';
REAL            ::= 'REAL';
WITH            ::= 'WITH'
;
EXCLAMATION_MARK        ::= '!'  ;
QUOTATION_MARK          ::= '"'  ;
AMPERSAND         	::= '&'
;
APOSTROPHE          	::= "\'" ;
LEFT_PARENTHESIS    	::= '('  ;
RIGHT_PARENTHESIS   	::= ')'  ;
ASTERISK            	::= '*'  ;
COMMA               	::= ','  ;
HYPHEN_MINUS        	::= '-'  ;
FULL_STOP           	::= '.'  ;
SOLIDUS             	::= '/'  ;
COLON               	::= ':'  ;
SEMICOLON           	::= ';'  ;
LESS_THAN_SIGN      	::= '<'  ;
EQUALS_SIGN         	::= '='  ;
GREATER_THAN_SIGN   	::= '>'  ;
COMMERCIAL_AT       	::= '@'  ;
LEFT_SQUARE_BRACKET 	::= '['  ;
RIGHT_SQUARE_BRACKET	::= ']'  ;
CIRCUMFLEX_ACCENT   	::= '^'  ;
LOW_LINE            	::= '_'  ;
LEFT_CURLY_BRACKET  	::= '{'  ;
VERTICAL_LINE       	::= '|'  ;
RIGHT_CURLY_BRACKET     ::= '}'  ;

/*
 * character sets
 */
LATIN_CAPITAL_LETTER  ::= "[A-Z]";
LATIN_SMALL_LETTER    ::= "[a-z]";
DIGIT                 ::= "[0-9]";
LWORD                 ::= "[a-z][a-zA-Z0-9_\-]*";
Lword                 ::= "[a-z][a-z0-9_\-]*";
WORD                  ::= "[a-zA-Z][a-zA-Z0-9_\-]*" $term 1;
Uword                 ::= "[A-Z][a-z0-9_\-]*";
//X6811 s7.9
word                  ::= "[A-Z][A-Z_\-]*";
UWORD                 ::= WORD;
NUMBER                ::= "[0-9]+" $term -1;
REALNUMBER            ::= "[0-9]+(\.[0-9]*)?([eE][+-]?[0-9]+)?" $term -2;

BSTRING      ::= QUOTATION_MARK "[^\"]"* QUOTATION_MARK;
HSTRING      ::= BSTRING;
CSTRING      ::= BSTRING;
XMLBSTRING   ::= BSTRING;
XMLHSTRING   ::= BSTRING;
XMLCSTRING   ::= BSTRING;

whitespace : "[ \t\n]*" | COMMENT;
COMMENT    ::= "--.*\n";
NO_SPACE:;
empty : ;


/* SPACE functions */
/*NO_SPACE     ::= "[^ ]";*/
//${token SPACE NO_SPACE COMMENT}
_GRAM_
;


__END__
