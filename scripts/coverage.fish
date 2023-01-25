#!/usr/bin/env fish
set -l c 0

cd $INNERWORKDIR
and rm -rf combined
and mkdir combined

and for i in gcov/????????????????????????????????
  if test $c -eq 0
    echo "first file $i"
    and cp -a $i combined/1
    and set c 1
  else if test $c -eq 1
    echo "merging $i"
    and rm -rf combined/2
    and gcov-tool merge $i combined/1 -o combined/2
    and set c 2
  else if test $c -eq 2
    echo "merging $i"
    and rm -rf combined/1
    and gcov-tool merge $i combined/2 -o combined/1
    and set c 1
  end
end

and if test $c -eq 1
  mv combined/1 combined/result
else if test $c -eq 2
  mv combined/2 combined/result
end

and rm -rf combined/1 combined/2 /tmp/gcno

and echo "creating gcno tar"
and pushd ArangoDB/build
and tar c -f /tmp/gcno.tar (find . -name "*.gcno")
and popd
and echo "copying gcno files"
and tar x -f /tmp/gcno.tar -C /work/combined/result

and rm -rf coverage
and mkdir coverage
and mkdir coverage/enterprise
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
end
