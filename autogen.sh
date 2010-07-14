#!/bin/sh

autoreconf --verbose --install

#libtoolize --automake
#aclocal -I m4
#automake --add-missing --gnu
#autoconf
# don't use any old cache, but create a new one
#--enable-maintainer-mode
#rm -f config.cache
./configure --enable-debug --enable-leak-detect --enable-maintainer-mode "$@"
