#!/usr/bin/env false

if test -z "$PARALLELISM"
  set -g PARALLELISM 64
end

# address sanitizer
set -xg ASAN_OPTIONS "log_path=/work/asan.log:log_exe_name=true:handle_ioctl=true:check_initialization_order=true:detect_container_overflow=1:detect_stack_use_after_return=false:detect_odr_violation=1:allow_addr2line=true:detect_deadlocks=true:strict_init_order=true"

# leak sanitizer
set -xg LSAN_OPTIONS "log_path=/work/asan.log:log_exe_name=true"

# undefined behavior sanitizer
set -xg UBSAN_OPTIONS "log_path=/work/asan.log:log_exe_name=true"

# thread sanitizer
set -xg TSAN_OPTIONS "log_path=/work/tsan.log:log_exe_name=true"

# suppressions
if test -f $INNERWORKDIR/ArangoDB/asan_arangodb_suppressions.txt
  set ASAN_OPTIONS "$ASAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/asan_arangodb_suppressions.txt"
end

if test -f $INNERWORKDIR/ArangoDB/lsan_arangodb_suppressions.txt
  set LSAN_OPTIONS "$LSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/lsan_arangodb_suppressions.txt"
end

if test -f $INNERWORKDIR/ArangoDB/ubsan_arangodb_suppressions.txt
  set UBSAN_OPTIONS "$UBSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/ubsan_arangodb_suppressions.txt"
end

if test -f $INNERWORKDIR/ArangoDB/tsan_arangodb_suppressions.txt
  set TSAN_OPTIONS "$TSAN_OPTIONS:suppressions=$INNERWORKDIR/ArangoDB/tsan_arangodb_suppressions.txt"
end

echo "ASAN: $ASAN_OPTIONS"
echo "LSAN: $LSAN_OPTIONS"
echo "UBSAN: $UBSAN_OPTIONS"
echo "TSAN: $TSAN_OPTIONS"

function runAnyTest
  set -l t $argv[1]
  set -l tt $argv[2]
  set -l l0 "$t"
  if test "$tt" = "-"
    set tt ""
  end
  if test "$tt" != ""
    set l0 "$t"_"$tt"
  end
  set -l l1 "$l0".log
  set -l l2 $TMPDIR/"$l0".out
  set -e argv[1..2]

  if test $VERBOSEOSKAR = On ; echo "$launchCount: Launching $l0" ; end

  if grep $t UnitTests/OskarTestSuitesBlackList
    echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
  else
    set -l arguments $t \
      --storageEngine $STORAGEENGINE \
      --minPort $portBase --maxPort (math $portBase + 99) \
      --skipNondeterministic "$SKIPNONDETERMINISTIC" \
      --skipTimeCritical "$SKIPTIMECRITICAL" \
      --testOutput $l2 \
      --writeXmlReport false \
      --skipGrey "$SKIPGREY" \
      --onlyGrey "$ONLYGREY" \
      $argv

    echo (pwd) "-" scripts/unittest $arguments
    mkdir -p $l2
    fish -c "date -u +%s > $l2/started; scripts/unittest $arguments > $l1 ^&1; date -u +%s > $l2/stopped" &
    set -g portBase (math $portBase + 100)
    sleep 1
  end
end

function runSingleTest1
  runAnyTest $argv --cluster false
end

function runSingleTest2
  runAnyTest $argv --cluster false --extraArgs:log.level replication=trace
end

function runCatchTest1
  runAnyTest $argv --cluster false
end

function runClusterTest1
  runAnyTest $argv --cluster true
end

function runClusterTest3
  set t $argv[3]
  set -e argv[3]

  runAnyTest $argv --cluster true --test $t
end

function createReport
  set -g result GOOD

  set -l now (date -u +%F_%H.%M.%SZ)
  set -l badtests

  echo $now >> testProtocol.txt
  echo $now

  pushd $INNERWORKDIR/tmp

  set -l totalStarted (date -u +%s)
  set -l totalStopped 0

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

    if test -f "$d/started"
      set started (cat "$d/started")

      if test $started -lt $totalStarted
        set totalStarted $started
      end

      if test -f "$d/started" -a -f "$d/stopped"
        set stopped (cat "$d/stopped")

        if test $totalStopped -lt $stopped
          set totalStopped $stopped
        end

        echo Test $d took (math $stopped - $started) seconds, status $localresult
        echo $d,(math $stopped - $started),$localresult >> testRuns.txt
      else
        echo Test $d did not finish, status $localresult
        echo $d,-1,$localresult >> testRuns.txt
      end
    end
  end

  echo "TOTAL,"(math $totalStopped - $totalStarted)","$result >> testRuns.txt

  begin
    echo "<table>"; echo "Test,Runtime,Status" | sed -e 's/^/<tr><th>/' -e 's/,/<\/th><th>/g' -e 's/$/<\/th><\/tr>/'
    cat testRuns.txt | sed -e 's/^/<tr><td>/' -e 's/,/<\/td><td align="right">/g' -e 's/$/<\/td><\/tr>/'
    echo "</table>"
  end > testRuns.html

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

  if test -f $INNERWORKDIR/tmp/testRuns.txt
    cp $INNERWORKDIR/tmp/testRuns.txt $INNERWORKDIR
  end

  if test -f $INNERWORKDIR/tmp/testRuns.html
    cp $INNERWORKDIR/tmp/testRuns.html $INNERWORKDIR
  end

  log "$now $TESTSUITE $result M:$MAINTAINER $BUILDMODE E:$ENTERPRISEEDITION $STORAGEENGINE" $repoState $repoStateEnterprise $badtests ""
end

function hasLDAPHOST
    test ! -z "$LDAPHOST"
    return $status
end

set -g repoState ""
set -g repoStateEnterprise ""

function getRepoState
  set -g repoState (git rev-parse HEAD) (git status -b -s | grep -v "^[?]")
  if test $ENTERPRISEEDITION = On 
    cd enterprise
    set -g repoStateEnterprise (git rev-parse HEAD) (git status -b -s | grep -v "^[?]")
    cd ..
  else
    set -g repoStateEnterprise ""
  end
end

function noteStartAndRepoState
  getRepoState
  rm -f testProtocol.txt
  set -l d (date -u +%F_%H.%M.%SZ)
  echo $d >> testProtocol.txt
  echo "==========\nStatus of main repository:" >> testProtocol.txt
  echo "==========\nStatus of main repository:"
  for l in $repoState ; echo "  $l" >> testProtocol.txt ; echo "  $l" ; end
  if test $ENTERPRISEEDITION = On
    echo "Status of enterprise repository:" >> testProtocol.txt
    echo "Status of enterprise repository:"
    for l in $repoStateEnterprise
      echo "  $l" >> testProtocol.txt ; echo "  $l"
    end
  end
end

function resetLaunch
  noteStartAndRepoState
  set -g launchFactor $argv[1]
  set -g portBase 10000
  set -g launchCount 0
  if test $launchFactor -gt 1 -a $PARALLELISM -lt (math "$launchFactor*2")
    set -g $PARALLELISM (math "$PARALLELISM*2")
    echo "Extend small parallelism for launchFactor > 1: $PARALLELISM"
  end
  echo Launching tests...
end

function waitForProcesses
  set i $argv[1]
  set launcher $argv[2]
  set start (date -u +%s)
  while true
    # Launch if necessary:
    while test (math (count (jobs -p))"*$launchFactor") -lt "$PARALLELISM"
      if test -z "$launcher" ; break ; end
      if eval "$launcher" ; break ; end
      sleep 30
    end

    # Check subprocesses:
    if test (count (jobs -p)) -eq 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 1
    end

    echo (date) (count (jobs -p)) jobs still running, remaining $i "seconds..."
    echo (begin \
            begin \
              test (count /work/tmp/*.out/started) -gt 0; and ls -1 /work/tmp/*.out/started; \
            end; \
            begin \
              test (count /work/tmp/*.out/stopped) -gt 0; and ls -1 /work/tmp/*.out/stopped; \
            end; \
          end | awk -F/ '{print $4}' | sort | uniq -c | awk '$1 == 1 { print substr($2,1,length($2) - 4) }')

    set i (math $i - 5)
    if test $i -lt 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 0
    end

    sleep 5
  end
end

function waitOrKill
  set timeout $argv[1]
  set launcher $argv[2]
  echo Controlling subprocesses...
  if waitForProcesses $timeout $launcher
    set -l ids (jobs -p)
    if test (count $ids) -gt 0
      kill $ids
      if waitForProcesses 30 ""
        set -l ids (jobs -p)
        if test (count $ids) -gt 0
          kill -9 $ids
          waitForProcesses 60 ""   # give jobs some time to finish
        end
      end
    end
  end
  return 0
end

function log
  for l in $argv
    echo $l
    echo $l >> $INNERWORKDIR/test.log
  end
end

function setupTmp
  pushd $INNERWORKDIR
  and rm -rf tmp
  and mkdir tmp
  and set -xg TMPDIR $INNERWORKDIR/tmp
  and cd $INNERWORKDIR/ArangoDB
  and for f in *.log ; rm -f $f ; end
  and popd
  or begin popd; return 1; end
end
