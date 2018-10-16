Function Get-LockingProcess([string]$path) {
[regex]$matchPattern = "(?<Name>\w+\.\w+)\s+pid:\s+(?<PID>\b(\d+)\b)\s+type:\s+(?<Type>\w+)\s+\w+:\s+(?<Path>.*)"
$data = &$(Get-Command handle) $path 
$MyMatches = $matchPattern.Matches( $data )
if ($MyMatches.value) {
      $MyMatches | foreach {
     [pscustomobject]@{ 
      FullName = $_.groups["Name"].value
      Name = $_.groups["Name"].value.split(".")[0]
      ID = $_.groups["PID"].value
      Type = $_.groups["Type"].value
      Path = $_.groups["Path"].value
     }
    }
  }
}

$HDD = $(Split-Path -Qualifier $env:WORKSPACE)
If(-Not(Test-Path -PathType Container -Path "$HDD\$env:NODE_NAME"))
{
    New-Item -ItemType Directory -Path "$HDD\$env:NODE_NAME"
}
$OSKARDIR = "$HDD\$env:NODE_NAME"
Set-Location $OSKARDIR

If(-Not(Test-Path -PathType Container -Path "$HDD\procdump"))
{
    New-Item -ItemType Directory -Path "$HDD\procdump"
}
foreach($file in  (Get-ChildItem -File -Recurse $OSKARDIR).FullName)
{
    $ID = (Get-LockingProcess $file).ID
    If($ID)
    {
        Start-Process $(Get-Command procdump) -ArgumentList "-accepteula -ma $ID $HDD\procdump\$ID.dmp" 
        Stop-Process -Force -Id $ID
    }
}

If(-Not($env:OSKAR_BRANCH))
{
    $env:OSKAR_BRANCH = "master"
}
If(-Not(Test-Path -PathType Container -Path "$OSKARDIR\oskar"))
{
    git clone -b $env:OSKAR_BRANCH https://github.com/arangodb/oskar
    Set-Location "$OSKARDIR\oskar"
}
Else
{
    Set-Location "$OSKARDIR\oskar"
    git fetch 
    git reset --hard 
    git checkout $env:OSKAR_BRANCH 
    git reset --hard origin/$env:OSKAR_BRANCH
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