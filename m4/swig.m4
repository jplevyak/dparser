
dnl
dnl From autoconf-archive, should be in macros dir
dnl
AC_DEFUN([AC_PROG_SWIG],[
	AC_PATH_PROG([SWIG],[swig])
	if test -z "$SWIG" ; then
	   AC_MSG_WARN([cannot find 'swig' program. You should look at http://www.swig.org])
	   SWIG='echo "Error: SWIG is not installed. You should look at http://www.swig.org" ; false'
	elif test -n "$1" ; then
	   AC_MSG_CHECKING([for SWIG version])
	   [swig_version=`$SWIG -version 2>&1 | grep 'SWIG Version' | sed 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/g'`]
	   AC_MSG_RESULT([$swig_version])
	   if test -n "$swig_version" ; then
# Calculate the required version number components
  	    	[required=$1]
		[required_major=`echo $required | sed 's/[^0-9].*//'`]
		if test -z "$required_major" ; then
		   [required_major=0]
		fi
		[required=`echo $required | sed 's/[0-9]*[^0-9]//'`]
		[required_minor=`echo $required | sed 's/[^0-9].*//'`]
		if test -z "$required_minor" ; then
		   [required_minor=0]
		   fi
		[required=`echo $required | sed 's/[0-9]*[^0-9]//'`]
		[required_patch=`echo $required | sed 's/[^0-9].*//'`]
		if test -z "$required_patch" ; then
		   [required_patch=0]
		fi
# Calculate the available version number components
		[available=$swig_version]
		[available_major=`echo $available | sed 's/[^0-9].*//'`]
		if test -z "$available_major" ; then
		   [available_major=0]
		   fi
		[available=`echo $available | sed 's/[0-9]*[^0-9]//'`]
		[available_minor=`echo $available | sed 's/[^0-9].*//'`]
		if test -z "$available_minor" ; then
		   [available_minor=0]
		fi
		[available=`echo $available | sed 's/[0-9]*[^0-9]//'`]
		[available_patch=`echo $available | sed 's/[^0-9].*//'`]
		if test -z "$available_patch" ; then
		   [available_patch=0]
		fi
		if test $available_major -ne $required_major \
		   -o $available_minor -ne $required_minor \
		   -o $available_patch -lt $required_patch ; then
		   AC_MSG_WARN([SWIG version >= $1 is required. You have $swig_version. You should look at http://www.swig.org])
		   SWIG='echo "Error: SWIG version >= $1 is required. You have '"$swig_version"'. You should look at http://www.swig.org" ; false'
		else
		   AC_MSG_NOTICE([SWIG executable is '$SWIG'])
		   SWIG_LIB=`$SWIG -swiglib`
		   AC_MSG_NOTICE([SWIG library directory is '$SWIG_LIB'])
		fi
	   else
		AC_MSG_WARN([cannot determine SWIG version])
		SWIG='echo "Error: Cannot determine SWIG version. You should look at http://www.swig.org" ; false'
	   fi
	 fi
	 AC_SUBST([SWIG_LIB])
])


# SWIG_ENABLE_CXX()
#
# Enable SWIG C++ support. This affects all invocations of $(SWIG).
AC_DEFUN([SWIG_ENABLE_CXX],[
	AC_REQUIRE([AC_PROG_SWIG])
	AC_REQUIRE([AC_PROG_CXX])
	SWIG="$SWIG -c++"
])

