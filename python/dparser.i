// $Id$
//
// $Log$
//
%module dparser

%include typemaps.i
%include cmalloc.i


#if defined SWIGPERL
#elif defined SWIGPYTHON
/* http://www.swig.org/Doc1.1/HTML/Python.html#n11 */

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
#endif

