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
    python "$env:WORKSPACE\jenkins\helper\generate_jenkins_scripts.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f ps1 --full | Invoke-Expression
    comm
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 18000
    Write-Host "Using test definitions from repo..."
    python "$env:WORKSPACE\jenkins\helper\generate_jenkins_scripts.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f ps1 --full --cluster | Invoke-Expression
    comm
}

runTests
