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
        $out = python "$env:WORKSPACE\jenkins\helper\generate_jenkins_scripts.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f ps1 --full
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
        $out = python "$env:WORKSPACE\jenkins\helper\generate_jenkins_scripts.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f ps1 --full --cluster
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
