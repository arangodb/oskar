Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

Function global:registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."

    $env:TIMELIMIT = 3900
    Set-Variable -Name ENTERPRISE_ARG "--no-enterprise"
    If ($ENTERPRISEEDITION -eq "On")
    {
        Set-Variable -Name ENTERPRISE_ARG "--enterprise"
    }

    Write-Host "Using test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions.txt $ENTERPRISE_ARG" -logfile $false -priority "Normal" 
}

Function global:registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."

    $env:TIMELIMIT = 6600
    Set-Variable -Name ENTERPRISE_ARG "--no-enterprise"
    If ($ENTERPRISEEDITION -eq "On")
    {
        Set-Variable -Name ENTERPRISE_ARG "--enterprise"
    }

    Write-Host "Using test definitions from repo..."
    pip install py7zr
    proc -process "python.exe" -argument "$env:WORKSPACE\jenkins\helper\test_launch_controller.py $INNERWORKDIR\ArangoDB\tests\test-definitions.txt --cluster $ENTERPRISE_ARG" -logfile $false -priority "Normal"
}

runTests
