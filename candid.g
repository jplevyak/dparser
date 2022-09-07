prog: def* actor?;
def
  : 'type' id '=' datatype ';'
  | 'import' text ';';
actor : 'service' id? ':' (tuptype '->')? (actortype | id);

actortype: '{' methtype* '}';
methtype: name ':' (functype | id) ';';
functype: tuptype '->' tuptype funcann*;
funcann: 'oneway' | 'query';
tuptype: '(' ((argtype ',')* argtype)? ')';
argtype: datatype | name ':' datatype;

recordfieldtype
  : nat ':' datatype
  | name ':' datatype
  | datatype // N : datatyp where N is 0 or previous + 1 (only in records)
  ;
variantfieldtype
  : nat ':' datatype
  | name ':' datatype
  | nat      // nat : null (only in variants)
  | name     // name: Null (only in varants)
  ;
datatype: id | primtype | comptype;
comptype: constype | reftype;

primtype
  : numtype
  | 'bool'
  | 'text'
  | 'null'
  | 'reserved'
  | 'empty'
  | 'principal'
  ;

numtype
  : 'nat' | 'nat8' | 'nat16' | 'nat32' | 'nat64'
  | 'int' | 'int8' | 'int16' | 'int32' | 'int64'
  | 'float32' | 'float64'
  ;

constype
  : 'opt' datatype
  | 'vec' datatype
  | 'record' '{' (recordfieldtype ';')* '}'
  | 'variant' '{' (variantfieldtype ';')* '}'
  | 'blob' // vec nat8
  ;

reftype
  : 'func' functype
  | 'service' actortype
  ;

name: id | text;

id: "[A-Za-z_][A-Za-z_-1-9]*" $term -1;
text ::= "\"[^\"]*\"";

digit ::= "[0-9]";
hex ::= digit | "[A-Fa-f]";
num ::= digit('_'? digit)*;
hexnum ::= hex('_'? hex)*;
nat ::= num | '0x' hexnum;
