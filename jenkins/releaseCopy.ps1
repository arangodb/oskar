If(-not((Get-SmbMapping -LocalPath B: -ErrorAction SilentlyContinue).Status -eq "OK"))
{
    New-PSDrive –Name "B" –PSProvider FileSystem –Root "\\nas02.arangodb.biz\buildfiles" –Persist
}

$dest = "b:/stage1/$env:RELEASE_TAG/release"

If(-Not(Test-Path -PathType Container -Path "$dest/packages/Community/Windows"))
{
  New-Item -ItemType Directory -Path "$dest/packages/Community/Windows"
}

If(-Not(Test-Path -PathType Container -Path "$dest/packages/Enterprise/Windows"))
{
  New-Item -ItemType Directory -Path "$dest/packages/Enterprise/Windows"
}

echo $pwd
dir

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3-*.exe").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Community/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3-*.zip").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Community/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3e-*.exe").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Enterprise/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3e-*.zip").fullName)
{
  Copy-Item "$file" -Destination "$dest/packages/Enterprise/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "download-windows-*.html").fullName)
{
  Copy-Item "$file" -Destination "$dest/snippets"
}
