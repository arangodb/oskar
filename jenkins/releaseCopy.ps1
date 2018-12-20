If(-Not(Test-Path -PathType Container -Path release/packages/Community/Windows))
{
  New-Item -ItemType Directory -Path release/packages/Community/Windows
}

If(-Not(Test-Path -PathType Container -Path release/packages/Enterprise/Windows))
{
  New-Item -ItemType Directory -Path release/packages/Enterprise/Windows
}

If(-Not(Test-Path -PathType Container -Path release/snippets))
{
  New-Item -ItemType Directory -Path release/snippets
}

echo $pwd
dir

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3-*.exe").fullName)
{
  Copy-Item "$file" -Destination "release/packages/Community/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3-*.zip").fullName)
{
  Copy-Item "$file" -Destination "release/packages/Community/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3e-*.exe").fullName)
{
  Copy-Item "$file" -Destination "release/packages/Enterprise/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "ArangoDB3e-*.zip").fullName)
{
  Copy-Item "$file" -Destination "release/packages/Enterprise/Windows"
}

ForEach($file in $(Get-ChildItem -Path . -Filter "download-windows-*.html").fullName)
{
  Copy-Item "$file" -Destination "release/snippets"
}
