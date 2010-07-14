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

# DPARSER_SET_VERSION
# sets and AC_DEFINEs DPARSER_VERSION_MAJOR, DPARSER_VERSION_MINOR and DPARSER_ALPHA_VERSION
# based on the contents of PACKAGE_VERSION; PACKAGE_VERSION must conform to
# [0-9]+[.][0-9]+(alpha[0.9]+)? 
# in lex syntax; if there is no alpha number, DPARSER_ALPHA_VERSION is empty
#
AC_DEFUN([DPARSER_SET_VERSION], [
  AC_MSG_CHECKING(DPARSER version numbers)
  DPARSER_VERSION_MAJOR=`echo $PACKAGE_VERSION | sed 's/^\([[0-9]][[0-9]]*\)[[.]].*$/\1/g'`
  DPARSER_VERSION_MINOR=`echo $PACKAGE_VERSION | sed 's/^[[^.]]*[[.]]\([[0-9]][[0-9]]*\).*$/\1/g'`
  DPARSER_ALPHA_VERSION=`echo $PACKAGE_VERSION | sed 's/^[[^.]]*[[.]][[0-9]]*[[.]]//'`

  case "$DPARSER_ALPHA_VERSION" in
    alpha*) 
      DPARSER_ALPHA_VERSION=`echo $DPARSER_ALPHA_VERSION \
      | sed 's/alpha\([[0-9]][[0-9]]*\)/\1/'` ;;
    *)  DPARSER_ALPHA_MAJOR='' ;;
  esac

  if test :$DPARSER_VERSION_MAJOR: = :: \
     -o   :$DPARSER_VERSION_MINOR: = :: ;
  then
    AC_MSG_RESULT(invalid)
    AC_MSG_ERROR([nonconforming PACKAGE_VERSION='$PACKAGE_VERSION'])
  fi
  
  AC_DEFINE_UNQUOTED([DPARSER_VERSION_MAJOR], $DPARSER_VERSION_MAJOR,
		     [The major version number of this release.])
  AC_DEFINE_UNQUOTED([DPARSER_VERSION_MINOR], $DPARSER_VERSION_MINOR,
		     [The minor version number of this release.])
  if test :$DPARSER_ALPHA_VERSION: != :: ; then
    AC_DEFINE_UNQUOTED([DPARSER_ALPHA_VERSION], $DPARSER_ALPHA_VERSION,
		       [The alpha version number, if applicable.])
  fi
  AC_MSG_RESULT(major=$DPARSER_VERSION_MAJOR minor=$DPARSER_VERSION_MINOR \
${DPARSER_ALPHA_VERSION:+alpha=}$DPARSER_ALPHA_VERSION)
])

sinclude(libtool.m4)
