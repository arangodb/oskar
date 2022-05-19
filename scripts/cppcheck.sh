#!/bin/sh
set -e

cd /work/ArangoDB
./utils/cppcheck.sh -j $PARALLELISM $@
status=$?

cat cppcheck.xml \
  | sed -e "s:file=\":file=\".:g" \
  > cppcheck.xml.tmp
mv cppcheck.xml.tmp cppcheck.xml

exit $status
