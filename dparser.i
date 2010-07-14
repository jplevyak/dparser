// $Id$
//
// $Log$
//
#if defined SWIGPERL

%module Parser::D


/*TYPEMAP perl->C */
%typemap(in) T_PTROBJ {
  $1 = $input;
 }

/*TYPEMAP C->perl */
%typemap(out)  T_PTROBJ {
  $result = $1;
 }

%apply T_PTROBJ {
  Grammar*, D_ReductionCode, Parser*, D_ParseNode_Globals*, D_ReductionCode, Parser*,
    D_ParseNode_Globals*,D_ParseNode_User*,D_ParseNode*,D_ParserTables*,user_plobjects*,d_loc_t*
    };

%include Dxs.h




#elif defined SWIGPYTHON
/* http://www.swig.org/Doc1.1/HTML/Python.html#n11 */
%module dparser

%include typemaps.i
%include cmalloc.i

%{
#include "pydparser.h"
%}

%typemap(in) PyObject* {
  $1 = $input;
}
%typemap(out) PyObject* {
  $result = $1;
}

%include pydparser.h

#elif defined SWIGRUBY
#elif defined SWIGTCL
#else
#warning "no callbacks for this language"
#error
#endif


