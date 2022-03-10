// Author(s): Wieger Wesselink
// Copyright: see the accompanying file COPYING or copy at
// https://github.com/mCRL2org/mCRL2/blob/master/COPYING
//
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//
/// \file mcrl2-syntax.g
/// \brief dparser grammar of the mCRL2 language

${declare tokenize}
${declare longest_match}

mCRL2Spec: mCRL2SpecElt* Init mCRL2SpecElt* ;                    // MCRL2 specification

//--- Sort expressions and sort declarations

SortExpr
  : 'Bool'                                                       // Booleans
  | 'Pos'                                                        // Positive numbers
  | 'Nat'                                                        // Natural numbers
  | 'Int'                                                        // Integers
  | 'Real'                                                       // Reals
  | 'List' '(' SortExpr ')'                                      // List sort
  | 'Set' '(' SortExpr ')'                                       // Set sort
  | 'Bag' '(' SortExpr ')'                                       // Bag sort
  | 'FSet' '(' SortExpr ')'                                      // Finite set sort
  | 'FBag' '(' SortExpr ')'                                      // Finite bag sort
  | Id                                                           // Sort reference
  | '(' SortExpr ')'                                             // Sort expression with parentheses
  | 'struct' ConstrDeclList                                      // Structured sort
  | SortExpr ('->' $binary_op_right 0) SortExpr                  // Function sort
  | SortExpr ('#' $binary_op_left 1) SortExpr                    // Product sort
  ;

SortProduct : SortExpr ;                                         // SortExpr in which # is allowed as top-level operator

SortSpec: 'sort' SortDecl+ ;                                     // Sort specification

SortDecl
  : IdList ';'                                                   // List of sort identifiers
  | Id '=' SortExpr ';'                                          // Sort alias
  ;

ConstrDecl: Id ( '(' ProjDeclList ')' )? ( '?' Id )? ;           // Constructor declaration

ConstrDeclList: ConstrDecl ( '|' ConstrDecl )* ;                 // Constructor declaration list

ProjDecl: ( Id ':' )? SortExpr ;                                 // Domain with optional projection

ProjDeclList: ProjDecl ( ',' ProjDecl )* ;                       // Declaration of projection functions

//--- Constructors and mappings

IdsDecl: IdList ':' SortExpr ;                                   // Typed parameters

ConsSpec: 'cons' ( IdsDecl ';' )+ ;                              // Declaration of constructors

MapSpec: 'map' ( IdsDecl ';' )+ ;                                // Declaration of mappings

//--- Equations

GlobVarSpec: 'glob' ( VarsDeclList ';' )+ ;                      // Declaration of global variables

VarSpec: 'var' ( VarsDeclList ';' )+ ;                           // Declaration of variables

EqnSpec: VarSpec? 'eqn' EqnDecl+ ;                               // Definition of equations

EqnDecl: (DataExpr '->')? DataExpr '=' DataExpr ';' ;            // Conditional equation

//--- Data expressions

VarDecl: Id ':' SortExpr ;                                       // Typed variable

VarsDecl: IdList ':' SortExpr ;                                  // Typed variables

VarsDeclList: VarsDecl ( ',' VarsDecl )* ;                       // Individually typed variables

DataExpr
  : Id                                                           // Identifier
  | Number                                                       // Number
  | 'true'                                   $left        20     // True
  | 'false'                                  $left        20     // False
  | '[' ']'                                  $left        20     // Empty list
  | '{' '}'                                  $left        20     // Empty set
  | '{'':''}'                                $left        20     // Empty bag
  | '[' DataExprList ']'                     $left        20     // List enumeration
  | '{' BagEnumEltList '}'                   $left        20     // Bag enumeration
  | '{' VarDecl '|' DataExpr '}'             $left        20     // Set/bag comprehension
  | '{' DataExprList '}'                     $left        20     // Set enumeration
  | '(' DataExpr ')'                         $left        50     // Brackets
  | DataExpr '[' DataExpr '->' DataExpr ']'  $unary_left  13     // Function update
  | DataExpr '(' DataExprList ')'            $unary_left  13     // Function application
  | '!' DataExpr                             $unary_right 12     // Negation, set complement
  | '-' DataExpr                             $unary_right 12     // Unary minus
  | '#' DataExpr                             $unary_right 12     // Size of a list
  | 'forall' VarsDeclList '.' DataExpr       $unary_right  1     // Universal quantifier
  | 'exists' VarsDeclList '.' DataExpr       $unary_right  1     // Existential quantifier
  | 'lambda' VarsDeclList '.' DataExpr       $unary_right  1     // Lambda abstraction
  | DataExpr ('=>' $binary_op_right 2) DataExpr                  // Implication
  | DataExpr ('||' $binary_op_right 3) DataExpr                  // Disjunction
  | DataExpr ('&&' $binary_op_right 4) DataExpr                  // Conjunction
  | DataExpr ('==' $binary_op_left 5) DataExpr                   // Equality
  | DataExpr ('!=' $binary_op_left 5) DataExpr                   // Inequality
  | DataExpr ('<' $binary_op_left 6) DataExpr                    // Smaller
  | DataExpr ('<=' $binary_op_left 6) DataExpr                   // Smaller equal
  | DataExpr ('>=' $binary_op_left 6) DataExpr                   // Larger equal
  | DataExpr ('>' $binary_op_left 6) DataExpr                    // Larger
  | DataExpr ('in' $binary_op_left 6) DataExpr                   // Set, bag, list membership
  | DataExpr ('|>' $binary_op_right 7) DataExpr                  // List cons
  | DataExpr ('<|' $binary_op_left 8) DataExpr                   // List snoc
  | DataExpr ('++' $binary_op_left 9) DataExpr                   // List concatenation
  | DataExpr ('+' $binary_op_left 10) DataExpr                   // Addition, set/bag union
  | DataExpr ('-' $binary_op_left 10) DataExpr                   // Subtraction, set/bag difference
  | DataExpr ('/' $binary_op_left 11) DataExpr                   // Division
  | DataExpr ('div' $binary_op_left 11) DataExpr                 // Integer div
  | DataExpr ('mod' $binary_op_left 11) DataExpr                 // Integer mod
  | DataExpr ('*' $binary_op_left 12) DataExpr                   // Multiplication, set/bag intersection
  | DataExpr ('.' $binary_op_left 12) DataExpr                   // List element at position
  | DataExpr 'whr' AssignmentList 'end'      $unary_left 0       // Where clause
  ;

DataExprUnit
  : Id                                                           // Identifier
  | Number                                                       // Number
  | 'true'                                                       // True
  | 'false'                                                      // False
  | '(' DataExpr ')'                                             // Bracket
  | DataExprUnit '(' DataExprList ')'        $unary_left  14     // Function application
  | '!' DataExprUnit                         $unary_right 13     // Negation, set complement
  | '-' DataExprUnit                         $unary_right 13     // Unary minus
  | '#' DataExprUnit                         $unary_right 13     // Size of a list
  ;

Assignment: Id '=' DataExpr ;                                    // Assignment

AssignmentList: Assignment ( ',' Assignment )* ;                 // Assignment list

DataExprList: DataExpr ( ',' DataExpr )* ;                       // Data expression list

BagEnumElt: DataExpr ':' DataExpr ;                              // Bag element with multiplicity

BagEnumEltList: BagEnumElt ( ',' BagEnumElt )* ;                 // Elements in a finite bag

//--- Communication and renaming sets

ActIdSet: '{' IdList '}' ;                                       // Action set

MultActId: Id ( '|' Id )* ;                                      // Multi-action label

MultActIdList: MultActId ( ',' MultActId )* ;                    // Multi-action labels

MultActIdSet: '{' MultActIdList? '}' ;                           // Multi-action label set

CommExpr: Id '|' MultActId '->' Id ;                             // Action synchronization

CommExprList: CommExpr ( ',' CommExpr )* ;                       // Action synchronizations

CommExprSet: '{' CommExprList? '}' ;                             // Action synchronization set

RenExpr: Id '->' Id ;                                            // Action renaming

RenExprList: RenExpr ( ',' RenExpr )* ;                          // Action renamings

RenExprSet: '{' RenExprList? '}' ;                               // Action renaming set

//--- Process expressions

ProcExpr
  : Action                                                       // Action or process instantiation
  | Id '(' AssignmentList? ')'                                   // Process assignment
  | 'delta'                                                      // Delta, deadlock, inaction
  | 'tau'                                                        // Tau, hidden action, empty multi-action
  | 'block' '(' ActIdSet ',' ProcExpr ')'                        // Block or encapsulation operator
  | 'allow' '(' MultActIdSet ',' ProcExpr ')'                    // Allow operator
  | 'hide' '(' ActIdSet ',' ProcExpr ')'                         // Hiding operator
  | 'rename' '(' RenExprSet ',' ProcExpr ')'                     // Action renaming operator
  | 'comm' '(' CommExprSet ',' ProcExpr ')'                      // Communication operator
  | '(' ProcExpr ')'                                             // Brackets
  | ProcExpr ('+' $binary_op_left 1) ProcExpr                    // Choice operator
  | ('sum' VarsDeclList '.' $unary_op_right 2) ProcExpr          // Sum operator
  | ProcExpr ('||' $binary_op_right 3) ProcExpr                  // Parallel operator
  | ProcExpr ('||_' $binary_op_right 4) ProcExpr                 // Leftmerge operator
  | (DataExprUnit '->' $unary_op_right 5) ProcExpr               // If-then operator
  | ((DataExprUnit '->' $unary_op_right 6) ProcExpr              // If-then-else operator
                   '<>' $unary_op_right 5) ProcExpr
  | ProcExpr ('<<' $binary_op_left 8) ProcExpr                   // Until operator
  | ProcExpr ('.' $binary_op_right 9) ProcExpr                   // Sequential composition operator
  | ProcExpr ('@' $binary_op_left 10) DataExprUnit               // At operator
  | ProcExpr ('|' $binary_op_left 11) ProcExpr                   // Communication merge
  | ('dist' VarsDeclList '[' DataExpr ']'
              '.' $unary_op_right 2) ProcExpr                    // Distribution operator
  ;

//--- Actions

Action: Id ( '(' DataExprList ')' )? ;                           // Action, process instantiation

ActDecl: IdList ( ':' SortProduct )? ';' ;                       // Declarations of actions

ActSpec: 'act' ActDecl+ ;                                        // Action specification

MultAct
  : 'tau'                                                        // Tau, hidden action, empty multi-action
  | ActionList                                                   // Multi-action
  ;

ActionList: Action ( '|' Action )* ;                             // List of actions

//--- Process and initial state declaration

ProcDecl: Id ( '(' VarsDeclList ')' )? '=' ProcExpr ';' ;        // Process declaration

ProcSpec: 'proc' ProcDecl+ ;                                     // Process specification

Init: 'init' ProcExpr ';' ;                                      // Initial process

//--- Data specification

DataSpec: ( SortSpec | ConsSpec | MapSpec | EqnSpec )+ ;         // Data specification

//--- mCRL2 specification

mCRL2SpecElt
  : SortSpec                                                     // Sort specification
  | ConsSpec                                                     // Constructor specification
  | MapSpec                                                      // Map specification
  | EqnSpec                                                      // Equation specification
  | GlobVarSpec                                                  // Global variable specification
  | ActSpec                                                      // Action specification
  | ProcSpec                                                     // Process specification
  ;

//--- Boolean equation system

BesSpec: BesEqnSpec BesInit ;                                    // Boolean equation system

BesEqnSpec: 'bes' BesEqnDecl+ ;                                  // Boolean equation declaration

BesEqnDecl: FixedPointOperator BesVar '=' BesExpr ';' ;          // Boolean fixed point equation

BesVar: Id ;                                                     // BES variable

BesExpr
  : BesVar                                                       // Boolean variable
  | 'true'                                                       // True
  | 'false'                                                      // False
  | BesExpr ('=>' $binary_op_right 2) BesExpr                    // Implication
  | BesExpr ('||' $binary_op_right 3) BesExpr                    // Disjunction
  | BesExpr ('&&' $binary_op_right 4) BesExpr                    // Conjunction
  | '!' BesExpr              $unary_right  5                     // Negation
  | '(' BesExpr ')'                                              // Brackets
  ;

BesInit: 'init' BesVar ';' ;                                     // Initial BES variable

//--- Parameterized Boolean equation systems

PbesSpec: DataSpec? GlobVarSpec? PbesEqnSpec PbesInit ;          // PBES specification

PbesEqnSpec: 'pbes' PbesEqnDecl+ ;                               // Declaration of PBES equations

PbesEqnDecl: FixedPointOperator PropVarDecl '=' PbesExpr ';' ;   // PBES equation

FixedPointOperator
  : 'mu'                                                         // Minimal fixed point operator
  | 'nu'                                                         // Maximal fixed point operator
  ;

PropVarDecl: Id ( '(' VarsDeclList ')' )? ;                      // PBES variable declaration

PropVarInst: Id ( '(' DataExprList ')' )? ;                      // Instantiated PBES variable

PbesInit: 'init' PropVarInst ';' ;                               // Initial PBES variable

DataValExpr: 'val' '(' DataExpr ')' $left 20 ;                   // Marked data expression

PbesExpr
  :
  DataValExpr                                                  // Boolean data expression
//| DataExpr                                                     // Boolean data expression
  | '(' PbesExpr ')'                           $left        50   // Brackets
  | 'true'                                     $left        30   // True
  | 'false'                                    $left        30   // False
  | Id ( '(' DataExprList ')' )?               $left        30   // Instantiated PBES variable or data application
  | 'forall' VarsDeclList '.' PbesExpr         $unary_right 21   // Universal quantifier
  | 'exists' VarsDeclList '.' PbesExpr         $unary_right 21   // Existential quantifier
  | PbesExpr ('=>' $binary_op_right 22) PbesExpr                 // Implication
  | PbesExpr ('||' $binary_op_right 23) PbesExpr                 // Disjunction
  | PbesExpr ('&&' $binary_op_right 24) PbesExpr                 // Conjunction
  | '!' PbesExpr                               $unary_right 25   // Negation
  ;

//--- Action formulas

ActFrm
  : DataValExpr                                                  // Boolean data expression
//| DataExpr                                                     // Boolean data expression
  | MultAct                                                      // Multi-action
  | '(' ActFrm ')'                             $left        50   // Brackets
  | 'true'                                     $left        30   // True
  | 'false'                                    $left        30   // False
  | 'forall' VarsDeclList '.' ActFrm           $unary_right 21   // Universal quantifier
  | 'exists' VarsDeclList '.' ActFrm           $unary_right 21   // Existential quantifier
  | ActFrm ('=>' $binary_op_right 22) ActFrm                     // Implication
  | ActFrm ('||' $binary_op_right 23) ActFrm                     // Union of actions
  | ActFrm ('&&' $binary_op_right 24) ActFrm                     // Intersection of actions
  | ActFrm ('@' $binary_op_left 25) DataExpr                     // At operator
  | '!' ActFrm                                 $unary_right 26   // Negation
  ;

//--- Regular formulas

RegFrm
  : ActFrm                                                       // Action formula
  | '(' RegFrm ')'                             $left        50   // Brackets
  | RegFrm ('+' $binary_op_left 31) RegFrm                       // Alternative composition
  | RegFrm ('.' $binary_op_right 32) RegFrm                      // Sequential composition
  | RegFrm '*'                                 $unary_right 33   // Iteration
  | RegFrm '+'                                 $unary_right 33   // Nonempty iteration
  ;

//--- State formula specification

StateFrmSpec
  : StateFrm                                                     // Single state formula
  | (StateFrmSpecElt*) FormSpec (StateFrmSpecElt*)               // State formula specification
  ;

FormSpec : 'form' StateFrm ';' ;

StateFrmSpecElt
  : SortSpec                                                     // Sort specification
  | ConsSpec                                                     // Constructor specification
  | MapSpec                                                      // Map specification
  | EqnSpec                                                      // Equation specification
  | ActSpec                                                      // Action specification
  ;

StateFrm
  : DataValExpr                                                  // Boolean data expression
//| DataExpr                                                     // Boolean data expression
  | '(' StateFrm ')'                           $left        50   // Brackets
  | 'true'                                     $left        50   // True
  | 'false'                                    $left        50   // False
  | Id ( '(' DataExprList ')' )?               $left        50   // Instantiated PBES variable
  | 'delay' ( '@' DataExpr )?                  $left        50   // Delay
  | 'yaled' ( '@' DataExpr )?                  $left        50   // Yaled
  | 'mu' StateVarDecl '.' StateFrm             $unary_right 41   // Minimal fixed point
  | 'nu' StateVarDecl '.' StateFrm             $unary_right 41   // Maximal fixed point
  | 'forall' VarsDeclList '.' StateFrm         $unary_right 42   // Universal quantification
  | 'exists' VarsDeclList '.' StateFrm         $unary_right 42   // Existential quantification
  | StateFrm ('=>' $binary_op_right 43) StateFrm                 // Implication
  | StateFrm ('||' $binary_op_right 44) StateFrm                 // Disjunction
  | StateFrm ('&&' $binary_op_right 45) StateFrm                 // Conjunction
  | '[' RegFrm ']' StateFrm                    $unary_right 46   // Box modality
  | '<' RegFrm '>' StateFrm                    $unary_right 46   // Diamond modality
  | '!' StateFrm                               $unary_right 47   // Negation
  ;

StateVarDecl: Id ( '(' StateVarAssignmentList ')' )? ;           // PBES variable declaration

StateVarAssignment: Id ':' SortExpr '=' DataExpr ;               // Typed variable with initial value

StateVarAssignmentList: StateVarAssignment ( ',' StateVarAssignment )* ;  // Typed variable list

//--- Action Rename Specifications

ActionRenameSpec: (SortSpec | ConsSpec | MapSpec | EqnSpec | ActSpec | ActionRenameRuleSpec)+ ; // Action rename specification

ActionRenameRuleSpec: VarSpec? 'rename' ActionRenameRule+ ;      // Action rename rule section

ActionRenameRule: (DataExpr '->')? Action '=>' ActionRenameRuleRHS ';' ; // Conditional action renaming

ActionRenameRuleRHS
  : Action                                                       // Action
  | 'tau'                                                        // Tau, hidden action, empty multi-action
  | 'delta'                                                      // Delta, deadlock, inaction
  ;

//--- Identifiers

IdList: Id ( ',' Id )* ;                                         // List of identifiers

Id: "[A-Za-z_][A-Za-z_0-9']*" $term -1 ;                         // Identifier

Number: "0|([1-9][0-9]*)" $term -1 ;                             // Number

//--- Whitespace

whitespace: "([ \t\n\r]|(%[^\n\r]*))*" ;                         // Whitespace
