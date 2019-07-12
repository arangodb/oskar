################################################################################
# report generation
################################################################################
Function showLog
{
    Get-Content "$INNERWORKDIR\test.log" | Out-GridView -Title "$INNERWORKDIR\test.log";comm
}

Function log([array]$log)
{
    ForEach($l in $log)
    {
        Write-Host $l
        $l | Add-Content "$INNERWORKDIR\test.log"
    }
    comm
}

Function createReport
{
    $date = $(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH.mm.ssZ")
    $date | Add-Content "$env:TMP\testProtocol.txt"
    $global:badtests = $null
    new-item $env:TMP\oskar-junit-report -itemtype directory
    ForEach($dir in (Get-ChildItem -Path $env:TMP  -Directory -Filter "*.out"))
    {
        if ($(Get-ChildItem -filter "*.xml" -path $dir.FullName | Measure-Object | Select -ExpandProperty Count) -gt 0) {
          Copy-Item -Path "$($dir.FullName)\*.xml" $env:TMP\oskar-junit-report
        }
        Write-Host "Looking at directory $($dir.BaseName)"
        If(Test-Path -PathType Leaf -Path "$($dir.FullName)\UNITTEST_RESULT_EXECUTIVE_SUMMARY.json")
            {
                        If(-Not($(Get-Content "$($dir.FullName)\UNITTEST_RESULT_EXECUTIVE_SUMMARY.json") -eq "true"))
                        {
                            $global:result = "BAD"
                            $file = $($dir.BaseName).Substring(0,$($dir.BaseName).Length-4)+".stdout.log"
                            Write-Host "Bad result in $file"
                            "Bad result in $file" | Add-Content "$env:TMP\testProtocol.txt"
                            $global:badtests = $global:badtests + "Bad result in $file`r`n"
                        }   
            }
        Elseif(Test-Path -PathType Leaf -Path "$($dir.FullName)\UNITTEST_RESULT_CRASHED.json")
            {
                        If(-Not($(Get-Content "$($dir.FullName)\UNITTEST_RESULT_CRASHED.json") -eq "false"))
                        {
                            $global:result = "BAD"
                            $file = $($dir.BaseName).Substring(0,$($dir.BaseName).Length-4)+".stdout.log"
                            Write-Host "Crash occured in $file"
                            $global:hasTestCrashes = "true"
                            "Crash occured in $file" | Add-Content "$env:TMP\testProtocol.txt"
                            $global:badtests = $global:badtests + "Crash occured in $file`r`n"
                        }   
            }
        Else
            {
                Write-Host "No Testresult found at directory $($dir.BaseName)"
                $global:result = "BAD"
                "No Testresult found at directory $($dir.BaseName)" | Add-Content "$env:TMP\testProtocol.txt"
                $global:badtests = $global:badtests + "No Testresult found at directory $($dir.BaseName)`r`n"   
            }
    }
    $global:result | Add-Content "$env:TMP\testProtocol.txt"
    If(Get-ChildItem -Path "$env:TMP" -Filter "core_*" -Recurse -ErrorAction Continue -Force)
    {
        Write-Host "7zip -Path "$global:ARANGODIR\build\bin\$BUILDMODE\arango*.exe "-DestinationPath "$INNERWORKDIR\crashreport-$date.zip
        7zip -Path "$global:ARANGODIR\build\bin\$BUILDMODE\arango*.exe" -DestinationPath "$INNERWORKDIR\crashreport-$date.zip"
        ForEach($core in (Get-ChildItem -Path "$env:TMP" -Filter "core_*" -Recurse -ErrorAction SilentlyContinue))
        {
            Write-Host "7zip -Path $($core.FullName) -DestinationPath `"$INNERWORKDIR\crashreport-$date.zip`""   
            7zip -Path $($core.FullName) -DestinationPath "$INNERWORKDIR\crashreport-$date.zip"
            Write-Host "Remove-Item $($core.FullName)"
            Remove-Item $($core.FullName)
        }
        ForEach($pdb in (Get-ChildItem -Path "$global:ARANGODIR\build\bin\$BUILDMODE\" -Filter "arango*.pdb" -Recurse -ErrorAction SilentlyContinue))
        {
            Write-Host "7zip -Path $($pdb.FullName) -DestinationPath `"$INNERWORKDIR\crashreport-$date.zip`""
            7zip -Path $($pdb.FullName) -DestinationPath "$INNERWORKDIR\crashreport-$date.zip"
        }
    }
    If(Test-Path -PathType Leaf -Path "$global:ARANGODIR\innerlogs.zip")
    {
        Remove-Item -Force "$global:ARANGODIR\innerlogs.zip"
    }
    Write-Host "7zip -Path `"$env:TMP\`" -DestinationPath `"$global:ARANGODIR\innerlogs.zip`""
    7zip -Path "$env:TMP\" -DestinationPath "$global:ARANGODIR\innerlogs.zip"
    ForEach($log in $(Get-ChildItem -Path $global:ARANGODIR -Filter "*.log"))
    {
        Write-Host "7zip -Path $($log.FullName)  -DestinationPath `"$INNERWORKDIR\testreport-$date.zip`""
        7zip -Path $($log.FullName)  -DestinationPath "$INNERWORKDIR\testreport-$date.zip"
    }
    ForEach($archive in $(Get-ChildItem -Path $global:ARANGODIR -Filter "*.zip"))
    {
        Write-Host "7zip -Path $($archive.FullName) -DestinationPath `"$INNERWORKDIR\testreport-$date.zip`""
        7zip -Path $($archive.FullName) -DestinationPath "$INNERWORKDIR\testreport-$date.zip"
    }
    Write-Host "7zip -Path $env:TMP\testProtocol.txt -DestinationPath `"$INNERWORKDIR\testreport-$date.zip`""
    7zip -Path "$env:TMP\testProtocol.txt" -DestinationPath "$INNERWORKDIR\testreport-$date.zip"

    log "$date $TESTSUITE $global:result M:$MAINTAINER $BUILDMODE E:$ENTERPRISEEDITION $STORAGEENGINE",$global:repoState,$global:repoStateEnterprise,$badtests
    If(Test-Path -PathType Leaf -Path "$INNERWORKDIR\testfailures.log")
    {
        Remove-Item -Force "$INNERWORKDIR\testfailures.log"
    }

    Add-Content $global:oskarErrorMessage "$INNERWORKDIR\testfailures.log"
    ForEach($file in (Get-ChildItem -Path $env:TMP -Filter "testfailures.txt" -Recurse).FullName)
    {
        Get-Content $file | Add-Content "$INNERWORKDIR\testfailures.log"; comm
    }
}

################################################################################
# Test main control
################################################################################

Function runTests
{
    If(Test-Path -PathType Container -Path $env:TMP)
    {
        Remove-Item -Recurse -Force -Path $env:TMP
        New-Item -ItemType Directory -Path $env:TMP
    }
    Else
    {
        New-Item -ItemType Directory -Path $env:TMP
    }
    Push-Location $pwd
    Set-Location $global:ARANGODIR
    ForEach($log in $(Get-ChildItem -Filter "*.log"))
    {
        Remove-Item -Recurse -Force $log 
    }
    Pop-Location

    Switch -Regex ($TESTSUITE)
    {
        "cluster"
        {
            registerClusterTests
            LaunchController $global:TESTSUITE_TIMEOUT
            createReport  
            Break
        }
        "single"
        {
            registerSingleTests
            LaunchController $global:TESTSUITE_TIMEOUT
            createReport
            Break
        }
        "catchtest"
        {
            registerTest -testname "catch"
            LaunchController $global:TESTSUITE_TIMEOUT
            createReport
            Break
        }
        "resilience"
        {
            Write-Host "resilience tests currently not implemented"
            $global:result = "BAD"
            Break
        }
        "*"
        {
            Write-Host "Unknown test suite $TESTSUITE"
            $global:result = "BAD"
            Break
        }
    }

    If($global:result -eq "GOOD")
    {
        Set-Variable -Name "ok" -Value $true -Scope global
    }
    Else
    {
        Set-Variable -Name "ok" -Value $false -Scope global
    }
}

Function launchTest($which) {
    Push-Location $pwd
    Set-Location $global:ARANGODIR; comm
    $arangosh = "$global:ARANGODIR\build\bin\$BUILDMODE\arangosh.exe"
    $test = $global:launcheableTests[$which]
    Write-Host "Test: " $test['testname'] " - " $test['identifier']
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    Write-Host $arangosh " --- " $test['commandline'] 
    Write-Host "-RedirectStandardOutput " $test['StandardOutput']
    Write-Host "-RedirectStandardError " $test['StandardError']

    $process = $(Start-Process -FilePath "$arangosh" -ArgumentList $test['commandline'] -RedirectStandardOutput $test['StandardOutput'] -RedirectStandardError $test['StandardError'] -PassThru)
    
    $global:launcheableTests[$which]['pid'] = $process.Id
    $global:launcheableTests[$which]['running'] = $true
    $global:launcheableTests[$which]['launchDate'] = $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))
    If(-not($process.ExitCode -eq $null))
    {
        Write-Host "Error: Launching Test"
        $process | Format-List -Property *
    }

    $str=$($test | where {($_.Name -ne "commandline")} | Out-String)
    Write-Host $str
    $global:launcheableTests[$which]['process'] = $process
    Pop-Location
}

Function registerTest($testname, $index, $bucket, $filter, $moreParams, $cluster, $weight, $sniff)
{
    Write-Host "$global:ARANGODIR\UnitTests\OskarTestSuitesBlackList"
    If(-Not(Select-String -Path "$global:ARANGODIR\UnitTests\OskarTestSuitesBlackList" -pattern $testname))
    {
        $testWeight = 1
        $testparams = ""
        $dumpAgencyOnError = ""

        $output = $testname.replace("*", "all")
        if ($index) {
          $output = $output+"$index"
        }
        If ($filter) {
           $testparams = $testparams+" --test $filter"
        }
        if ($bucket) {
            $testparams = $testparams+" --testBuckets $bucket"
        }
        if ($cluster -eq $true)
        {
            $testWeight = 4
            $cluster = "true"
            $dumpAgencyOnError = "true"
        }
        else
        {
            $cluster = "false"
            $dumpAgencyOnError = "false"
        }
        if ($testname -eq "agency")
        {
            $dumpAgencyOnError = "true"
        }
        if ($weight) {
          $testWeight = $weight
        }

        if ($sniff) {
          $tsharkx = "$global:WIRESHARKPATH\tshark.exe"
          $tshark = "$tsharkx" -replace ' ', '` '
          (Invoke-Expression "$tshark -D"  |Select-String -SimpleMatch Npcap ) -match '^(\d).*'
          $dumpDevice = $Matches[1]
          if ($dumpDevice -notmatch '\d+') {
             Write-Host "unable to detect the loopback-device. we expect this to have an Npcacp one:"
             Invoke-Expression $tshark -D
             Set-Variable -Name "ok" -Value $false -Scope global
             return
          }
          $testparams = $testparams + " --sniff true --sniffProgram `"$tsharkx`" --sniffDevice $dumpDevice"
        }
        
        $testparams = $testparams + " --cluster $cluster --coreCheck true --storageEngine $STORAGEENGINE --minPort $global:portBase --maxPort $($global:portBase + 99) --skipNondeterministic $global:SKIPNONDETERMINISTIC --skipTimeCritical $global:SKIPTIMECRITICAL --writeXmlReport true --skipGrey $global:SKIPGREY --dumpAgencyOnError $dumpAgencyOnError --onlyGrey $global:ONLYGREY --buildType $BUILDMODE"

        New-Item -Path "$env:TMP\$output.out" -ItemType Directory
        $testparams = $testparams + " --testOutput $env:TMP\$output.out"
        $testparams = $testparams + " " + $moreParams
        If (-Not ([string]::IsNullOrEmpty($global:RUBY))) {
          $testparams = $testparams + " --ruby " + $global:RUBY
        }
        
        $PORT = Get-Random -Minimum 20000 -Maximum 65535
        $i = $global:testCount
        $global:testCount = $global:testCount+1
        $global:launcheableTests += @{
          running=$false;
          weight=$testWeight;
        testname=$testname;
        identifier=$output;
          commandline=" -c $global:ARANGODIR\etc\relative\arangosh.conf --log.level warning --server.endpoint tcp://127.0.0.1:$PORT --javascript.execute $global:ARANGODIR\UnitTests\unittest.js -- $testname $testparams";
          StandardOutput="$global:ARANGODIR\$output.stdout.log";
          StandardError="$global:ARANGODIR\$output.stderr.log";
          pid=-1;
        }
        $global:maxTestCount = $global:maxTestCount+1
        
        $global:portBase = $($global:portBase + 100)
    }
    Else
    {
        Write-Host "Test suite $testname skipped by UnitTests/OskarTestSuitesBlackList"
    }
    comm
}

Function LaunchController($seconds)
{
    $timeSlept = 0;
    $nextLauncheableTest = 0
    $currentScore = 0
    $currentRunning = 1
    $maxLauncheableTests = $global:launcheableTests.Length
    $numberTestsSlots = [math]::Round($global:numberSlots * 0.9) # Should leave 10% of slots free for $global:numberSlots > 4
    While (($seconds -gt 0) -and (($currentRunning -gt 0) -or ($nextLauncheableTest -lt $maxLauncheableTests))) {
        while (($currentScore -lt $numberTestsSlots) -and ($nextLauncheableTest -lt $global:maxTestCount)) {
            Write-Host "Launching $nextLauncheableTest '" $global:launcheableTests[$nextLauncheableTest ]['identifier'] "'"
            launchTest $nextLauncheableTest 
            $currentScore = $currentScore+$global:launcheableTests[$nextLauncheableTest ]['weight']
            Start-Sleep 20
            $seconds = $seconds - 20
            $nextLauncheableTest = $nextLauncheableTest+1
        }
        $currentRunning = 0
        $currentRunningNames = @()
        ForEach ($test in $global:launcheableTests) {
            if ($test['running']) {
                if ($test['process'].HasExited) {
                    $currentScore = $currentScore - $test['weight']
                    Write-Host "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ')) Testrun finished: "$test['identifier'] $test['launchdate']
                    $str=$($test | where {($_.Name -ne "commandline")} | Out-String)
                    $test['running'] = $false
                }
                Else {
                    $currentRunningNames += $test['identifier']
                    $currentRunning = $currentRunning+1
                }
            }
        }
        Start-Sleep 5
        $a = $currentRunningNames -join ","
        Write-Host "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ')) - Waiting  - "$seconds" - Running Tests: "$a
        $seconds = $seconds - 5
    }
    if ($seconds -lt 1) {
      Write-Host "tests timeout reached. Current state of worker jobs:"
    }
    Else {
      Write-Host "tests done. Current state of worker jobs:"
    }
    $str=$global:launcheableTests | Out-String
    Write-Host $str
  
    Get-WmiObject win32_process | Out-File -filepath $env:TMP\processes-before.txt
    Write-Host "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ')) we have "$currentRunning" tests that timed out! Currently running processes:"
    $SessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    ForEach ($test in $global:launcheableTests) {
        if ($test['pid'] -gt 0) { # TODO:  $test['running']
          if ($test['running']) {
             $global:oskarErrorMessage = $global:oskarErrorMessage + "Oskar is killing this test due to timeout:\n" + $( format-list $test['running'] )
          }
          Write-Host "Testrun timeout:"
          $str=$($test | where {($_.Name -ne "commandline")} | Out-String)
          Write-Host $str
          ForEach ($childProcesses in $(Get-WmiObject win32_process | Where {$_.ParentProcessId -eq $test['pid'] -And $_.SessionId -eq $SessionId -And -Not [string]::IsNullOrEmpty($_.Path) })) {
            ForEach ($childChildProcesses in $(Get-WmiObject win32_process | Where {$_.ParentProcessId -eq $test['pid'] -And $_.SessionId -eq $SessionId -And -Not [string]::IsNullOrEmpty($_.Path) })) {
              ForEach ($childChildChildProcesses in $(Get-WmiObject win32_process | Where {$_.ParentProcessId -eq $test['pid'] -And $_.SessionId -eq $SessionId -And -Not [string]::IsNullOrEmpty($_.Path) })) {
                Write-Host "killing child3: "
                $str=$childChildChildProcesses | Out-String
                Write-Host $str
                Stop-Process -Force -Id $childChildChildProcesses.Handle
              }
              Write-Host "killing child2: "
              $str=$childChildProcesses | Out-String
              Write-Host $str
              Stop-Process -Force -Id $childChildProcesses.Handle
            }
            Write-Host "killing child: "
            $str=$childProcesses | Out-String
            Write-Host $str

            Stop-Process -Force -Id $childProcesses.Handle
            $global:result = "BAD"
          }
          If((Get-Process -Id $test['pid'] -ErrorAction SilentlyContinue) -ne $null)
          {
            Stop-Process -Force -Id $test['pid']
          }
          Else
          {
            Write-Host ("Process with ID {0} was already stopped" -f $test['pid'])
          }
        }
    }
    Get-WmiObject win32_process | Out-File -filepath $env:TMP\processes-after.txt 
    comm
}
