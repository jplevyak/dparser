
/* reserved words */

%debug
%verbose

%glr-parser

//%expect-rr 1

%token yytkABSENT  yytkENCODED yytkINTEGER yytkRELATIVE_OID yytkABSTRACT_SYNTAX yytkEND yytkINTERSECTION yytkSEQUENCE yytkALL             
%token yytkENUMERATED yytkISO646String yytkSET yytkAPPLICATION yytkEXCEPT yytkMAX yytkSIZE yytkAUTOMATIC  yytkEXPLICIT yytkMIN
%token yytkSTRING yytkBEGIN yytkEXPORTS yytkMINUS_INFINITY yytkSYNTAX yytkBIT yytkEXTENSIBILITY yytkNULL yytkT61String
%token yytkBMPString yytkEXTERNAL yytkNumericString yytkTAGS yytkBOOLEAN yytkFALSE yytkOBJECT yytkTeletexString yytkBY yytkFROM yytkObjectDescriptor 
%token yytkTRUE yytkCHARACTER yytkGeneralizedTime yytkOCTET yytkTYPE_IDENTIFIER yytkCHOICE yytkGeneralString yytkOF
%token yytkUNION yytkCLASS yytkGraphicString yytkOPTIONAL yytkUNIQUE yytkCOMPONENT    yytkIA5String yytkPATTERN      yytkUNIVERSAL  yytkCOMPONENTS   yytkIDENTIFIER
%token yytkPDV  yytkUniversalString yytkCONSTRAINED  yytkIMPLICIT yytkPLUS_INFINITY yytkUTCTime        yytkCONTAINING    yytkIMPLIED    
%token yytkPRESENT       yytkUTF8String     yytkDEFAULT       yytkIMPORTS  yytkPrintableString   yytkVideotexString yytkDEFINITIONS   yytkINCLUDES
%token yytkPRIVATE       yytkVisibleString     yytkEMBEDDED      yytkINSTANCE  yytkREAL          yytkWITH             

/* character sets */
%token yytkLATIN_CAPITAL_LETTER  yytkLATIN_SMALL_LETTER  yytkDIGIT
%token yytkEXCLAMATION_MARK       yytkQUOTATION_MARK         yytkAMPERSAND              yytkAPOSTROPHE             yytkLEFT_PARENTHESIS       yytkRIGHT_PARENTHESIS      yytkASTERISK               yytkCOMMA                  yytkHYPHEN_MINUS           yytkFULL_STOP              yytkSOLIDUS                yytkCOLON                  yytkSEMICOLON              yytkLESS_THAN_SIGN         yytkEQUALS_SIGN            yytkGREATER_THAN_SIGN      yytkCOMMERCIAL_AT          yytkLEFT_SQUARE_BRACKET    yytkRIGHT_SQUARE_BRACKET   yytkCIRCUMFLEX_ACCENT      yytkLOW_LINE               yytkLEFT_CURLY_BRACKET     yytkVERTICAL_LINE          yytkRIGHT_CURLY_BRACKET    yytkUWORD        yytkLWORD        yytkCOMMENT      yytkPOSTRBRACE   yytkNUMBER       yytkREALNUMBER   yytkBSTRING      yytkHSTRING      yytkCSTRING      yytkXMLBSTRING   yytkXMLHSTRING   yytkXMLCSTRING   yytkNO_SPACE     yytkWORD


%%

/*
12.1 A "ModuleDefinition" is specified by the following productions:
*/

ModuleDefinition :
ModuleIdentifier yytkDEFINITIONS TagDefault ExtensionDefault Assignment_lexical_item yytkBEGIN ModuleBody yytkEND
{
  return { $_[1] => $_[7], attribs => [$_[2], $_[3], $_[4]] }
}
;

ModuleIdentifier : modulereference DefinitiveIdentifier
{
  $_[1]->{ref} = $_[2];
  return($_[1])
}
;

DefinitiveIdentifier :
yytkLEFT_CURLY_BRACKET DefinitiveObjIdComponentList yytkRIGHT_CURLY_BRACKET
(-
  return($_[2])
-)
| empty
;

DefinitiveObjIdComponentList : DefinitiveObjIdComponent

| DefinitiveObjIdComponent DefinitiveObjIdComponentList
(-
 return push $
 -)
;

DefinitiveObjIdComponent : NameForm
| DefinitiveNumberForm
| DefinitiveNameAndNumberForm
;

DefinitiveNumberForm : number;

DefinitiveNameAndNumberForm : identifier yytkLEFT_PARENTHESIS DefinitiveNumberForm yytkRIGHT_PARENTHESIS
;


TagDefault : yytkEXPLICIT yytkTAGS
| yytkIMPLICIT yytkTAGS
| yytkAUTOMATIC yytkTAGS
| empty
;


ExtensionDefault : yytkEXTENSIBILITY yytkIMPLIED
| empty
;


ModuleBody : Exports Imports AssignmentList
| empty
;

Exports : yytkEXPORTS SymbolsExported yytkSEMICOLON
| yytkEXPORTS yytkALL yytkSEMICOLON
| empty
  ;

SymbolsExported : SymbolList
| empty
;



Imports : yytkIMPORTS SymbolsImported yytkSEMICOLON
| empty
;

SymbolsImported : SymbolsFromModuleList
| empty
;

SymbolsFromModuleList : SymbolsFromModule
| SymbolsFromModuleList SymbolsFromModule
;

SymbolsFromModule : SymbolList yytkFROM GlobalModuleReference;

GlobalModuleReference : modulereference AssignedIdentifier;

AssignedIdentifier : ObjectIdentifierValue
| DefinedValue
| empty
;

SymbolList : Symbol
| SymbolList yytkCOMMA Symbol
;

Symbol : Reference
| ParameterizedReference
;

Reference : typereference
| valuereference
| objectclassreference
| objectreference
| objectsetreference
;


AssignmentList : Assignment
| AssignmentList Assignment;

Assignment : TypeAssignment
| ValueAssignment
| XMLValueAssignment
| ValueSetTypeAssignment
| ObjectClassAssignment
| ObjectAssignment
| ObjectSetAssignment
| ParameterizedAssignment
;



/*
aitem	: Class plicit anyelem //postrb
		{
		  //$_[3]->[enTAG] = $_[1];
		  //$$ = $_[2] ? explicit($_[3]) : $_[3];
		  AV* av = (AV*) SvRV($_[3]);
		  av_store(av, enTAG, $_[1]);		  
		  $$ = (SvTRUE($_[2]) ? call_explicit($_[3]) : $_[3]);
		}
	| celem
	;

seqset	: yytkSEQUENCE	| yytkSET
	;

selem	: seqset yytkOF Class plicit sselem optional
		{
		  //$_[5]->[enTAG] = $_[3];
		  //@{$$ = []}[cTYPE,enCHILD,enLOOP,cOPT] = ($_[1], [$_[5]], 1, $_[6]);
		  //$$ = explicit($$) if $_[4];
		  AV* av_0 = newAV();
		  AV* av  = (AV*) SvRV($_[5]);
		  av_store(av, enTAG, $_[3]);
		  av_store(av_0, 0, $_[5]);
		  av = newAV();
		  av_store(av, enTYPE,  $_[1]);
		  av_store(av, enCHILD, (SV*) av_0);
		  av_store(av, enLOOP,  $_[1]);
		  av_store(av, enOPT,   $_[6]);
		  $$ = newRV((SV*) av); 
		  if(SvTRUE($_[4])) { $$ = call_explicit($$);}
		}
	;



onelem	: yytkSEQUENCE yytkLEFT_CURLY_BRACKET slist yytkRIGHT_CURLY_BRACKET
		{
		  //@{$$ = []}[cTYPE,enCHILD] = ('SEQUENCE', $_[3]);
		  AV* av = newAV();
		  av_store(av, enTYPE, newSVpv("SEQUENCE", 10));
		  av_store(av, enCHILD, $_[3]);
		  $$ = newRV((SV*) av);     
		}
	| yytkSET yytkLEFT_CURLY_BRACKET slist yytkRIGHT_CURLY_BRACKET
		{
		  //@{$$ = []}[cTYPE,enCHILD] = ('SET', $_[3]);
		  AV* av = newAV();
		  av_store(av, enTYPE, newSVpv("SET", 3));
		  av_store(av, enCHILD, $_[3]);
		  $$ = newRV((SV*) av);
		}
	| yytkCHOICE  yytkLEFT_CURLY_BRACKET nlist yytkRIGHT_CURLY_BRACKET
		{
		  //@{$$ = []}[cTYPE,enCHILD] = ("CHOICE", $_[3]);
		  AV* av = newAV();
		  av_store(av, enTYPE, newSVpv("CHOICE", 6));
		  av_store(av, enCHILD, $_[3]);
		  $$ = newRV((SV*) av);
		}
	;

eelem   : yytkENUMERATED yytkLEFT_CURLY_BRACKET elist yytkRIGHT_CURLY_BRACKET
		{
		  //@{$$ = []}[cTYPE] = ('ENUM');
		  AV* av = newAV();
		  av_store(av, enTYPE, newSVpv("ENUM", 4));
		  $$ = newRV((SV*) av);
		}
	;


oielem	: yytkUWORD
        { 
	  //@{$$ = []}[cTYPE] = $_[1];
	  AV* av = newAV();
	  av_store(av, enTYPE, $_[1]);
	  $$ = newRV((SV*) av);
	}
        | yytkSEQUENCE
        { 
	  //@{$$ = []}[cTYPE] = $_[1];
	  AV* av = newAV();
	  av_store(av, enTYPE, $_[1]);
	  $$ = newRV((SV*) av);
	}
	| yytkSET
        { 
	  //@{$$ = []}[cTYPE] = $_[1];
	  AV* av  = newAV();
	  av_store(av, enTYPE, $_[1]);
	  $$ = newRV((SV*) av);
	}
	| yytkENUMERATED
        {
	  //@{$$ = []}[cTYPE] = $_[1];
	  AV* av = newAV();
	  av_store(av, enTYPE, $_[1]);
	  $$ = newRV((SV*) av);
	}
	;

| yytkALL defined
        {
	  //@{$$ = []}[cTYPE,enCHILD,enDEFINE] = ('ANY',undef,$_[2]);
	  AV* av  = newAV();
	  av_store(av, enTYPE, newSVpv("ANY", 4));
	  av_store(av, enCHILD, &PL_sv_undef);
	  av_store(av, enDEFINE, $_[2]);
	  $$ = newRV((SV*) av);
	}







nlist	: nlist1		{ $$ = $_[1] }
	| nlist1 yytkPOSTRBRACE	{ $$ = $_[1] }
	;

nlist1	: nitem
	{
	  //$$ = [ $_[1] ];
	  AV* av = newAV();
	  av_store(av, 0, $_[1]);
	  $$ = newRV((SV*) av)
	}
	| nlist1 yytkPOSTRBRACE nitem
	{
	  //push @{$$=$_[1]}, $_[3];
	  AV* av = (AV*) SvRV($_[1]);
	  av_push(av, $_[3]);
	  $$ = $_[1]
	}
	| nlist1 yytkCOMMA nitem
	{
	  //push @{$$=$_[1]}, $_[3];
	  AV* av = (AV*) SvRV($_[1]);
	  av_push(av, $_[3]);
	  $$ = $_[1]
	}
	;

nitem	: yytkUWORD Class plicit anyelem
	{
	  //@{$$=$_[4]}[enVAR,enTAG] = ($_[1],$_[2]);
	  //$$ = explicit($$) if $_[3];
	  AV* av = (AV*) SvRV($_[4]);
	  av_store(av, enVAR, $_[1]);
	  av_store(av, enTAG, $_[2]);
	  $$ = (SvTRUE($_[3]) ? call_explicit($_[4]) : $_[4])
	}
	;



slist	: sitem
	{
	  //$$ = [ $_[1] ];
	  AV* av = newAV();
	  $$ = *av_store(av, 0, $_[1])
	}
	| slist yytkCOMMA sitem
	{
	  //push @{$$=$_[1]}, $_[3];
  	  AV* av = (AV*) SvRV($_[1]);
	  av_push(av, $_[3]);
	  $$ = $_[1]
	}
	| slist yytkPOSTRBRACE sitem
	{
	  //push @{$$=$_[1]}, $_[3];
  	  AV* av = (AV*) SvRV($_[1]);
	  av_push(av, $_[3]);
	  $$ = $_[1]
	}
	;

snitem	: oelem optional
	{
	  //@{$$=$_[1]}[cOPT] = ($_[2]);
	  AV* av = (AV*) SvRV($_[1]);
	  av_store(av, enOPT, $_[2]);
	  $$ = $_[1]  
	}
	| eelem
	| selem
	| onelem
	;

sitem	: yytkUWORD class plicit snitem 
	{
	  //@{$$=$_[4]}[enVAR,enTAG] = ($_[1],$_[2]);
	  //$$->[cOPT] = $_[1] if $$->[cOPT];
	  //$$ = explicit($$) if $_[3];
	  AV* av = (AV*) SvRV($_[4]);
	  av_store(av, enVAR, $_[1]);
	  av_store(av, enTAG, $_[2]);		  
	  if(av_fetch(av, enOPT, 0) != NULL) {
	    av_store(av, enOPT, $_[1]);
	  }
	  $$ = (SvTRUE($_[3]) ? call_explicit($_[4]) : $_[4])
	}
	| celem
	| class plicit onelem
        {
	  //@{$$=$_[3]}[enTAG] = ($_[1]);
	  //$$ = explicit($$) if $_[2];
	  AV* av = (AV*) SvRV($_[3]);
	  av_store(av, enTAG, $_[1]);
	  $$ = (SvTRUE($_[2]) ? call_explicit($_[3]) : $_[3])
	}
	;

*/


/*13 Referencing type and value definitions */

DefinedType : ExternalTypeReference
| typereference
| ParameterizedType
| ParameterizedValueSetType
  ;

DefinedValue : ExternalValueReference
| valuereference
| ParameterizedValue
;

NonParameterizedTypeName : ExternalTypeReference | typereference | xmlasn1typename ;

ExternalTypeReference : modulereference yytkFULL_STOP typereference
(-
{ //type
  // $$->{ref} = $_[1]->{ref} . $_[3]->{ref} ???
  //     ext_ref ::= ext_mod . my_type
}
-)
;


ExternalValueReference : modulereference yytkFULL_STOP valuereference
(-
{ //value
  // $$->{ref} = $_[1]->{ref} . $_[3]->{ref} ???
  //     ext_ref ::= ext_mod . my_type
}
-)
;




/*14 Notation to support references to ASN.1 components*/

AbsoluteReference : yytkCOMMERCIAL_AT ModuleIdentifier yytkFULL_STOP ItemSpec;

ItemSpec : typereference | ItemId yytkFULL_STOP ComponentId ;

ItemId : ItemSpec;

ComponentId : identifier | number | yytkASTERISK;


/*15 Assigning types and values */

TypeAssignment : typereference Assignment_lexical_item Type;

ValueAssignment : valuereference Type Assignment_lexical_item Value;

ValueSetTypeAssignment : typereference Type Assignment_lexical_item ValueSet;

ValueSet : yytkLEFT_CURLY_BRACKET ElementSetSpecs yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
 -)
;


XMLValueAssignment : valuereference Assignment_lexical_item XMLTypedValue;
XMLTypedValue : 
  yytkLESS_THAN_SIGN yytkNO_SPACE NonParameterizedTypeName yytkGREATER_THAN_SIGN
  XMLValue XML_end_tag_start_item yytkNO_SPACE NonParameterizedTypeName yytkGREATER_THAN_SIGN
| yytkLESS_THAN_SIGN yytkNO_SPACE NonParameterizedTypeName XML_end_tag_start_item
;




/*16 Definition of types and values*/

Type : BuiltinType
(-
 $$ = new ();
 $$->{type} = $_[1];
 return $$;
 -)

| ReferencedType
(-
  
 -)
| ConstrainedType
 
(-
 -)
;




BuiltinType : BitStringType
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


// Type ???
SequenceOfType : yytkSEQUENCE yytkOF Type
| yytkSEQUENCE yytkOF NamedType
;

ReferencedType : DefinedType
		 | UsefulType
| SelectionType
| TypeFromObject
| ValueSetFromObjects
;

SelectionType : identifier "<" Type;

NamedType : identifier Type
(-
 return { $_[1] => { type => $_[2] } }
 -)
;


Value : BuiltinValue | ReferencedValue | ObjectClassFieldValue;

XMLValue : XMLBuiltinValue
| XMLObjectClassFieldValue
;

ObjectClassFieldValue :
OpenTypeFieldVal 
| FixedTypeFieldVal
;

OpenTypeFieldVal : Type yytkCOLON Value;

BuiltinValue : BitStringValue
| BooleanValue
| CharacterStringValue
| ChoiceValue
	       | EmbeddedPDVValue
| EnumeratedValue
	       | ExternalValue
| InstanceOfValue
| IntegerValue
| NullValue
| ObjectIdentifierValue
	       | OctetStringValue //included in BitStringValue
| RealValue
| RelativeOIDValue
	       | SequenceValue
| SequenceOfValue
	       | SetValue | SetOfValue //is Sequence also.
| TaggedValue
;


XMLBuiltinValue :
XMLBitStringValue
| XMLBooleanValue
//| XMLCharacterStringValue
		  //| XMLChoiceValue
		  //| XMLEmbeddedPDVValue
| XMLEnumeratedValue
		  //| XMLExternalValue
		  //| XMLInstanceOfValue
| XMLIntegerValue
| XMLNullValue
| XMLObjectIdentifierValue
		  //| XMLOctetStringValue in XMLBitStringValue
| XMLRealValue
| XMLRelativeOIDValue
		  //| XMLSequenceValue
		  //| XMLSequenceOfValue
		  //| XMLSetValue | XMLSetOfValue
		  //| XMLTaggedValue
;


ReferencedValue : DefinedValue| ValueFromObject;
NamedValue : identifier Value;



/*17 Notation for the boolean type*/

BooleanType : yytkBOOLEAN;

BooleanValue : yytkTRUE 
| yytkFALSE
;

XMLBooleanValue :
yytkLESS_THAN_SIGN yytkNO_SPACE XML_boolean_true_item XML_single_tag_end_item
| yytkLESS_THAN_SIGN yytkNO_SPACE XML_boolean_false_item XML_single_tag_end_item
;

/*18 Notation for the integer type*/

IntegerType : yytkINTEGER
(-
  return { type => $_[1] }
-)
| yytkINTEGER yytkLEFT_CURLY_BRACKET NamedNumberList yytkRIGHT_CURLY_BRACKET
(-
  return { $_[1] => $_[3] }
-)
;

NamedNumberList : NamedNumber
| NamedNumberList yytkCOMMA NamedNumber
;

NamedNumber : identifier yytkLEFT_PARENTHESIS SignedNumber yytkRIGHT_PARENTHESIS
| identifier yytkLEFT_PARENTHESIS DefinedValue yytkRIGHT_PARENTHESIS
;

SignedNumber : number
| yytkHYPHEN_MINUS number
;

IntegerValue : SignedNumber
| identifier
;

XMLIntegerValue : SignedNumber
| yytkLESS_THAN_SIGN yytkNO_SPACE identifier yytkSOLIDUS yytkGREATER_THAN_SIGN
;

/*19 Notation for the enumerated type*/

EnumeratedType : yytkENUMERATED yytkLEFT_CURLY_BRACKET Enumerations yytkRIGHT_CURLY_BRACKET
(-
  return { ENUM => $_[3] };
-)
;


Enumerations : RootEnumeration
| RootEnumeration yytkCOMMA Ellipsis ExceptionSpec
	       // $_[1], ...  ==> auto incrementation operator with exceptions?! $_[4]
	       // $$ = push @{$_[1]}, ({'...' => $_[4]})

| RootEnumeration yytkCOMMA Ellipsis ExceptionSpec yytkCOMMA AdditionalEnumeration
	       // $$ = push @{$_[1]}, ({'...' => $_[4]}, @{$_[6]})

;

RootEnumeration : Enumeration;

AdditionalEnumeration : Enumeration;



//elist
Enumeration : EnumerationItem
(-
  return [ $_[1] ]
-)
| EnumerationItem yytkCOMMA Enumeration
(-
   return push @{$_[3]}, $_[1]
-)
;

EnumerationItem : identifier | NamedNumber;


/*20 Notation for the real type*/

RealType : yytkREAL;

RealValue : NumericRealValue | SpecialRealValue;

NumericRealValue : realnumber
| yytkHYPHEN_MINUS realnumber
{
  //$$ = - $_[1];
}
//| SequenceValue {}//??? conflict
;

SpecialRealValue : yytkPLUS_INFINITY
{
  //$$ = +inf
}
| yytkMINUS_INFINITY
{
  //$$ = -inf
}
;

XMLRealValue : XMLNumericRealValue | XMLSpecialRealValue ;

XMLNumericRealValue : realnumber | yytkHYPHEN_MINUS realnumber;

XMLSpecialRealValue : yytkLESS_THAN_SIGN yytkNO_SPACE SpecialRealValue XML_single_tag_end_item ;



/*21 Notation for the bitstring type*/

BitStringType : yytkBIT yytkSTRING
{ //$$ = (sprintf("%b",0));
}
| yytkBIT yytkSTRING yytkLEFT_CURLY_BRACKET NamedBitList yytkRIGHT_CURLY_BRACKET
;

NamedBitList : NamedBit
{
  //$$ = push @{$$}, $_[1]
  AV* av = newAV();
  av_push(av, $_[1]);
  $$ = newRV((SV*) av)
}
| NamedBitList yytkCOMMA NamedBit
{
  //$$ = push @{$_[3]}, $_[1]//$$ = push @{$_[1]}, $_[3]
  AV* av = (AV*) SvRV($_[1]);
  av_push(av, $_[3]);
  $$ = $_[1]
}
;

NamedBit : 
identifier  yytkLEFT_PARENTHESIS number yytkRIGHT_PARENTHESIS
(-
  return { $_[1] => $_[3] }
-)
| identifier  yytkLEFT_PARENTHESIS DefinedValue yytkRIGHT_PARENTHESIS
(-
  return { $_[1] => $_[3] }
-)
;




  // 'b11111000111'
BitStringValue : OctetStringValue
| yytkLEFT_CURLY_BRACKET IdentifierList yytkRIGHT_CURLY_BRACKET { $$ = $_[2] }
| yytkLEFT_CURLY_BRACKET empty yytkRIGHT_CURLY_BRACKET { $$ = $_[2] }
;

IdentifierList : identifier
{
  //$$ = push @{$$}, $_[1] 
  AV* av = newAV();
  av_push(av, $_[1]);
  $$ = newRV((SV*) av)
}
| identifier yytkCOMMA IdentifierList 
{
  //$$ = push @{$_[3]}, $_[1]
  AV* av = (AV*) SvRV($_[1]);
  av_push(av, $_[3]);
  $$ = $_[1]
}
;

XMLBitStringValue : XMLOctetStringValue 
		    // XMLTypedValue 
| xmlbstring 
		    //| XMLIdentifierList
| empty
;


XMLIdentifierList : yytkLESS_THAN_SIGN yytkNO_SPACE identifier XML_single_tag_end_item
|  yytkLESS_THAN_SIGN yytkNO_SPACE identifier XML_single_tag_end_item XMLIdentifierList
;


/*22 Notation for the octetstring type*/

OctetStringType : yytkOCTET yytkSTRING {};


/* already done rule by BitStringValue
*/
OctetStringValue :  bstring | hstring
| yytkCONTAINING Value
{  $$ = $_[2] }
;


XMLOctetStringValue : xmlhstring |  XMLTypedValue;

/*23 Notation for the null type*/

NullType : yytkNULL;

NullValue : yytkNULL;

XMLNullValue :  yytkNULL //empty -> conflict
;

/*24 Notation for sequence types*/
SequenceType :
yytkSEQUENCE yytkLEFT_CURLY_BRACKET yytkRIGHT_CURLY_BRACKET
| yytkSEQUENCE yytkLEFT_CURLY_BRACKET ExtensionAndException OptionalExtensionMarker yytkRIGHT_CURLY_BRACKET
| yytkSEQUENCE yytkLEFT_CURLY_BRACKET ComponentTypeLists yytkRIGHT_CURLY_BRACKET
;

ExtensionAndException : Ellipsis | Ellipsis ExceptionSpec;

OptionalExtensionMarker : yytkCOMMA Ellipsis | empty;

ComponentTypeLists : RootComponentTypeList
| RootComponentTypeList yytkCOMMA ExtensionAndException ExtensionAdditions OptionalExtensionMarker
| RootComponentTypeList yytkCOMMA ExtensionAndException ExtensionAdditions ExtensionEndMarker yytkCOMMA RootComponentTypeList
| ExtensionAndException ExtensionAdditions ExtensionEndMarker yytkCOMMA RootComponentTypeList
| ExtensionAndException ExtensionAdditions OptionalExtensionMarker
;

RootComponentTypeList : ComponentTypeList;

ExtensionEndMarker : yytkCOMMA Ellipsis
(-
 -)
;

ExtensionAdditions : yytkCOMMA ExtensionAdditionList
(-
 return $_[2]
 -)
| empty
;

ExtensionAdditionList : ExtensionAddition
{ $$ = push(@{$$}, $_[1]) }
| ExtensionAdditionList yytkCOMMA ExtensionAddition
{ $$ = push(@{$_[1]}, $_[3]) }
;

ExtensionAddition : ComponentType | ExtensionAdditionGroup ;

ExtensionAdditionGroup :
Left_version_brackets VersionNumber ComponentTypeList Right_version_brackets
(-
  return( {
    ver => $_[2]
    , type => $_[3]
    }
          )
-)
;

VersionNumber : empty 
| number yytkCOLON
(-
  $$ = $_[1]
-)
;

ComponentTypeList : ComponentType
//$$ = push @{$$}, $_[1]
| ComponentTypeList yytkCOMMA ComponentType
 //$$ = push @{$_[3]}, $_[1]
;

ComponentType : NamedType
| NamedType yytkOPTIONAL
(-
 $_[1]->{$_[2]} = undef;
 return $_[1]
-)
| NamedType yytkDEFAULT Value
(-
 $_[1]->{$_[2]} = $_[3];
 return $_[1]
-)
| yytkCOMPONENTS yytkOF Type
(-
  //@{$$ = []}[cTYPE,enCHILD] = ('COMPONENTS', $_[3]);
  //AV* av = newAV();
  //av_store(av, enTYPE,  newSVpv("COMPONENTS", 11));
  //av_store(av, enCHILD, $_[3]);
  //$$ = newRV((SV*) av);

  //$$->{type} = $_[3]
  
-)
;



SequenceValue : yytkLEFT_CURLY_BRACKET ComponentValueList yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
 -)
;

ComponentValueList : NamedValue
(-
  return([ $_[1] ])
-)
| ComponentValueList yytkCOMMA NamedValue
(-
  push @{$_[3]}, $_[1]
  return $_[3]
-)
;


XMLComponentValueList : XMLNamedValue | XMLComponentValueList XMLNamedValue;

XMLSequenceValue : XMLNamedValue | XMLSequenceValue XMLNamedValue
// | XMLComponentValueList
;

XMLNamedValue : 
yytkLESS_THAN_SIGN yytkNO_SPACE identifier yytkGREATER_THAN_SIGN
XMLValue 
XML_end_tag_start_item  yytkNO_SPACE identifier yytkGREATER_THAN_SIGN
;


/*25 Notation for sequence-of types*/

SequenceOfValue :
yytkLEFT_CURLY_BRACKET ValueList yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
 -)
| yytkLEFT_CURLY_BRACKET NamedValueList yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
 -)
;


ValueList : Value
(-
  return([ $_[1] ])
-)
| ValueList yytkCOMMA Value
(-
  push @{$_[3]}, $_[1]
  return $_[3]
-)
;

NamedValueList : NamedValue
(-
  return([ $_[1] ])
-)
| NamedValue yytkCOMMA NamedValueList 
(-
  push @{$_[3]}, $_[1]
  return $_[3]
-)
;






XMLValueList : XMLValueOrEmpty |  XMLValueList  XMLValueOrEmpty ;
XMLSpaceSeparatedList: XMLValueList;



XMLSequenceOfValue : XMLDelimitedItemList;

XMLDelimitedItemList : XMLDelimitedItem |  XMLDelimitedItemList XMLDelimitedItem;

XMLDelimitedItem : yytkLESS_THAN_SIGN yytkNO_SPACE NonParameterizedTypeName yytkGREATER_THAN_SIGN XMLValue
XML_end_tag_start_item yytkNO_SPACE NonParameterizedTypeName yytkGREATER_THAN_SIGN
| yytkLESS_THAN_SIGN yytkNO_SPACE identifier yytkGREATER_THAN_SIGN XMLValue XML_end_tag_start_item yytkNO_SPACE identifier yytkGREATER_THAN_SIGN
;

XMLValueOrEmpty : XMLValue
| yytkLESS_THAN_SIGN yytkNO_SPACE NonParameterizedTypeName XML_single_tag_end_item
;


/*26 Notation for set types*/

SetType :
yytkSET yytkLEFT_CURLY_BRACKET empty yytkRIGHT_CURLY_BRACKET
| yytkSET yytkLEFT_CURLY_BRACKET ExtensionAndException OptionalExtensionMarker yytkRIGHT_CURLY_BRACKET
(-
  $_[3]->{marker} = $_[4];
  return $_[3]
-)
| yytkSET yytkLEFT_CURLY_BRACKET ComponentTypeLists yytkRIGHT_CURLY_BRACKET
(-
  return $_[3]
-)
;

/* is sequence also...*/
SetValue :
yytkLEFT_CURLY_BRACKET ComponentValueList yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
 -)
;
XMLSetValue : XMLComponentValueList | empty;



/*27 Notation for set-of types*/

SetOfType : yytkSET yytkOF Type
{ $$ = $_[3] }
| yytkSET yytkOF NamedType
{ $$ = $_[3] }
;



SetOfValue : SequenceOfValue:
yytkLEFT_CURLY_BRACKET ValueList yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
 -)
| yytkLEFT_CURLY_BRACKET NamedValueList yytkRIGHT_CURLY_BRACKET
(-
 return $_[2]
-)
;
XMLSetOfValue : XMLSequenceOfValue | empty;


/*28 Notation for choice types*/


ChoiceType : yytkCHOICE yytkLEFT_CURLY_BRACKET AlternativeTypeLists yytkRIGHT_CURLY_BRACKET
(-
 return $_[3]
 -)
 ;

AlternativeTypeLists : RootAlternativeTypeList
| RootAlternativeTypeList yytkCOMMA ExtensionAndException ExtensionAdditionAlternatives OptionalExtensionMarker
;

RootAlternativeTypeList : AlternativeTypeList;

ExtensionAdditionAlternatives :
yytkCOMMA ExtensionAdditionAlternativesList
{ $$ = $_[2] }
| empty
;

ExtensionAdditionAlternativesList : ExtensionAdditionAlternative
{
  //$$ = push @{$$}, $_[1]
  AV* av = newAV();
  av_push(av, $_[1]);
  $$ = newRV((SV*) av);
}
| ExtensionAdditionAlternativesList yytkCOMMA ExtensionAdditionAlternative
{
  //$$ = push @{$_[1]}, $_[3]
  AV* av = (AV*) SvRV($_[1]);
  av_push(av, $_[3]);
  $$ = $_[1]
}
;
ExtensionAdditionAlternative : ExtensionAdditionAlternativesGroup | NamedType;

ExtensionAdditionAlternativesGroup :
Left_version_brackets VersionNumber AlternativeTypeList Right_version_brackets
;

AlternativeTypeList : NamedType
{
  //$$ = push @{$$}, $_[1]
  AV* av = newAV();
  av_push(av, $_[1]);
  $$ = newRV((SV*) av);
}
| AlternativeTypeList yytkCOMMA NamedType
{
  //$$ = push @{$_[1]}, $_[3]
  AV* av = (AV*) SvRV($_[1]);
  av_push(av, $_[3]);
  $$ = $_[1]
}
;

ChoiceValue : identifier yytkCOLON Value
{
  // $$ = { $_[1] => $_[3] }
};

XMLChoiceValue :
yytkLESS_THAN_SIGN yytkNO_SPACE identifier yytkGREATER_THAN_SIGN
XMLValue
XML_end_tag_start_item yytkNO_SPACE identifier yytkGREATER_THAN_SIGN;



/*30 Notation for tagged types*/

TaggedType : Tag plicit Type
{
  // $$ = { val => $_[1], attrib => $_[2], type => $_[3] }
}
;

plicit : empty
| yytkEXPLICIT
| yytkIMPLICIT
;


Tag : yytkLEFT_SQUARE_BRACKET Class ClassNumber yytkRIGHT_SQUARE_BRACKET
{ 
  //$$ = { attrib => $_[3], val => $_[4] }
};

ClassNumber : number | DefinedValue ;

Class : yytkUNIVERSAL
| yytkAPPLICATION
| yytkPRIVATE
| empty
;

TaggedValue : Value;

XMLTaggedValue : XMLValue;


/*31 Notation for the object identifier type*/

ObjectIdentifierType : yytkOBJECT yytkIDENTIFIER
(-
 -)
;

ObjectIdentifierValue :
yytkLEFT_CURLY_BRACKET ObjIdComponentsList yytkRIGHT_CURLY_BRACKET
(-
 return($_[2])
-)
| yytkLEFT_CURLY_BRACKET DefinedValue ObjIdComponentsList yytkRIGHT_CURLY_BRACKET
(-
  //$$->{val} = $_[2]
  $$ = $_[3]
-)
;

ObjIdComponentsList : ObjIdComponents
(-
  return([ $_[1] ])
-)
| ObjIdComponentsList ObjIdComponents
(-
  push @{$_[1]}, $_[2]
-)
;

ObjIdComponents : NameForm
| NumberForm
| NameAndNumberForm
| DefinedValue
;

NameForm : identifier;

NumberForm : number | DefinedValue;

NameAndNumberForm :
identifier  yytkLEFT_PARENTHESIS NumberForm yytkRIGHT_PARENTHESIS
(-
  $_[1]->{form} = $_[3];
  return($_[1])
-)
;

XMLObjectIdentifierValue : XMLObjIdComponentList;
XMLObjIdComponentList : XMLObjIdComponent | XMLObjIdComponent yytkNO_SPACE yytkFULL_STOP yytkNO_SPACE XMLObjIdComponentList;
XMLObjIdComponent : NameForm | XMLNumberForm | XMLNameAndNumberForm ;
XMLNumberForm : number ;
XMLNameAndNumberForm : identifier yytkNO_SPACE  yytkLEFT_PARENTHESIS yytkNO_SPACE XMLNumberForm yytkNO_SPACE yytkRIGHT_PARENTHESIS
(-
 $_[1]->{form} = $_[5];
 return($_[1])
 -)
;


/*32 Notation for the relative object identifier type*/

RelativeOIDType : yytkRELATIVE_OID
(-
 -)
;

RelativeOIDValue : yytkLEFT_CURLY_BRACKET RelativeOIDComponentsList yytkRIGHT_CURLY_BRACKET
(-
 return($_[2])
 -)
;

RelativeOIDComponentsList :
RelativeOIDComponents
| RelativeOIDComponents RelativeOIDComponentsList
;

RelativeOIDComponents : NumberForm | NameAndNumberForm ;
XMLRelativeOIDValue : XMLRelativeOIDComponentList ;
XMLRelativeOIDComponentList :
XMLRelativeOIDComponent
| XMLRelativeOIDComponent yytkNO_SPACE yytkFULL_STOP yytkNO_SPACE XMLRelativeOIDComponentList
;
XMLRelativeOIDComponent :
XMLNumberForm
| XMLNameAndNumberForm
;


/* 33 Notation for the embedded-pdv type */

EmbeddedPDVType : yytkEMBEDDED yytkPDV
(-
 -)
;

EmbeddedPDVValue : SequenceValue;

/*34 Notation for the external type*/
ExternalType : yytkEXTERNAL {};
ExternalValue : SequenceValue;



XMLExternalValue : XMLSequenceValue;
XMLEmbeddedPDVValue : XMLSequenceValue;


/* 36 Notation for character string types*/


CharacterStringType :
RestrictedCharacterStringType
| UnrestrictedCharacterStringType
  ;


CharacterStringValue :
RestrictedCharacterStringValue
  | UnrestrictedCharacterStringValue;

UnrestrictedCharacterStringValue : SequenceValue;

XMLCharacterStringValue : XMLRestrictedCharacterStringValue
| XMLUnrestrictedCharacterStringValue
  ;

XMLUnrestrictedCharacterStringValue : XMLSequenceValue;

XMLRestrictedCharacterStringValue : xmlcstring;


/*37 Definition of restricted character string types*/

RestrictedCharacterStringType :
yytkBMPString
| yytkGeneralString
| yytkGraphicString
| yytkIA5String
| yytkISO646String
| yytkNumericString
| yytkPrintableString
| yytkTeletexString
| yytkT61String
| yytkUniversalString
| yytkUTF8String
| yytkVideotexString
| yytkVisibleString
;

RestrictedCharacterStringValue : cstring
| CharacterStringList
| Quadruple
//| Tuple
;
CharacterStringList : yytkLEFT_CURLY_BRACKET CharSyms yytkRIGHT_CURLY_BRACKET;
CharSyms : CharsDefn | CharSyms yytkCOMMA CharsDefn;

CharsDefn : cstring
| Quadruple
	    //| Tuple
| DefinedValue
;

Quadruple : yytkLEFT_CURLY_BRACKET Group yytkCOMMA Plane yytkCOMMA Row yytkCOMMA Cell yytkRIGHT_CURLY_BRACKET;
Group : number;
Plane : number;
Row   : number;
Cell  : number;


Tuple : yytkLEFT_CURLY_BRACKET TableColumn yytkCOMMA TableRow yytkRIGHT_CURLY_BRACKET;
TableColumn : number;
TableRow : number;

/*40 Definition of unrestricted character string types*/

UnrestrictedCharacterStringType : yytkCHARACTER yytkSTRING;
UsefulType : typereference;

/*42 Generalized time*/

//GeneralizedTime : [yytkUNIVERSAL 24] yytkIMPLICIT VisibleString;


/*43 Universal time*/

//UTCTime : [yytkUNIVERSAL 23] yytkIMPLICIT VisibleString;



/*45 Constrained types*/

ConstrainedType : Type Constraint
// $$ = { val => $_[2], type => $_[1] }
| TypeWithConstraint;


Constraint : yytkLEFT_PARENTHESIS ConstraintSpec ExceptionSpec yytkRIGHT_PARENTHESIS
{
  //$$ = {val => $_[1], attrib => $_[3]}
};

ConstraintSpec : SubtypeConstraint | GeneralConstraint;

SubtypeConstraint : ElementSetSpecs;

TypeWithConstraint : yytkSET Constraint yytkOF Type
		     // $$ = { attrib => $_[1], val => $_[2], type => $_[4] }
		     //etc...
| yytkSET SizeConstraint yytkOF Type
| yytkSET Constraint yytkOF NamedType
| yytkSET SizeConstraint yytkOF NamedType
| yytkSEQUENCE Constraint yytkOF Type
| yytkSEQUENCE SizeConstraint yytkOF Type
| yytkSEQUENCE Constraint yytkOF NamedType
| yytkSEQUENCE SizeConstraint yytkOF NamedType
  ;


/*46 Element set specification*/

ElementSetSpecs : RootElementSetSpec
| RootElementSetSpec yytkCOMMA Ellipsis
| RootElementSetSpec yytkCOMMA Ellipsis yytkCOMMA AdditionalElementSetSpec
;

RootElementSetSpec : ElementSetSpec;

AdditionalElementSetSpec : ElementSetSpec;

ElementSetSpec : Unions | yytkALL Exclusions ;

Unions : Intersections
| UElems UnionMark Intersections
;

UElems : Unions;

Intersections : IntersectionElements
| IElems IntersectionMark IntersectionElements;

IElems : Intersections;

IntersectionElements : Elements | Elems Exclusions;

Elems : Elements;

Exclusions : yytkEXCEPT Elements;

UnionMark : yytkVERTICAL_LINE | yytkUNION;

IntersectionMark : yytkCIRCUMFLEX_ACCENT | yytkINTERSECTION;

Elements : SubtypeElements
| ObjectSetElements
|  yytkLEFT_PARENTHESIS ElementSetSpec yytkRIGHT_PARENTHESIS
;


/*47 Subtype elements*/

SubtypeElements : SingleValue
| ContainedSubtype

| ValueRange

| PermittedAlphabet
| SizeConstraint
| TypeConstraint
| InnerTypeConstraints
| PatternConstraint
  ;

SingleValue : Value;

ValueRange : LowerEndpoint Range_separator UpperEndpoint;

LowerEndpoint : LowerEndValue | LowerEndValue yytkLESS_THAN_SIGN;

UpperEndpoint : UpperEndValue | yytkLESS_THAN_SIGN UpperEndValue;


LowerEndValue : Value | yytkMIN;

UpperEndValue : Value | yytkMAX;


SizeConstraint : yytkSIZE Constraint;

TypeConstraint : Type;

PermittedAlphabet : yytkFROM Constraint;

InnerTypeConstraints :
  yytkWITH yytkCOMPONENT SingleTypeConstraint
| yytkWITH yytkCOMPONENTS MultipleTypeConstraints;

SingleTypeConstraint : Constraint;

MultipleTypeConstraints :
FullSpecification
  | PartialSpecification;

FullSpecification : yytkLEFT_CURLY_BRACKET TypeConstraints yytkRIGHT_CURLY_BRACKET;

PartialSpecification : yytkLEFT_CURLY_BRACKET Ellipsis yytkCOMMA TypeConstraints yytkRIGHT_CURLY_BRACKET;

TypeConstraints : NamedConstraint
  | NamedConstraint yytkCOMMA TypeConstraints;

NamedConstraint : identifier ComponentConstraint;


ComponentConstraint : ValueConstraint PresenceConstraint;


ValueConstraint : Constraint | empty;

PresenceConstraint : yytkPRESENT | yytkABSENT | yytkOPTIONAL | empty;

PatternConstraint : yytkPATTERN Value;

ContainedSubtype : Includes Type;

Includes : yytkINCLUDES | empty;

/*49 The exception identifier*/

ExceptionSpec : yytkEXCLAMATION_MARK ExceptionIdentification | empty;

ExceptionIdentification :
SignedNumber
| DefinedValue
| Type yytkCOLON Value
;


EnumeratedValue : identifier;

XMLEnumeratedValue : "<" yytkNO_SPACE identifier "/>";

/*15 Information from objects*/



DefinedObjectClass :
ExternalObjectClassReference | objectclassreference | UsefulObjectClassReference
;

ExternalObjectClassReference : modulereference yytkFULL_STOP objectclassreference;

UsefulObjectClassReference :
yytkTYPE_IDENTIFIER
| yytkABSTRACT_SYNTAX
;

ObjectClassAssignment : objectclassreference Assignment_lexical_item ObjectClass;

ObjectClass : DefinedObjectClass | ObjectClassDefn | ParameterizedObjectClass;

fieldspecs: 
| FieldSpec
| FieldSpec yytkCOMMA fieldspecs
;

ObjectClassDefn :
yytkCLASS yytkLEFT_CURLY_BRACKET fieldspecs yytkRIGHT_CURLY_BRACKET WithSyntaxSpec
| yytkCLASS yytkLEFT_CURLY_BRACKET fieldspecs yytkRIGHT_CURLY_BRACKET 
;

FieldSpec :
TypeFieldSpec
| FixedTypeValueFieldSpec
| VariableTypeValueFieldSpec
| FixedTypeValueSetFieldSpec
| VariableTypeValueSetFieldSpec
| ObjectFieldSpec
| ObjectSetFieldSpec

PrimitiveFieldName :
//| typefieldreference
 valuefieldreference
| valuesetfieldreference
| objectfieldreference
| objectsetfieldreference


FieldName : PrimitiveFieldName
| PrimitiveFieldName yytkFULL_STOP FieldName
;
TypeFieldSpec :
typefieldreference 
| typefieldreference TypeOptionalitySpec
;

TypeOptionalitySpec : yytkOPTIONAL | yytkDEFAULT Type;

FixedTypeValueFieldSpec :
valuefieldreference Type
| valuefieldreference Type yytkUNIQUE
| valuefieldreference Type ValueOptionalitySpec
| valuefieldreference Type yytkUNIQUE ValueOptionalitySpec
;

ValueOptionalitySpec : yytkOPTIONAL | yytkDEFAULT Value;

VariableTypeValueFieldSpec : valuefieldreference FieldName
| valuefieldreference FieldName ValueOptionalitySpec;

FixedTypeValueSetFieldSpec : valuesetfieldreference Type
| valuesetfieldreference Type ValueSetOptionalitySpec;

ValueSetOptionalitySpec : yytkOPTIONAL | yytkDEFAULT ValueSet;

VariableTypeValueSetFieldSpec : valuesetfieldreference FieldName 
| valuesetfieldreference FieldName ValueSetOptionalitySpec;

ObjectFieldSpec : objectfieldreference DefinedObjectClass 
| objectfieldreference DefinedObjectClass ObjectOptionalitySpec
;

ObjectOptionalitySpec : yytkOPTIONAL | yytkDEFAULT Object;


ObjectSetFieldSpec : objectsetfieldreference DefinedObjectClass
| objectsetfieldreference DefinedObjectClass ObjectSetOptionalitySpec;

ObjectSetOptionalitySpec : yytkOPTIONAL | yytkDEFAULT ObjectSet;

WithSyntaxSpec : yytkWITH yytkSYNTAX SyntaxList;

SyntaxList : yytkLEFT_CURLY_BRACKET TokenOrGroupSpec empty yytkRIGHT_CURLY_BRACKET;

TokenOrGroupSpec : RequiredToken | OptionalGroup;

OptionalGroup : yytkLEFT_SQUARE_BRACKET TokenOrGroupSpec empty yytkRIGHT_SQUARE_BRACKET;

RequiredToken : Literal | PrimitiveFieldName;

Literal : word | yytkCOMMA;

DefinedObject : ExternalObjectReference | objectreference;

ExternalObjectReference : modulereference yytkFULL_STOP objectreference;

ObjectAssignment : objectreference DefinedObjectClass Assignment_lexical_item Object;

Object : DefinedObject | ObjectDefn | ObjectFromObject | ParameterizedObject;

ObjectDefn : DefaultSyntax | DefinedSyntax;

fieldsettings : FieldSetting
| FieldSetting yytkCOMMA fieldsettings
;

DefaultSyntax : yytkLEFT_CURLY_BRACKET fieldsettings yytkRIGHT_CURLY_BRACKET;

FieldSetting : PrimitiveFieldName Setting;

DefinedSyntax : yytkLEFT_CURLY_BRACKET DefinedSyntaxToken empty yytkRIGHT_CURLY_BRACKET;

DefinedSyntaxToken : Literal | Setting;

Setting : Type | Value | ValueSet | Object | ObjectSet;

DefinedObjectSet : ExternalObjectSetReference | objectsetreference;

ExternalObjectSetReference : modulereference yytkFULL_STOP objectsetreference;

ObjectSetAssignment : objectsetreference DefinedObjectClass Assignment_lexical_item ObjectSet;

ObjectSet : yytkLEFT_CURLY_BRACKET ObjectSetSpec yytkRIGHT_CURLY_BRACKET;

ObjectSetSpec :
RootElementSetSpec
| RootElementSetSpec yytkCOMMA Ellipsis
| Ellipsis
| Ellipsis yytkCOMMA AdditionalElementSetSpec
| RootElementSetSpec yytkCOMMA Ellipsis yytkCOMMA AdditionalElementSetSpec
;

ObjectSetElements : Object | DefinedObjectSet | ObjectSetFromObjects | ParameterizedObjectSet;

ObjectClassFieldType : DefinedObjectClass yytkFULL_STOP FieldName;

ObjectClassFieldValue : OpenTypeFieldVal | FixedTypeFieldVal;

OpenTypeFieldVal : Type yytkCOLON Value;

FixedTypeFieldVal : BuiltinValue | ReferencedValue;

XMLObjectClassFieldValue :
XMLOpenTypeFieldVal
| XMLFixedTypeFieldVal;

XMLOpenTypeFieldVal : XMLTypedValue;

XMLFixedTypeFieldVal : XMLBuiltinValue;

/* useless nonterminal
InformationFromObjects : ValueFromObject | ValueSetFromObjects | TypeFromObject | ObjectFromObject | ObjectSetFromObjects;
*/
ReferencedObjects :
DefinedObject | ParameterizedObject |
  DefinedObjectSet | ParameterizedObjectSet;

ValueFromObject : ReferencedObjects yytkFULL_STOP FieldName;
ValueSetFromObjects : ReferencedObjects yytkFULL_STOP FieldName;
TypeFromObject : ReferencedObjects yytkFULL_STOP FieldName;
ObjectFromObject : ReferencedObjects yytkFULL_STOP FieldName;
ObjectSetFromObjects : ReferencedObjects yytkFULL_STOP FieldName;
InstanceOfType : yytkINSTANCE yytkOF DefinedObjectClass;
InstanceOfValue : Value;
XMLInstanceOfValue : XMLValue;


/*X.682*/

GeneralConstraint : UserDefinedConstraint | TableConstraint | ContentsConstraint;

UserDefinedConstraintParameters :
empty
| UserDefinedConstraintParameter
| UserDefinedConstraintParameter "," UserDefinedConstraintParameters;

UserDefinedConstraint : yytkCONSTRAINED yytkBY "{" UserDefinedConstraintParameters "}";

UserDefinedConstraintParameter :
Governor ":" Value
| Governor ":" ValueSet
| Governor ":" Object
| Governor ":" ObjectSet
| Type
| DefinedObjectClass;


TableConstraint : SimpleTableConstraint | ComponentRelationConstraint;

SimpleTableConstraint : ObjectSet;


AtNotations :
| AtNotation
| AtNotation yytkCOMMA AtNotations;

ComponentRelationConstraint : "{" DefinedObjectSet "}" "{" AtNotations "}"


AtNotation : "@" ComponentIdList | "@" yytkFULL_STOP Level ComponentIdList;

Level : yytkFULL_STOP Level | empty;

ComponentIdList : identifier | identifier yytkFULL_STOP ComponentIdList;

ContentsConstraint :
yytkCONTAINING Type
| yytkENCODED yytkBY Value
| yytkCONTAINING Type yytkENCODED yytkBY Value;


/* X.683 */

ParameterizedAssignment :
ParameterizedTypeAssignment
| ParameterizedValueAssignment
| ParameterizedValueSetTypeAssignment
| ParameterizedObjectClassAssignment
| ParameterizedObjectAssignment
| ParameterizedObjectSetAssignment
;

ParameterizedTypeAssignment : typereference ParameterList Assignment_lexical_item Type;

ParameterizedValueAssignment : valuereference ParameterList Type Assignment_lexical_item Value

ParameterizedValueSetTypeAssignment :
typereference ParameterList Type Assignment_lexical_item ValueSet;

ParameterizedObjectClassAssignment :
objectclassreference ParameterList Assignment_lexical_item ObjectClass;

ParameterizedObjectAssignment : objectreference ParameterList DefinedObjectClass Assignment_lexical_item Object;

ParameterizedObjectSetAssignment :
objectsetreference ParameterList DefinedObjectClass Assignment_lexical_item ObjectSet;


parameters : Parameter
| Parameter yytkCOMMA parameters;

ParameterList : yytkLEFT_CURLY_BRACKET parameters yytkRIGHT_CURLY_BRACKET;

Parameter : ParamGovernor ":" DummyReference | DummyReference;

ParamGovernor : Governor | DummyGovernor;

Governor : Type | DefinedObjectClass;

DummyGovernor : DummyReference;

DummyReference : Reference;

ParameterizedReference : Reference
| Reference yytkLEFT_CURLY_BRACKET empty yytkRIGHT_CURLY_BRACKET
(-
 $_[1]->{val} = $_[3];
 return $_[1];
 -)
;

SimpleDefinedType : ExternalTypeReference | typereference;
SimpleDefinedValue : ExternalValueReference | valuereference;


// this lot is not quite right!
//$1->{type} = $2
//return $1
ParameterizedType : SimpleDefinedType ActualParameterList
(-
 return $_[2];
 -)
;
ParameterizedValue : SimpleDefinedValue ActualParameterList
(-
 return $_[2];
 -)
;
ParameterizedValueSetType : SimpleDefinedType ActualParameterList
(-
 return $_[2];
 -)
;
ParameterizedObjectClass : DefinedObjectClass ActualParameterList
(-
 return $_[2];
 -)
;
ParameterizedObjectSet : DefinedObjectSet ActualParameterList
(-
 return $_[2];
 -)
;
ParameterizedObject : DefinedObject ActualParameterList
(-
 return $_[2];
 -)
;

ActualParameters : ActualParameter
(-
 return([ $_[1] ]);
 -)
| ActualParameter  yytkCOMMA  ActualParameters
(-
 push(@{$_[3]}, $_[1]);
 return $_[3];
-)
;

ActualParameterList : yytkLEFT_CURLY_BRACKET ActualParameters yytkRIGHT_CURLY_BRACKET
(-
 return $_[2];
 -)
;

ActualParameter : Type | Value | ValueSet | DefinedObjectClass | Object | ObjectSet;

 /*11 ASN.1 lexical items*/
 //& means not space! oops
 /*except that no lower-case letters or digits shall be included.*/

objectreference : valuereference;
objectsetreference : typereference;
typefieldreference : yytkAMPERSAND typereference
(-
 return $_[2]
-)
  ;

valuefieldreference : yytkAMPERSAND valuereference
(-
 return $_[2]
-)
  ;

valuesetfieldreference : yytkAMPERSAND typereference
(-
 return $_[2]
-)
  ;

objectsetfieldreference : yytkAMPERSAND objectsetreference
(-
 return $_[2]
-)
  ;

objectfieldreference : yytkAMPERSAND objectreference
(-
 return $_[2]
-)
  ;

word : yytkWORD
(-
  return({val => $_[1]})
-)
;

objectclassreference: typereference
| word; /* only upper cases*/

typereference : yytkUWORD
(-
  return {val => $_[1]}
-)
| objectclassreference;

/* except that no lower-case letters or digits shall be included.*/

identifier : yytkLWORD
(-
  return {val => $_[1]}
-)
;

valuereference : yytkLWORD
(-
 return {val => $_[1]};
-)
;

modulereference : typereference;

comment : yytkCOMMENT
(- 
  return {val => $_[1]};
-)
;


number : yytkNUMBER
(- 
  return {val => $_[1]};
-)
;


realnumber : yytkREALNUMBER
(- 
  return {val => $_[1]};
-)
;

bstring : yytkBSTRING
(- 
  return {val => $_[1]};
-)
;

xmlbstring : yytkXMLBSTRING
(- 
 return {val => $_[1]}
 -)
;

hstring : yytkHSTRING
(- 
 return {val => $_[1]}
 -)
;


cstring : yytkCSTRING
(- 
 return {val => $_[1]}
 -)
;


xmlhstring : yytkXMLHSTRING
(- 
 return {val => $_[1]}
 -)
| yytkXMLBSTRING
(- 
 return {val => $_[1]}
 -)
;

xmlcstring : yytkXMLCSTRING
(- 
 return {val => $_[1] }
 -)
| xmlhstring ;

xmlasn1typename: typereference;


Assignment_lexical_item : yytkSEMICOLON yytkNO_SPACE yytkSEMICOLON yytkNO_SPACE yytkEQUALS_SIGN;

Range_separator : yytkFULL_STOP yytkNO_SPACE yytkFULL_STOP;
XML_end_tag_start_item : yytkLESS_THAN_SIGN yytkNO_SPACE yytkSOLIDUS;
XML_single_tag_end_item : yytkSOLIDUS yytkNO_SPACE yytkGREATER_THAN_SIGN;
Ellipsis : yytkFULL_STOP yytkNO_SPACE yytkFULL_STOP yytkNO_SPACE yytkFULL_STOP;
Left_version_brackets  : yytkLEFT_SQUARE_BRACKET yytkNO_SPACE yytkLEFT_SQUARE_BRACKET;
Right_version_brackets : yytkRIGHT_SQUARE_BRACKET yytkNO_SPACE yytkRIGHT_SQUARE_BRACKET;

XML_boolean_true_item : "true";
XML_boolean_false_item : "false";

empty :    ;

%%
