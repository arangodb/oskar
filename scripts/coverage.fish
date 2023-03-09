#!/usr/bin/env fish
set -l c 0

cd $INNERWORKDIR
and rm -rf combined
and mkdir combined
and python3 "$WORKSPACE/jenkins/helper/aggregate_coverage.py" $INNERWORKDIR/gcov $INNERWORKDIR/combined/result

and echo "creating gcno tar"
and pushd ArangoDB/build
and tar c -f /tmp/gcno.tar (find . -name "*.gcno")
and popd
and echo "copying gcno files"
and tar x -f /tmp/gcno.tar -C $INNERWORKDIR/combined/result

and rm -rf coverage
and mkdir coverage
and mkdir coverage/utils/gdb-pretty-printers/immer/test
and mkdir coverage/enterprise
and ln -s $INNERWORKDIR/ArangoDB/3rdParty/jemalloc/v*/include $INNERWORKDIR/ArangoDB/include
and gcovr --exclude-throw-branches --root $INNERWORKDIR/ArangoDB \
        -x \
        -e $INNERWORKDIR/ArangoDB/build \
        -e $INNERWORKDIR/ArangoDB/build/3rdParty/libunwind/v* \
        -e $INNERWORKDIR/ArangoDB/build/3rdParty/libunwind/v*/src/ \
        -e $INNERWORKDIR/ArangoDB/3rdParty \
        -e $INNERWORKDIR/ArangoDB/3rdParty/jemalloc/v*/ \
        -e $INNERWORKDIR/ArangoDB/usr/ \
        -e $INNERWORKDIR/ArangoDB/tests \
        -o coverage/coverage.xml \
        --exclude-lines-by-pattern "TRI_ASSERT" \
        --print-summary \
        $INNERWORKDIR/combined/result > $INNERWORKDIR/coverage/summary.txt
and cat coverage/coverage.xml \
      | sed -e "s:filename=\":filename=\"./coverage/:g" \
      > $INNERWORKDIR/coverage/coverage.xml.tmp
and mv $INNERWORKDIR/coverage/coverage.xml $INNERWORKDIR/coverage/coverage.org.xml
and mv $INNERWORKDIR/coverage/coverage.xml.tmp $INNERWORKDIR/coverage/coverage.xml
and for d in lib arangosh client-tools arangod enterprise/Enterprise
  if test -d $INNERWORKDIR/ArangoDB/$d
  	echo "cp -a $INNERWORKDIR/ArangoDB/$d $INNERWORKDIR/coverage/$d"
  	cp -a $INNERWORKDIR/ArangoDB/$d $INNERWORKDIR/coverage/$d
  end
end
and if test -d $INNERWORKDIR/ArangoDB/enterprise/tests
        echo "cp -a $INNERWORKDIR/ArangoDB/enterprise/tests $INNERWORKDIR/coverage/enterprise/tests"
        cp -a $INNERWORKDIR/ArangoDB/enterprise/tests $INNERWORKDIR/coverage/enterprise/tests
    end
and if test -d $INNERWORKDIR/ArangoDB/utils/gdb-pretty-printers
    echo "cp -a $INNERWORKDIR/ArangoDB/utils/gdb-pretty-printers/immer/test/flex_vector_test.cpp $INNERWORKDIR/coverage/utils/gdb-pretty-printers/immer/test/flex_vector_test.cpp"
    cp -a $INNERWORKDIR/ArangoDB/utils/gdb-pretty-printers/immer/test/flex_vector_test.cpp $INNERWORKDIR/coverage/utils/gdb-pretty-printers/immer/test/flex_vector_test.cpp
end
