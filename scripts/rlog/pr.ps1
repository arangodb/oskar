Import-Module "$PSScriptRoot\..\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $env:TIMELIMIT = 16200
    Write-Host "Using rlog test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions-rlog.txt -f launch --full --cluster" -logfile $false -priority "Normal"
}

$global:TESTSUITE = "cluster"
runTests
