#!/usr/bin/env false

set -xg ASAN_OPTIONS "log_path=/work/asan.log:log_exe_name=true:handle_ioctl=true:check_initialization_order=true:detect_container_overflow=1:detect_stack_use_after_return=false:detect_odr_violation=1:allow_addr2line=true:detect_deadlocks=true:strict_init_order=true"
set -xg LSAN_OPTIONS "log_path=/work/asan.log:log_exe_name=true"
set -xg UBSAN_OPTIONS "log_path=/work/asan.log:log_exe_name=true"

if test -z "$PARALLELISM"
  set -g PARALLELISM 64
end

function runSingleTest1
  if test $VERBOSEOSKAR = On ; echo Launching $argv "($launchCount)" ; end

  set -l t $argv[1]
  set -l tt $argv[2]
  set -l l0 "$t""$tt".log
  set -l l1 $TMPDIR/"$t""$tt".out
  set -e argv[1..2]

  if grep $t UnitTests/OskarTestSuitesBlackList
    echo Test suite $t skipped by UnitTests/OskarTestSuitesBlackList
  else
    set -l arguments $t \
      --cluster false \
      --storageEngine $STORAGEENGINE \
      --minPort $portBase --maxPort (math $portBase + 99) \
      --skipNondeterministic true \
      --skipTimeCritical true \
      --testOutput $l1 \
      --writeXmlReport false \
      --skipGrey "$SKIPGREY" \
      --onlyGrey "$ONLYGREY" \
      $argv

    echo scripts/unittest $arguments
    mkdir -p $l1
    date -u +%s > $l1/started
    scripts/unittest $arguments > $l0 ^&1 &
    set -g portBase (math $portBase + 100)
    sleep 1
  end
end

function runSingleTest2
  runSingleTest1 $argv --extraArgs:log.level replication=trace
end

function runCatchTest1
  runSingleTest1 $argv
end

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
    end
    # Check subprocesses:
    if test (count (jobs -p)) -eq 0
      set stop (date -u +%s)
      echo (date) executed $launchCount tests in (math $stop - $start) seconds
      return 1
    end

    echo (date) (count (jobs -p)) jobs still running, remaining $i "seconds..."

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