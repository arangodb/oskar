Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $env:TIMELIMIT = 3900

    Write-Host "Using test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions.txt" -logfile $false -priority "Normal"
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $env:TIMELIMIT = 6600

    Write-Host "Using test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions.txt --cluster" -logfile $false -priority "Normal"
}

runTests
