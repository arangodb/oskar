Function proc($process,$argument)
{
    $p = Start-Process $process -ArgumentList $argument -NoNewWindow -PassThru
    $h = $p.Handle
    $p.WaitForExit()
    If($p.ExitCode -eq 0)
    {
        Set-Variable -Name "ok" -Value $true -Scope global
    }
    Else
    {
        Set-Variable -Name "ok" -Value $false -Scope global
    }
}

$HDD = $(Split-Path -Qualifier $env:WORKSPACE)
If(-Not(Test-Path -PathType Container -Path "$HDD\$env:NODE_NAME"))
{
    New-Item -ItemType Directory -Path "$HDD\$env:NODE_NAME"
}

$OSKARDIR = "$HDD\$env:NODE_NAME"
Set-Location $OSKARDIR

If(-Not($env:OSKAR_BRANCH))
{
    $env:OSKAR_BRANCH = "master"
}
If(-Not(Test-Path -PathType Container -Path "$OSKARDIR\oskar"))
{
    proc -process "git" -argument "clone -b $env:OSKAR_BRANCH https://github.com/arangodb/oskar"
    Set-Location "$OSKARDIR\oskar"
}
Else
{
    Set-Location "$OSKARDIR\oskar"
    proc -process "git" -argument "fetch --tags"
    proc -process "git" -argument "fetch"
    proc -process "git" -argument "reset --hard"
    proc -process "git" -argument "checkout $env:OSKAR_BRANCH"
    proc -process "git" -argument "reset --hard origin/$env:OSKAR_BRANCH"
}
Import-Module "$OSKARDIR\oskar\helper.psm1"
If(-Not($?))
{
    Write-Host "Did not find oskar modul"
    Exit 1
}
lockDirectory
updateOskar
If($(Get-Module).Name -ccontains "oskar")
{
    Remove-Module helper
}
Import-Module "$OSKARDIR\oskar\helper.psm1"
clearResults
