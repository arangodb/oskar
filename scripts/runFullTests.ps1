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
        python "$env:WORKSPACE\jenkins\helper\test_launch_controller.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f launch --full
        If ($LASTEXITCODE -eq 0)
        {
            echo $out | Invoke-Expression -ErrorAction Stop
        }
        Else
        {
            throw "$out"
        }
        Set-Variable -Name "ok" -Value $true -Scope global
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
        python "$env:WORKSPACE\jenkins\helper\test_launch_controller.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f launch --full --cluster
        If ($LASTEXITCODE -eq 0)
        {
            echo $out | Invoke-Expression -ErrorAction Stop
        }
        Else
        {
            throw "$out"
        }
        Set-Variable -Name "ok" -Value $true -Scope global
    }
    Catch
    {
        Write-Host "Error: $_"
        Set-Variable -Name "ok" -Value $false -Scope global
    }
}

runTests
