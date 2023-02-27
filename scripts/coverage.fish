#!/usr/bin/env fish
set -l c 0

cd $INNERWORKDIR
and rm -rf /work/combined
and mkdir /work/combined
and python3 "$WORKSPACE/jenkins/helper/aggregate_coverage.py" /work/gcov /work/combined/result

and echo "creating gcno tar"
and pushd ArangoDB/build
and tar c -f /tmp/gcno.tar (find . -name "*.gcno")
and popd
and echo "copying gcno files"
and tar x -f /tmp/gcno.tar -C /work/combined/result

and rm -rf coverage
and mkdir coverage
and mkdir coverage/enterprise
and ln -s /work/ArangoDB/3rdParty/jemalloc/v*/include /work/ArangoDB/include
and gcovr --exclude-throw-branches --root /work/ArangoDB \
        -x \
        -e /work/ArangoDB/build \
        -e /work/ArangoDB/build/3rdParty/libunwind/v* \
        -e /work/ArangoDB/build/3rdParty/libunwind/v*/src/ \
        -e /work/ArangoDB/3rdParty \
        -e /work/ArangoDB/3rdParty/jemalloc/v*/ \
        -e /work/ArangoDB/usr/ \
        -e /work/ArangoDB/tests \
        -o coverage/coverage.xml \
        --exclude-lines-by-pattern "TRI_ASSERT" \
        --print-summary \
        /work/combined/result > /work/coverage/summary.txt
and cat coverage/coverage.xml \
      | sed -e "s:filename=\":filename=\"./coverage/:g" \
      > coverage/coverage.xml.tmp
and mv coverage/coverage.xml coverage/coverage.org.xml
and mv coverage/coverage.xml.tmp coverage/coverage.xml
and for d in lib arangosh client-tools arangod enterprise/Enterprise
  if test -d /work/ArangoDB/$d
  	echo "cp -a /work/ArangoDB/$d coverage/$d"
  	cp -a /work/ArangoDB/$d coverage/$d
  end
and if test -d /work/ArangoDB/enterprise/tests
        echo "cp -a /work/ArangoDB/enterprise/tests coverage/enterprise/tests"
        cp -a /work/ArangoDB/enterprise/tests coverage/enterprise/tests
    end
end
