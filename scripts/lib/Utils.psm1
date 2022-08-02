################################################################################
# report generation
################################################################################
Function showLog
{
    Get-Content "$INNERWORKDIR\test.log" | Out-GridView -Title "$INNERWORKDIR\test.log";comm
}

Function log([array]$log)
{
    ForEach ($l in $log)
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
    ForEach ($dir in (Get-ChildItem -Path $env:TMP  -Directory -Filter "*.out"))
    {
        $reportFound = $false
        If ($(Get-ChildItem -filter "*.xml" -path $dir.FullName | Measure-Object | Select -ExpandProperty Count) -gt 0) {
          Copy-Item -Path "$($dir.FullName)\*.xml" $env:TMP\oskar-junit-report
        }
        Write-Host "Looking at directory $($dir.BaseName)"
        If(Test-Path -PathType Leaf -Path "$($dir.FullName)\UNITTEST_RESULT_EXECUTIVE_SUMMARY.json")
            {
                        $reportFound = $true
                        If(-Not($(Get-Content "$($dir.FullName)\UNITTEST_RESULT_EXECUTIVE_SUMMARY.json") -eq "true"))
                        {
                            $global:result = "BAD"
                            $file = $($dir.BaseName).Substring(0,$($dir.BaseName).Length-4)+".stdout.log"
                            Write-Host "Bad result in $file"
                            "Bad result in $file" | Add-Content "$env:TMP\testProtocol.txt"
                            $global:badtests = $global:badtests + "Bad result in $file`r`n"
                        }
            }
        If(Test-Path -PathType Leaf -Path "$($dir.FullName)\UNITTEST_RESULT_CRASHED.json")
            {
                        $reportFound = $true
                        If(-Not($(Get-Content "$($dir.FullName)\UNITTEST_RESULT_CRASHED.json") -eq "false"))
                        {
                            $global:result = "BAD"
                            $file = $($dir.BaseName).Substring(0,$($dir.BaseName).Length-4)+".stdout.log"
                            Write-Host "Crash occured in $file"
                            $global:hasTestCrashes = $True
                            "Crash occured in $file" | Add-Content "$env:TMP\testProtocol.txt"
                            $global:badtests = $global:badtests + "Crash occured in $file`r`n"
                        }
            }
        If ($reportFound -ne $true)
            {
                Write-Host "No Testresult found at directory $($dir.BaseName)"
                $global:result = "BAD"
                "No Testresult found at directory $($dir.BaseName)" | Add-Content "$env:TMP\testProtocol.txt"
                $global:badtests = $global:badtests + "No Testresult found at directory $($dir.BaseName)`r`n"   
            }
    }
    $global:result | Add-Content "$env:TMP\testProtocol.txt"
    If($global:ENABLE_REPORT_DUMPS -eq "on" -and (Get-ChildItem -Path "$global:COREDIR" -Filter "arango*.dmp" -Recurse -ErrorAction Continue -Force))
    {
        Write-Host "7zip -Path "$global:ARANGODIR\build\bin\$BUILDMODE\arango*.exe "-DestinationPath "$INNERWORKDIR\crashreport-$date.7z
        7zip -Path "$global:ARANGODIR\build\bin\$BUILDMODE\arango*.exe" -DestinationPath "$INNERWORKDIR\crashreport-$date.7z"
        ForEach ($core in (Get-ChildItem -Path "$global:COREDIR" -Filter "arango*.dmp" -Recurse -ErrorAction SilentlyContinue))
        {
            Write-Host "7zip -Path $($core.FullName) -DestinationPath `"$INNERWORKDIR\crashreport-$date.7z`""   
            7zip -Path $($core.FullName) -DestinationPath "$INNERWORKDIR\crashreport-$date.7z"
            Write-Host "Remove-Item $($core.FullName)"
            Remove-Item $($core.FullName)
        }
        ForEach ($pdb in (Get-ChildItem -Path "$global:ARANGODIR\build\bin\$BUILDMODE\" -Filter "arango*.pdb" -Recurse -ErrorAction SilentlyContinue))
        {
            Write-Host "7zip -Path $($pdb.FullName) -DestinationPath `"$INNERWORKDIR\crashreport-$date.7z`""
            7zip -Path $($pdb.FullName) -DestinationPath "$INNERWORKDIR\crashreport-$date.7z"
        }
    }
    If(Test-Path -PathType Leaf -Path "$global:ARANGODIR\innerlogs.7z")
    {
        Remove-Item -Force "$global:ARANGODIR\innerlogs.7z"
    }
    Write-Host "7zip -Path `"$env:TMP\`" -DestinationPath `"$global:ARANGODIR\innerlogs.7z`""
    7zip -Path "$env:TMP\" -DestinationPath "$global:ARANGODIR\innerlogs.7z"
    ForEach ($log in $(Get-ChildItem -Path $global:ARANGODIR -Filter "*.log"))
    {
        Write-Host "7zip -Path $($log.FullName)  -DestinationPath `"$INNERWORKDIR\testreport-$date.7z`""
        7zip -Path $($log.FullName) -DestinationPath "$INNERWORKDIR\testreport-$date.7z"
    }
    ForEach ($archive in $(Get-ChildItem -Path $global:ARANGODIR -Filter "*.7z"))
    {
        Write-Host "7zip -Path $($archive.FullName) -DestinationPath `"$INNERWORKDIR\testreport-$date.7z`""
        7zip -Path $($archive.FullName) -DestinationPath "$INNERWORKDIR\testreport-$date.7z"
    }
    Write-Host "7zip -Path $env:TMP\testProtocol.txt -DestinationPath `"$INNERWORKDIR\testreport-$date.7z`""
    7zip -Path "$env:TMP\testProtocol.txt" -DestinationPath "$INNERWORKDIR\testreport-$date.7z"

    log "$date $TESTSUITE $global:result M:$MAINTAINER $BUILDMODE E:$ENTERPRISEEDITION $STORAGEENGINE",$global:repoState,$global:repoStateEnterprise,$badtests
    If(Test-Path -PathType Leaf -Path "$INNERWORKDIR\testfailures.txt")
    {
        Remove-Item -Force "$INNERWORKDIR\testfailures.txt"
    }

    If($global:result -eq "BAD" -Or $global:hasTestCrashes)
    {
        $global:oskarErrorMessage | Add-Content "$INNERWORKDIR\testfailures.txt"
        ForEach ($file in (Get-ChildItem -Path $env:TMP -Filter "testfailures.txt" -Recurse).FullName)
        {
            Get-Content $file | Add-Content "$INNERWORKDIR\testfailures.txt"; comm
        }
    }
}

################################################################################
# Test main control
################################################################################

Function runTests
{
    If (Test-Path -PathType Container -Path $env:TMP)
    {
        Remove-Item -Recurse -Force -Path $env:TMP -Exclude "$env:TMP\OpenSSL"
    }
    Else
    {
        New-Item -ItemType Directory -Path $env:TMP
    }
    Push-Location $pwd
    Set-Location $global:ARANGODIR
    ForEach ($log in $(Get-ChildItem -Filter "*.log"))
    {
        Remove-Item -Recurse -Force $log
    }
    Pop-Location

    $global:result = "GOOD"

    Switch -Regex ($TESTSUITE)
    {
        "cluster"
        {
            registerClusterTests
            Break
        }
        "single"
        {
            registerSingleTests
            Break
        }
        "gtest"
        {
            registerTest -testname "gtest"
            Break
        }
        "resilience"
        {
            Write-Host "resilience tests currently not implemented"
            $global:result = "BAD"
            Break
        }
        "tests"
        {
            registerTests
            Break
        }
        "*"
        {
            Write-Host "Unknown test suite $TESTSUITE"
            $global:result = "BAD"
            Break
        }
    }

    If ($global:result -eq "GOOD" -And $global:ok)
    {
        LaunchController $global:TESTSUITE_TIMEOUT
        createReport
    }
    Else
    {
        $global:result = "BAD"
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

Function waitForTimeWaitSockets() {
    $TimeWait = 0
    do {
      $TimeWait = (Get-NetTCPConnection -State TimeWait -ErrorAction SilentlyContinue | Measure-Object).Count
      If ($TimeWait -gt 2500) {
        Write-Host "waiting for connections to go away ${TimeWait}"
        Start-Sleep 20
      }
    } while ($TimeWait -gt 2500)
}


Function StopProcessWithChildren ($PidToKill, $WaitTimeout)
{
    Write-Host "Killing $PidToKill with descedants!"
    $stopProc = Get-Process -Id $PidToKill

    If ($global:PSKILL_EXE) {
        Invoke-Expression "$global:PSKILL_EXE -t $PidToKill" | Out-Null
    } Else {
        Stop-Process -Force -Id $PidToKill
    }

    While (-Not $stopProc.HasExited) {
        Write-Host "Waiting $PidToKill to stop for ${WaitTimeout}s..."
    }
}

