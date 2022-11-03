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

################################################################################
# Test main control
################################################################################

If ($ENTERPRISEEDITION -eq "On")
{
    $ENV:EncryptionAtRest = "--encryptionAtRest true"
}
Else
{
    $ENV:EncryptionAtRest = ""
}

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

