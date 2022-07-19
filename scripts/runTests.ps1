Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 3900

    Write-Host "Using test definitions from repo..."
    Try
    {
        pip install py7zr
        proc = Start-Process "python" -Argumentlist '"$env:WORKSPACE\jenkins\helper\test_launch_controller.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt"'  -Wait -Passthru
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

    $global:TESTSUITE_TIMEOUT = 6000

    Write-Host "Using test definitions from repo..."
    Try
    {
        pip install py7zr
        proc = Start-Process "python" -Argumentlist '"$env:WORKSPACE\jenkins\helper\test_launch_controller.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" --cluster'  -Wait -Passthru
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
