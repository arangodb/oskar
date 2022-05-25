Import-Module "$PSScriptRoot\..\lib\Utils.psm1"

. "$global:ARANGODIR\tests\Definition\rlog\pr.ps1"

$global:TESTSUITE = "tests"
runTests