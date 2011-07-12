#!/bin/sh
#set -xv
#unset D_USE_FREELISTS for best valgrind results
#setenv VALGRIND 'valgrind -q '
VALGRIND=' '
MAKE=${MAKE:-make}

cp -auv BUILD_VERSION Makefile *.h *.cpp grammar.g tests
$MAKE -C tests -s make_dparser
$MAKE -C tests gram
$MAKE -C tests -s make_dparser

cd tests

tests=`ls *.g`
failed=0

for g in *.test.g
do
  rm -f sample_parser
  if [ -e $g.flags ] ; then
    flags=`cat $g.flags`
  else
    flags= 
  fi
  $VALGRIND ./make_dparser $flags $g
  $MAKE -s sample_parser SAMPLE_GRAMMAR=$g
  for t in $g.[0-9] $g.[0-9][0-9]
  do
    if [ ! -e $t ] ; then
      continue
    fi
    if [ -e $t.flags ] ; then
      flags=`cat $t.flags`
    else
      flags= 
    fi
    $VALGRIND ./sample_parser $flags -v $t > $t.out
    #dos2unix $t.out
    diff -db $t.out $t.check
    if [ $? -ne 0 ] ; then
      echo $t "******** FAILED ********"
      failed=`expr $failed + 1`
    else
      echo $t "PASSED"
    fi
  done
done
echo "---------------------------------------"
if [ $failed -eq 0 ] ; then
  echo "ALL tests PASSED"
else
  echo "********" $failed "test(s) FAILED *********"
fi
#rm -vf sample_parser BUILD_VERSION Makefile *.c *.h *.o *.cpp make_dparser make_dparser.exe libdparse.a grammar.g
cd ..
