#!/usr/bin/env false

function createReport
  set -g result GOOD

  set -l now (date -u +%F_%H.%M.%SZ)
  set -l badtests

  echo $now >> testProtocol.txt
  echo $now

  pushd $INNERWORKDIR/tmp

  for d in *.out
    set -l localresult GOOD
    echo Looking at directory $d

    if test -f "$d/UNITTEST_RESULT_EXECUTIVE_SUMMARY.json"
      if not grep -q true "$d/UNITTEST_RESULT_EXECUTIVE_SUMMARY.json"
        set -g result BAD
        set localresult BAD
        set f (basename -s out $d)log
        echo Bad result in $f
        echo Bad result in $f >> testProtocol.txt
        set badtests $badtests "Bad result in $f"
      end
    end

    if test -f "$d/UNITTEST_RESULT_CRASHED.json"
      if not grep -q false "$d/UNITTEST_RESULT_CRASHED.json"
        set -g result BAD
        set localresult BAD
        set f (basename -s out $d)log
        echo A crash occured in $f
        echo A crash occured in $f >> testProtocol.txt
        set badtests $badtests "A crash occured in $f"
      end
    end

    if test -f "$d/started" -a -f "$d/UNITTEST_RESULT_EXECUTIVE_SUMMARY.json"
      set started (cat "$d/started")
      set stopped (date -u -r "$d/UNITTEST_RESULT_EXECUTIVE_SUMMARY.json" +%s)
      echo Test $d took (math $stopped - $started) seconds, status $localresult
      echo Test $d took (math $stopped - $started) seconds, status $localresult >> testProtocol.txt
    end
  end

  # this is the jslint output
  if test -e "jslint.log"
    if grep ERROR "jslint.log"
      set -g result BAD
      echo Bad result in jslint
      echo Bad result in jslint >> testProtocol.txt
      set badtests $badtests "Bad result in jslint"
      mkdir "$INNERWORKDIR/jslint.out/"
      grep ERROR "jslint.log" > "$INNERWORKDIR/jslint.out/testfailures.txt"
    end
  end

  # this is the logids output
  if test -e "logids.log"
    if grep ERROR "logids.log"
      set -g result BAD
      echo Bad result in logids
      echo Bad result in logids >> testProtocol.txt
      set badtests $badtests "Bad result in logids"
      mkdir "$INNERWORKDIR/logids.out/"
      grep ERROR "logids.log" > "$INNERWORKDIR/logids.out/testfailures.txt"
    end
  end
 
  popd
  echo $result >> testProtocol.txt
  pushd $INNERWORKDIR
  and begin
    echo tar czvf "$INNERWORKDIR/ArangoDB/innerlogs.tar.gz" --exclude databases --exclude rocksdb --exclude journals tmp
    eval $IONICE nice -n 10 tar czvf "$INNERWORKDIR/ArangoDB/innerlogs.tar.gz" --exclude databases --exclude rocksdb --exclude journals tmp
    popd
  end
  
  # core on mac are under "/cores"
  # we have to grab all, because we do not know if a
  # core belongs to us
  if test -d /cores
    set -l cores /cores/core.*
    if test (count $cores) -ne 0
      mv /cores/core.* .
    end
  end

  set archives *.tar.gz
  set logs *.log
  set cores core*

  if test (count $cores) -ne 0
    set binaries (find ./build/bin \( -perm -u=x -o -perm -g=x -o -perm -o=x \) -type f -name 'arango*')
    echo tar czvf "$INNERWORKDIR/crashreport-$now.tar.gz" $cores $binaries
    eval $IONICE nice -n 10 tar czvf "$INNERWORKDIR/crashreport-$now.tar.gz" $cores $binaries
  end

  echo tar czvf "$INNERWORKDIR/testreport-$now.tar.gz" $logs testProtocol.txt $archives
  eval $IONICE nice -n 10 tar czvf "$INNERWORKDIR/testreport-$now.tar.gz" $logs testProtocol.txt $archives

  echo rm -rf $cores $archives
  eval $IONICE nice -n 10 rm -rf $cores $archives

  # And finally collect the testfailures.txt:
  rm -rf $INNERWORKDIR/testfailures.txt
  touch $INNERWORKDIR/testfailures.txt

  for f in "$INNERWORKDIR"/tmp/*.out/testfailures.txt
    cat -s $f >> $INNERWORKDIR/testfailures.txt
  end

  if grep "unclean shutdown" "$INNERWORKDIR/testfailures.txt"
    set -g result BAD
  end

  log "$now $TESTSUITE $result M:$MAINTAINER $BUILDMODE E:$ENTERPRISEEDITION $STORAGEENGINE" $repoState $repoStateEnterprise $badtests ""
end

