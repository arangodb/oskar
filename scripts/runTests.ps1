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
    python "$env:WORKSPACE\jenkins\helper\generate_jenkins_scripts.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f launch | Invoke-Expression
    comm
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $global:TESTSUITE_TIMEOUT = 6000

    Write-Host "Using test definitions from repo..."
    python "$env:WORKSPACE\jenkins\helper\generate_jenkins_scripts.py" "$INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -f launch --cluster | Invoke-Expression
    comm
}

runTests
