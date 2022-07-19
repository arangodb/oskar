Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 9000
    Write-Host "Using test definitions from repo..."
    Try
    {
        proc = proc = Start-Process -FilePath "$env:WORKSPACE\jenkins\helper\test_launch_controller.py"  -Argumentlist '"$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f launch --full'  -Wait -Passthru
        If ($proc.ExitCode -eq 0)
        {
            Set-Variable -Name "ok" -Value $true -Scope global
        }
        Else
        {
            Set-Variable -Name "ok" -Value $false -Scope global
        }
    }
    Catch
    {
        Write-Host "Error: $_"
        Set-Variable -Name "ok" -Value $false -Scope global
    }
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 18000
    Write-Host "Using test definitions from repo..."
    Try
    {
        proc = Start-Process -FilePath "$env:WORKSPACE\jenkins\helper\test_launch_controller.py"  -Argumentlist '"$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f launch --full --cluster'  -Wait -Passthru
        If ($proc.ExitCode -eq 0)
        {
            Set-Variable -Name "ok" -Value $true -Scope global
        }
        Else
        {
            Set-Variable -Name "ok" -Value $false -Scope global
        }
    }
    Catch
    {
        Write-Host "Error: $_"
        Set-Variable -Name "ok" -Value $false -Scope global
    }
}

runTests
