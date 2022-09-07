Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $env:TIMELIMIT = 9000
    Write-Host "Using test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions.txt -f launch --full" -logfile $false -priority "Normal"
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $env:TIMELIMIT = 16200
    Write-Host "Using test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions.txt -f launch --full --cluster" -logfile $false -priority "Normal"
}

runTests
