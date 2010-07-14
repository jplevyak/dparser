# 
# 
# THIS MATERIAL IS PROVIDED AS IS, WITH ABSOLUTELY NO WARRANTY EXPRESSED
# OR IMPLIED.  ANY USE IS AT YOUR OWN RISK.
# 
# Permission is hereby granted to use or copy this program
# for any purpose,  provided the above notices are retained on all copies.
# Permission to modify the code and to distribute modified code is granted,
# provided the above notices are retained, and a notice that the code was
# modified is included with the above copyright notice.
#
# Modified by: 

# DPARSER_DISABLE_GC
# sets USE_GC, GC_LIB
#


# Garbage Collector
# -----------------
AC_DEFUN([DPARSER_DISABLE_GC],[
default=$1
if test "x$default" = x ; then
  default="yes"
fi
AH_TEMPLATE([USE_GC], [are we using a GNU- sofisticated Garbage Collector.])
AC_CHECK_HEADER([gc.h],dnl
    [
    dnl gcc -o conftest.exe -g -O2   conftest.c -lgc   >&5
    dnl this is the command to link and it does not work
      dp_ldflags=$LDFLAGS
      LDFLAGS="-L/usr/local/lib -L/usr/lib $LDFLAGS"
      AC_CHECK_LIB([gc], [GC_get_version],
        [ac_is_gc=yes],dnl
        [
          ac_is_gc=no
      	  AC_MSG_RESULT([GC could not be linked. not using GC.])
        ])
      LDFLAGS=$dp_ldflags
    ],dnl
    [ac_is_gc=no]
)
AC_ARG_ENABLE([garbage-collector],
  [AS_HELP_STRING([--disable-garbage-collector], [wether to disable the use of a garbage collector])],
  [AS_IF([test "x${enable_garbage_collector}" = xno], [ac_is_gc=no])]
)
AS_IF([test "x${ac_is_gc}" = xyes],
  [
    AC_MSG_RESULT([Garbage Collector GC will be used.])
    AC_DEFINE([USE_GC], [1], [we are using the state of art, sofisticated Garbage Collector.])
    AC_SUBST([GC_LIB], [-lgc])    
    dnl AM_CONDITIONAL([DPARSER_USE_GC], [1])
  ]
)
dnl TODO:CPM100620 add possibly a -L/usr/local/lib need examples...
])

#sinclude(libtool.m4)
