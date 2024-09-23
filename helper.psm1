$global:WORKDIR = $pwd
$global:SCRIPTSDIR = Join-Path -Path $global:WORKDIR -ChildPath scripts

If (-Not($ENV:WORKSPACE))
{
    $ENV:WORKSPACE = Join-Path -Path $global:WORKDIR -ChildPath work
}

If (-Not($ENV:OSKAR_BRANCH))
{
    $ENV:OSKAR_BRANCH = "master"
}

If (-Not($ENV:ARANGODB_GIT_HOST))
{
    $ENV:ARANGODB_GIT_HOST = "github.com"
}

If (-Not($ENV:ARANGODB_GIT_ORGA))
{
    $ENV:ARANGODB_GIT_ORGA = "arangodb"
}

If (-Not($ENV:HELPER_GIT_ORGA))
{
    $ENV:HELPER_GIT_ORGA = "arangodb-helper"
}

If (-Not($ENV:ENTERPRISE_GIT_HOST))
{
    $ENV:ENTERPRISE_GIT_HOST = "github.com"
}

If (-Not($ENV:ENTERPRISE_GIT_ORGA))
{
    $ENV:ENTERPRISE_GIT_ORGA = "arangodb"
}

If (-Not(Test-Path -PathType Container -Path "work"))
{
    New-Item -ItemType Directory -Path "work"
}

$ENV:TSHARK = ((Get-ChildItem -ErrorAction SilentlyContinue -Recurse "${env:ProgramFiles}" tshark.exe).FullName | Select-Object -Last 1)

If (-Not("$ENV:TSHARK"))
{
    Write-Host "failed to locate TSHARK"
}
Else
{
    If ((. $ENV:TSHARK -D | Select-String -SimpleMatch Npcap ) -match '^(\d).*')
    {
        $ENV:DUMPDEVICE = $Matches[1]
        If ($ENV:DUMPDEVICE -notmatch '\d+') {
            Write-Host "unable to detect the loopback-device. we expect this to have an Npcacp one:"
            . $ENV:TSHARK -D
            Exit 1
        }
        Else {
            $ENV:DUMPDEVICE="Npcap Loopback Adapter"
        }
    }
    Else
    {
        Write-Host "failed to get loopbackdevice - check NCAP Driver installation"
        $ENV:TSHARK = ""
  }
}

$global:HANDLE_EXE = $null
If (Get-Command handle.exe -ErrorAction SilentlyContinue)
{
    $global:HANDLE_EXE = (Get-Command handle.exe).Source -Replace ' ', '` '
}

$global:PSKILL_EXE = $null
If (Get-Command pskill.exe -ErrorAction SilentlyContinue)
{
    $global:PSKILL_EXE = (Get-Command pskill.exe).Source -Replace ' ', '` '
}

$global:REG_WER = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"
$global:COREDIR = "$ENV:WORKSPACE\core"
If (-Not(Test-Path -Path $global:COREDIR))
{
  New-Item -ItemType "directory" -Path "$global:COREDIR"
}
Else
{
  Remove-Item "$global:COREDIR\*" -Recurse -Force
}
$ENV:COREDIR=$global:COREDIR
$global:INNERWORKDIR = "$WORKDIR\work"
$global:ARANGODIR = "$INNERWORKDIR\ArangoDB"
$global:ENTERPRISEDIR = "$global:ARANGODIR\enterprise"
$ENV:TMP = "$INNERWORKDIR\tmp"
$global:ARANGODB_BUILD_DATE = "$ENV:ARANGODB_BUILD_DATE"

Function setVisualStudioEnvs
{
    param (
        [Parameter(Mandatory=$true)]
        $patternVersion
    )
    $installationPath = $(Get-VSSetupInstance | Select-VSSetupInstance -Version $patternVersion).InstallationPath
    if ("$installationPath" -and (test-path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
        & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -no_logo && set" | foreach-object {
        $name, $value = $_ -split '=', 2
        set-content env:\"$name" $value
        }
    }
}
Function VS2019
{
    $ENV:CLCACHE_CL = $($(Get-ChildItem $(Get-VSSetupInstance -All | Where {$_.DisplayName -match "Visual Studio Community 2019"}).InstallationPath -Filter cl_original.exe -Recurse | Select-Object Fullname | Where {$_.FullName -match "Hostx64\\x64"}).FullName | Select-Object -Last 1)
    $global:GENERATOR = "Visual Studio 16 2019"
    $global:GENERATORID = "v142"
    $global:MSVS = "2019"
    setVisualStudioEnvs "[16.0,17.0)"
}

Function VS2022
{
    $ENV:CLCACHE_CL = $($(Get-ChildItem $(Get-VSSetupInstance -All | Where {$_.DisplayName -match "Visual Studio Community 2022"}).InstallationPath -Filter cl_original.exe -Recurse | Select-Object Fullname | Where {$_.FullName -match "Hostx64\\x64"}).FullName | Select-Object -Last 1)
    $global:GENERATOR = "Visual Studio 17 2022"
    $global:GENERATORID = "v143"
    $global:MSVS = "2022"
}

If (-Not($global:GENERATOR))
{
    VS2019
}

Function findCompilerVersion
{
    If (Test-Path -Path "$global:ARANGODIR\VERSIONS")
    {
        $MSVC_WINDOWS = Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "MSVC_WINDOWS" | Select Line
        If ($MSVC_WINDOWS)
        {
            $MSVC_WINDOWS -match "`"(?<version>[0-9\.]*)`"" | Out-Null

	    switch ($Matches['version'])
	    {
		2019    { VS2019 ; $global:MSVS_COMPILER = "" }
		2022    { VS2022 ; $global:MSVS_COMPILER = ",version=14.32.31326" }
		"17.0"  { VS2022 ; $global:MSVS_COMPILER = ",version=14.30.30705" }
		"17.1"  { VS2022 ; $global:MSVS_COMPILER = ",version=14.31.31103" }
		"17.2"  { VS2022 ; $global:MSVS_COMPILER = ",version=14.32.31326" }
		"17.3"  { VS2022 ; $global:MSVS_COMPILER = ",version=14.33.31629" }
		default { VS2019 ; $global:MSVS_COMPILER = "" }
	    }

            return
        }
    }

    VS2019
}

findCompilerVersion
$ENV:CLCACHE_DIR = "$INNERWORKDIR\.clcache.windows"
$ENV:CMAKE_CONFIGURE_DIR = "$INNERWORKDIR\.cmake.windows"
$ENV:CLCACHE_LOG = 0
$ENV:CLCACHE_HARDLINK = 1
$ENV:CLCACHE_OBJECT_CACHE_TIMEOUT_MS = 120000

$global:launcheableTests = @()
$global:maxTestCount = 0
$global:testCount = 0
$global:portBase = 10000
$global:result = "GOOD"
$global:hasTestCrashes = $False

$global:ok = $true

If (-Not(Test-Path -Path $ENV:TMP))
{
  New-Item -ItemType "directory" -Path "$ENV:TMP"
}
If (-Not(Test-Path -Path $ENV:CMAKE_CONFIGURE_DIR))
{
  New-Item  -ItemType "directory" -Path "$ENV:CMAKE_CONFIGURE_DIR"
}

################################################################################
# Utilities
################################################################################

While (Test-Path Alias:curl) 
{
    Remove-Item Alias:curl
}

Function proc($process,$argument,$logfile,$priority)
{
    If (!$priority)
    {
        $priority = "Normal"
    }
    If ($logfile -eq $false)
    {
        $p = Start-Process $process -ArgumentList $argument -NoNewWindow -PassThru
        $p.PriorityClass = $priority
        $h = $p.Handle
        $p.WaitForExit()
        If ($p.ExitCode -ne 0)
        {
            Set-Variable -Name "ok" -Value $false -Scope global
        }
        Else
        {
            Set-Variable -Name "ok" -Value $true -Scope global
        }
    }
    Else
    {
        $p = Start-Process $process -ArgumentList $argument -RedirectStandardOutput "$logfile.stdout.log" -RedirectStandardError "$logfile.stderr.log" -PassThru
        $p.PriorityClass = $priority
        $h = $p.Handle
        $p.WaitForExit()
        If ($p.ExitCode -ne 0)
        {
            Set-Variable -Name "ok" -Value $false -Scope global
        }
        Else
        {
            Set-Variable -Name "ok" -Value $true -Scope global
        }
    }
}

Function comm
{
    Set-Variable -Name "ok" -Value $? -Scope global
}

Function 7zip($Path,$DestinationPath,$moreArgs)
{
    Write-Host "7z.exe" -argument "a -mx9 $DestinationPath $Path $moreArgs" -logfile $false -priority "Normal" 
    proc -process "7z.exe" -argument "a -mx9 $DestinationPath $Path $moreArgs" -logfile $false -priority "Normal" 
}

Function 7unzip($zip)
{
    Write-Host "7z.exe" -argument "x $zip -aoa" -logfile $false -priority "Normal" 
    proc -process "7z.exe" -argument "x $zip -aoa" -logfile $false -priority "Normal" 
}

Function isGCE
{
    return "$ENV:COMPUTERNAME" -eq "JENKINS-WIN-GCE"
}

Function hostKey
{
    If (Test-Path -PathType Leaf -Path "$HOME\.ssh\known_hosts")
    {
        Remove-Item -Force "$HOME\.ssh\known_hosts"
    }
    git config --global core.sshCommand 'ssh -o UserKnownHostsFile=C:\Users\Administrator\.ssh\known_hosts -o StrictHostKeyChecking=no'
}

Function clearWER
{
    Remove-Item "$global:REG_WER" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item "$global:REG_WER" -Force | Out-Null
}

Function configureWER($executable, $path)
{
    Write-Host "Configure crashdumps location for $executable processes"
    $regPath = "$global:REG_WER\$executable"
    Remove-Item "$regPath" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item "$regPath" -Force | Out-Null
    New-ItemProperty "$regPath" -Name DumpFolder -PropertyType ExpandString -Value "$path" -Force | Out-Null
    New-ItemProperty "$regPath" -Name DumpCount -PropertyType DWord -Value 100 -Force | Out-Null
    New-ItemProperty "$regPath" -Name DumpType -PropertyType DWord -Value 2 -Force | Out-Null
}

$global:OPENSSL_DEFAULT_VERSION = "1.1.0l"
$global:OPENSSL_VERSION = $global:OPENSSL_DEFAULT_VERSION

$global:OPENSSL_MODES = "release", "debug"
$global:OPENSSL_TYPES = "static", "shared"

Function oskarOpenSSL
{
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    $global:USE_OSKAR_OPENSSL = "On"
    findCompilerVersion
    findRequiredOpenSSL
    $global:OPENSSL_PATH = $(If (isGCE) {"C:"} Else {"${global:INNERWORKDIR}"}) + "\OpenSSL\${OPENSSL_VERSION}"
    Write-Host "Use OpenSSL within oskar: build ${OPENSSL_VERSION} if not present in ${OPENSSL_PATH}"
    $IS_OPENSSL_3 = "$global:OPENSSL_VERSION" -like '3.*'
    If ($IS_OPENSSL_3)
    {
      $global:ok = (checkOpenSSL $(If (isGCE) {"C:"} Else {"${global:INNERWORKDIR}"}) $OPENSSL_VERSION $MSVS "release" "static" $true)
    }
    Else
    {
      $global:ok = (checkOpenSSL $(If (isGCE) {"C:"} Else {"${global:INNERWORKDIR}"}) $OPENSSL_VERSION $MSVS ${OPENSSL_MODES} ${OPENSSL_TYPES} $true)
    }
    If ($global:ok)
    {
      Write-Host "Set OPENSSL_ROOT_DIR via environment variable to $OPENSSL_PATH"
      $ENV:OPENSSL_ROOT_DIR = $OPENSSL_PATH
    }
    Else
    {
      Write-Host "Error during checking and building OpenSSL with oskar!"
    }
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
}

Function ownOpenSSL
{
    $global:USE_OSKAR_OPENSSL = "Off"
}

If (-Not($USE_OSKAR_OPENSSL))
{
    $global:USE_OSKAR_OPENSSL = "On"
}

Function checkOpenSSL ($path, $version, $msvs, [string[]] $modes, [string[]] $types, $doBuild)
{
  $count = 0
  Push-Location
  If (Test-Path -PathType Container -Path "${path}\OpenSSL\${version}\VS_${msvs}")
  {
    ForEach ($mode In $modes)
    {
      ForEach ($type In $types)
      {
        $OPENSSL_BUILD="${type}-${mode}"
        $OPENSSL_CHECK_PATH="${path}\OpenSSL\${version}\VS_${msvs}\${OPENSSL_BUILD}"
        If (Test-Path -PathType Leaf -Path "${OPENSSL_CHECK_PATH}\bin\openssl.exe")
        {
          Set-Location "${OPENSSL_CHECK_PATH}\bin"
          If ((.\openssl.exe version | Select-String -Pattern "${version}").Length -eq 1)
          {
            $count++
          }
          Else
          {
            If ($doBuild)
            {
              Write-Host "Building OpenSSL ${version} (${OPENSSL_BUILD}) due to wrong version in ${OPENSSL_CHECK_PATH}"
              If (buildOpenSSL $path $version $msvs $mode $type)
              {
                $count++
              }
            }
          }
        }
        Else
        {
          If ($doBuild)
          {
            Write-Host "Building OpenSSL ${version} (${OPENSSL_BUILD}) due to no build in ${OPENSSL_CHECK_PATH}"
            If (buildOpenSSL $path $version $msvs $mode $type)
            {
              $count++
            }
          }
        }
      }
    }
  }
  Else 
  {
    If ($doBuild)
    {
      Write-Host "Build OpenSSL ${version} all necessary configurations: {$modes} x {$types}"
      If (buildOpenSSL $path $version $msvs $modes $types)
      {
        $count = ($modes.Length * $types.Length)
      }
    }
  }
  Pop-Location
  return $count -eq ($modes.Length * $types.Length)
}

Function buildOpenSSL ($path, $version, $msvs, [string[]] $modes, [string[]] $types)
{
  Push-Location
  $OPENSSL_TAG="OpenSSL_" + ($version -Replace "\.","_")
  If ("$version" -like '3.*')
  {
    $OPENSSL_TAG="openssl-$version"
  }
  If (-Not(Test-Path -PathType Container -Path "${global:INNERWORKDIR}\OpenSSL\tmp_${msvs}"))
  {
    mkdir "${global:INNERWORKDIR}\OpenSSL\tmp_${msvs}"
  }
  Else
  {
    Remove-Item -Recurse -Force -Path "${global:INNERWORKDIR}\OpenSSL\tmp_${msvs}\*"
  }
  If ($global:ok)
  {
    proc -process "git"  -argument "clone -q -b $OPENSSL_TAG https://github.com/openssl/openssl ${global:INNERWORKDIR}\OpenSSL\tmp_${msvs}" -logfile $false -priority "Normal"
    Set-Location "${global:INNERWORKDIR}\OpenSSL\tmp_${msvs}"
    If ($global:ok)
    {
      proc -process "git" -argument "fetch -q" -logfile $false -priority "Normal"
      If ($global:ok)
      {
        proc -process "git" -argument "reset -q --hard $OPENSSL_TAG"  -logfile $false -priority "Normal"
        If ($global:ok)
        {
          proc -process "git" -argument "clean -q -fdx"
          ForEach ($mode In $modes)
          {
            ForEach ($type In $types)
            {
              $OPENSSL_BUILD="${type}-${mode}"
              $ENV:installdir = "${path}\OpenSSL\${version}\VS_${msvs}\${OPENSSL_BUILD}"
              If (Test-Path -PathType Leaf -Path "$ENV:installdir")
              {
                  Remove-Item -Force -Recurse -Path "${env:installdir}\*"
                  New-Item -Path "${env:installdir}"
              }
              If ($type -eq "static")
              {
                $CONFIG_TYPE = "no-shared"
              }
              Else
              {
                $CONFIG_TYPE = "${type}"
              }
              $MSVS_PATH="${Env:ProgramFiles(x86)}\Microsoft Visual Studio\$msvs"
              If (-Not (Test-Path -Path "$MSVS_PATH"))
              {
                  $MSVS_PATH="${Env:ProgramFiles}\Microsoft Visual Studio\$msvs"
              }
              $buildCommand = "call `"$MSVS_PATH\Community\Common7\Tools\vsdevcmd`" -arch=amd64 && perl Configure $CONFIG_TYPE --$mode --prefix=`"${env:installdir}`" --openssldir=`"${env:installdir}\ssl`" VC-WIN64A && nmake clean && set CL=/MP && nmake && nmake install"
              Invoke-Expression "& cmd /c '$buildCommand' 2>&1" | tee "${INNERWORKDIR}\buildOpenSSL_${type}-${mode}-${msvs}.log"
              If (-Not ($?)) { $global:ok = $false }
            }
          }
        }
      }
    }
  }
  Pop-Location
  return $global:ok
}

################################################################################
# Locking
################################################################################

Function lockDirectory
{
    Push-Location $pwd
    Set-Location $WORKDIR
    hostKey
    If (-Not(Test-Path -PathType Leaf LOCK.$pid))
    {
        $pid | Add-Content LOCK.$pid
        While($true)
        {
            If ($pidfound = Get-Content LOCK -ErrorAction SilentlyContinue)
            {
                If (-Not(Get-Process -Id $pidfound -ErrorAction SilentlyContinue))
                {
                    Remove-Item LOCK
                    Remove-Item LOCk.$pidfound
                    Write-Host "Removed stale lock"
                }
            }
            If (New-Item -ItemType HardLink -Name LOCK -Value LOCK.$pid -ErrorAction SilentlyContinue)
            {
               Break
            }
            Write-Host "Directory is locked, waiting..."
            $(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH.mm.ssZ")
            Start-Sleep -Seconds 15
        }
    }
    comm 
    Pop-Location
}

Function unlockDirectory
{
    Push-Location $pwd
    Set-Location $WORKDIR
    If (Test-Path -PathType Leaf LOCK.$pid)
    {
        Remove-Item LOCK
        Remove-Item LOCK.$pid
        Write-Host "Removed lock"
    }
    comm
    Pop-Location   
}

################################################################################
# Configure Oskar
################################################################################

Function trimCache
{
    If ($CLCACHE -eq "On")
    {
        If ($ENV:CLCACHE_CL)
        {
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-c" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
        }
        Else
        {
            Write-Host "No clcache installed!"
        }
    }
    Else
    {
        Write-Host "Clcache usage is disabled!"
    }
}

Function clearCache
{
    If ($CLCACHE -eq "On")
    {
        If ($ENV:CLCACHE_CL)
        {
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-C" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-z" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
        }
        Else
        {
            Write-Host "No clcache installed!"
        }
    }
    Else
    {
        Write-Host "Clcache usage is disabled!"
    }
}

Function configureCache
{
    If ($CLCACHE -eq "On")
    {
        If ($ENV:CLCACHE_CL)
        {
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-M 107374182400" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
            
        }
        Else
        {
            Write-Host "No clcache installed!"
        }
    }
    Else
    {
        Write-Host "Clcache usage is disabled!"
    }
}

Function showCacheStats
{
    If ($CLCACHE -eq "On")
    {
        If ($ENV:CLCACHE_CL)
        {
            $tmp_stats = $global:ok
            proc -process "$(Split-Path $ENV:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
            $global:ok = $tmp_stats
        }
        Else
        {
            Write-Host "No clcache installed!"
        }
    }
    Else
    {
        Write-Host "Clcache usage is disabled!"
    }
}

Function showConfig
{
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "Global Configuration"
    Write-Host "User           : "$ENV:USERDOMAIN\$ENV:USERNAME
    Write-Host "Path           : "$ENV:PATH
    Write-Host "Use cache      : "$CLCACHE
    Write-Host "Cache          : "$ENV:CLCACHE_CL
    Write-Host "Cachedir       : "$ENV:CLCACHE_DIR
    Write-Host "CMakeConfigureCache      : "$ENV:CMAKE_CONFIGURE_DIR
    Write-Host " "
    Write-Host "Build Configuration"
    Write-Host "Buildmode      : "$BUILDMODE
    Write-Host "Enterprise     : "$ENTERPRISEEDITION
    Write-Host "Maintainer     : "$MAINTAINER
    Write-host "SkipNondeterministic       : "$SKIPNONDETERMINISTIC
    Write-host "SkipTimeCritical       : "$SKIPTIMECRITICAL
    Write-host "SkipGrey       : "$SKIPGREY
    Write-host "OnlyGrey       : "$ONLYGREY
    Write-Host " "
    Write-Host "Generator      : "$GENERATOR
    Write-Host "OpenSSL        :  ${OPENSSL_VERSION} (A.B.Cd)"
    Write-Host "Use oskar SSL  : "$USE_OSKAR_OPENSSL
    Write-Host "Packaging      : "$PACKAGING
    Write-Host "Static exec    : "$STATICEXECUTABLES
    Write-Host "Static libs    : "$STATICLIBS
    Write-Host "Failure tests  : "$USEFAILURETESTS
    Write-Host "Keep build     : "$KEEPBUILD
    Write-Host "PDBs workspace : "$PDBS_TO_WORKSPACE
    Write-Host "PDBs archive:  : "$PDBS_ARCHIVE_TYPE
    Write-Host "DMP workspace  : "$ENABLE_REPORT_DUMPS
    Write-Host "Use rclone     : "$USE_RCLONE
    Write-Host "Sign package   : "$SIGN
    Write-Host " "
    Write-Host "Test Configuration"
    Write-Host "Storage engine : "$STORAGEENGINE
    Write-Host "Test suite     : "$TESTSUITE
    Write-Host " "
    Write-Host "Internal Configuration"
    Write-Host "Parallelism    : "$numberSlots
    Write-Host "Verbose        : "$VERBOSEOSKAR
    Write-Host "Logs preserve  : "$WORKSPACE_LOGS
    Write-Host " "
    Write-Host "Directories"
    Write-Host "Inner workdir  : "$INNERWORKDIR
    Write-Host "Workdir        : "$WORKDIR
    Write-Host "Workspace      : "$ENV:WORKSPACE
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "Cache Statistics"
    showCacheStats
    $ENV:SKIPNONDETERMINISTIC = $SKIPNONDETERMINISTIC
    $ENV:SKIPTIMECRITICAL = $SKIPTIMECRITICAL
    $ENV:SKIPGREY = $SKIPGREY
    $ENV:ONLYGREY = $ONLYGREY
    $ENV:BUILDMODE = $BUILDMODE
    comm
}

Function single
{
    $global:TESTSUITE = "single"
}
Function cluster
{
    $global:TESTSUITE = "cluster"
}
Function resilience
{
    $global:TESTSUITE = "resilience"
}
Function catchtest
{
    $global:TESTSUITE = "catchtest"
    $global:TIMELIMIT = 1800
}
If (-Not($TESTSUITE))
{
    cluster
}

Function skipPackagingOn
{
    $global:SKIPPACKAGING = "On"
    $global:PACKAGING = "Off"
    $global:USEFAILURETESTS = "On"
}
Function skipPackagingOff
{
    $global:SKIPPACKAGING = "Off"
    $global:PACKAGING = "On"
    $global:USEFAILURETESTS = "Off"
}
Function packagingOn
{
    $global:SKIPPACKAGING = "Off"
    $global:PACKAGING = "On"
    $global:USEFAILURETESTS = "Off"
}
Function packagingOff
{
    $global:SKIPPACKAGING = "On"
    $global:PACKAGING = "Off"
    $global:USEFAILURETESTS = "On"
}
If (-Not($SKIPPACKAGING))
{
    skipPackagingOff
}

Function staticExecutablesOn
{
    $global:STATICEXECUTABLES = "On"
    $global:STATICLIBS = "true"
}
Function staticExecutablesOff
{
    $global:STATICEXECUTABLES = "Off"
    $global:STATICLIBS = "false"
}
If (-Not($STATICEXECUTABLES))
{
    staticExecutablesOff
}

Function signPackageOn
{
    $global:SIGN = $true
}
Function signPackageOff
{
    $global:SIGN = $false
}
If (-Not($SIGN))
{
    signPackageOff
}

Function maintainerOn
{
    $global:MAINTAINER = "On"
}
Function maintainerOff
{
    $global:MAINTAINER = "Off"
}
If (-Not($MAINTAINER))
{
    maintainerOn
}

Function clcacheOn
{
    $global:CLCACHE = "On"
    Remove-Item Env:\CLCACHE_DISABLE
}
Function clcacheOff
{
    $global:CLCACHE = "Off"
    $ENV:CLCACHE_DISABLE = "1"
}
If (-Not($CLCACHE))
{
    clcacheOff
}

Function skipNondeterministic
{
    $global:SKIPNONDETERMINISTIC = "true"
}
Function includeNondeterministic
{
    $global:SKIPNONDETERMINISTIC = "false"
}
If (-Not($SKIPNONDETERMINISTIC))
{
    skipNondeterministic
}

Function skipTimeCritical
{
    $global:SKIPTIMECRITICAL = "true"
}
Function includeTimeCritical
{
    $global:SKIPTIMECRITICAL = "false"
}
If (-Not($SKIPTIMECRITICAL))
{
    skipTimeCritical
}

Function skipGrey
{
    $global:SKIPGREY = "true"
}
Function includeGrey
{
    $global:SKIPGREY = "false"
}
If (-Not($SKIPGREY))
{
    includeGrey
}

Function onlyGreyOn
{
    $global:ONLYGREY = "true"
}
Function onlyGreyOff
{
    $global:ONLYGREY = "false"
}
If (-Not($ONLYGREY))
{
    onlyGreyOff
}

Function debugMode
{
    $global:BUILDMODE = "Debug"
}
Function releaseMode
{
    $global:BUILDMODE = "RelWithDebInfo"
}
Function releaseModeNoSymbols
{
    $global:BUILDMODE = "Release"
}
If (-Not($BUILDMODE))
{
    releaseMode
}

Function community
{
    $global:ENTERPRISEEDITION = "Off"
}

Function enterprise
{
    $global:ENTERPRISEEDITION = "On"
}

If (-Not($ENTERPRISEEDITION))
{
    enterprise
}

Function mmfiles
{
    $global:STORAGEENGINE = "mmfiles"
}

Function rocksdb
{
    $global:STORAGEENGINE = "rocksdb"
}

If (-Not($STORAGEENGINE))
{
    rocksdb
}

Function verbose
{
    $global:VERBOSEOSKAR = "On"
}

Function silent
{
    $global:VERBOSEOSKAR = "Off"
}

If (-Not($VERBOSEOSKAR))
{
    verbose
}

Function parallelism($threads)
{
    $global:numberSlots = $threads
}

If (-Not($global:numberSlots))
{
    $global:numberSlots = ($(Get-WmiObject Win32_processor).NumberOfLogicalProcessors)
}

Function keepBuild
{
    $global:KEEPBUILD = "On"
}

Function clearBuild
{
    $global:KEEPBUILD = "Off"
}

If (-Not ($KEEPBUILD))
{
    $global:KEEPBUILD = "Off"
}

Function setAllLogsToWorkspace
{
    $global:WORKSPACE_LOGS = "all"
}

Function setOnlyFailLogsToWorkspace
{
    $global:WORKSPACE_LOGS = "fail"
}

If (-Not ($global:WORKSPACE_LOGS))
{
    setOnlyFailLogsToWorkspace
}

Function setPDBsToWorkspaceOnCrashOnly
{
    $global:PDBS_TO_WORKSPACE = "crash"
}

Function setPDBsToWorkspaceAlways
{
    $global:PDBS_TO_WORKSPACE = "always"
}

If (-Not($WORKSPACE_PDB_CRASH_ONLY))
{
    $global:PDBS_TO_WORKSPACE = "always"
}

Function setPDBsArchiveZip
{
    $global:PDBS_ARCHIVE_TYPE = "zip"
}

Function setPDBsArchive7z
{
    $global:PDBS_ARCHIVE_TYPE = "7z"
}

If (-Not($PDBS_ARCHIVE_TYPE))
{
    $global:PDBS_ARCHIVE_TYPE = "zip"
}

Function disableDumpsToReport
{
    $global:ENABLE_REPORT_DUMPS = "off"
}

Function enableDumpsToReport
{
    $global:ENABLE_REPORT_DUMPS = "on"
}

If (-Not($ENABLE_REPORT_DUMPS))
{
    enableDumpsToReport
}

Function findRcloneVersion
{
    $global:RCLONE_VERSION = "1.51.0"

    If (Test-Path -Path "$global:ARANGODIR\VERSIONS")
    {
        $RCLONE_VERSION = Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "RCLONE_VERSION" | Select Line
        If ($RCLONE_VERSION -ne "")
        {
            If ($RCLONE_VERSION -match '[0-9]+\.[0-9]+\.[0-9]+' -And $Matches.count -eq 1)
            {
                $global:RCLONE_VERSION = $Matches[0]
            }
        }
    }

    setupSourceInfo "Rclone" "$global:RCLONE_VERSION"
}

Function findUseRclone
{
    If (Test-Path -Path "$global:ARANGODIR\VERSIONS")
    {
        $USE_RCLONE = Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "USE_RCLONE" | Select Line
        If ($USE_RCLONE -ne "")
        {
            $USE_RCLONE -match 'true|false' | Out-Null
            If ($Matches.count -eq 1)
            {
                $global:USE_RCLONE = $Matches[0]
                return
            }
        }
    }

    $global:USE_RCLONE = "false"
}

If (-Not($USE_RCLONE))
{
    findUseRclone
}

Function findRequiredOpenSSL
{
    If (Test-Path -Path "$global:ARANGODIR\VERSIONS")
    {
        $OPENSSL_WINDOWS = Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "OPENSSL_WINDOWS" | Select Line
        If ($OPENSSL_WINDOWS -ne "")
        {
            If ($OPENSSL_WINDOWS -match '[0-9]{1}\.[0-9]{1}\.[0-9]+[a-z]?' -And $Matches.count -eq 1)
            {
                $global:OPENSSL_VERSION = $Matches[0]
                return
            }
        }
    }
    Write-Host "No VERSIONS file with proper OPENSSL_WINDOWS record found! Using default version: ${OPENSSL_DEFAULT_VERSION}"
    $global:OPENSSL_VERSION = $global:OPENSSL_DEFAULT_VERSION
}

Function defaultBuildRepoInfo
{
    $global:BUILD_REPO_INFO = "default"
}

Function releaseBuildRepoInfo
{
    $global:BUILD_REPO_INFO = "release"
}

Function nightlyBuildRepoInfo
{
    $global:BUILD_REPO_INFO = "nightly"
}

If (-Not($BUILD_REPO_INFO))
{
    defaultBuildRepoInfo
}
Else 
{
    $global:BUILD_REPO_INFO = "$BUILD_REPO_INFO"
}

# ##############################################################################
# Version detection
# ##############################################################################

Function findArangoDBVersion
{
    If ($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_MAJOR")[0] -match '.*"([0-9a-zA-Z]*)".*')
    {
        $global:ARANGODB_VERSION_MAJOR = $Matches[1]
        If ($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_MINOR")[0] -match '.*"([0-9a-zA-Z]*)".*')
        {
            $global:ARANGODB_VERSION_MINOR = $Matches[1]
            
            $34AndAbove = Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_PATCH"
            $33AndBelow = Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_REVISION"
            
            If (($34AndAbove, "")[!$34AndAbove].toString() + ($33AndBelow, "")[!$33AndBelow].toString() -match '.*"([0-9a-zA-Z]*)".*')
            {
                $global:ARANGODB_VERSION_PATCH = $Matches[1]
                If ($34AndAbove -and $(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_RELEASE_TYPE")[0] -match '.*"([0-9a-zA-Z]*)".*')
                {
                    $global:ARANGODB_VERSION_RELEASE_TYPE = $Matches[1]
                    If ($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_RELEASE_NUMBER")[0] -match '.*"([0-9a-zA-Z]*)".*')
                    {
                        $global:ARANGODB_VERSION_RELEASE_NUMBER = $Matches[1]  
                    }
                }

            }
        }

    }
    $global:ARANGODB_VERSION = "$global:ARANGODB_VERSION_MAJOR.$global:ARANGODB_VERSION_MINOR.$global:ARANGODB_VERSION_PATCH"
    $global:ARANGODB_REPO = "arangodb$global:ARANGODB_VERSION_MAJOR$global:ARANGODB_VERSION_MINOR"
    If ($global:ARANGODB_VERSION_RELEASE_TYPE)
    {
        If ($global:ARANGODB_VERSION_RELEASE_NUMBER)
        {
            $global:ARANGODB_FULL_VERSION = "$global:ARANGODB_VERSION-$global:ARANGODB_VERSION_RELEASE_TYPE.$global:ARANGODB_VERSION_RELEASE_NUMBER"
        }
        Else
        {
            $global:ARANGODB_FULL_VERSION = "$global:ARANGODB_VERSION-$global:ARANGODB_VERSION_RELEASE_TYPE"
        }
        
    }
    Else
    {
        $global:ARANGODB_FULL_VERSION = $global:ARANGODB_VERSION
    }
    return $global:ARANGODB_FULL_VERSION
}

################################################################################
# Upload Symbols to Google Drive
################################################################################

Function uploadSymbols
{
    findArangoDBVersion
    proc -process "ssh" -argument "root@symbol.arangodb.biz cd /script/ && python program.py /mnt/symsrv_$global:ARANGODB_REPO" -logfile $true -priority "Normal"; comm
    proc -process "ssh" -argument "root@symbol.arangodb.biz gsutil -m rsync -r /mnt/symsrv_$global:ARANGODB_REPO gs://download.arangodb.com/symsrv_$global:ARANGODB_REPO" -logfile $true -priority "Normal"; comm
}

################################################################################
# include External resources starter, syncer
################################################################################

Function downloadStarter
{
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "STARTER_REV").Line -match '(v[0-9]+.[0-9]+.[0-9]+[\-]?[0-9a-z]*[\-]?[0-9]?)|latest' | Out-Null
    $STARTER_REV = $Matches[0]    
    If ($STARTER_REV -eq "")
    {
        Write-Host "Failed to identify STARTER_REV from VERSIONS file!"
    }
    Else
    {
        Write-Host "Identified STARTER_REV is $STARTER_REV"
    }
    If ($STARTER_REV -eq "latest")
    {
        $JSON = Invoke-WebRequest -Uri 'https://api.$ENV:ARANGODB_GIT_HOST/repos/$ENV:HELPER_GIT_ORGA/arangodb/releases/latest' -UseBasicParsing | ConvertFrom-Json
        $STARTER_REV = $JSON.name
    }
    Write-Host "Download: Starter"
    (New-Object System.Net.WebClient).DownloadFile("https://$ENV:ARANGODB_GIT_HOST/$ENV:HELPER_GIT_ORGA/arangodb/releases/download/$STARTER_REV/arangodb-windows-amd64.exe","$global:ARANGODIR\build\arangodb.exe")
    setupSourceInfo "Starter" $STARTER_REV
}

Function downloadSyncer
{
    If ($global:ARANGODB_VERSION_MAJOR -eq 3 -And $global:ARANGODB_VERSION_MINOR -lt 12)
    {
        Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        If (-Not($ENV:DOWNLOAD_SYNC_USER))
        {
            Write-Host "Need environment variable set!"
        }
        (Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "SYNCER_REV").Line -match 'v?([0-9]+.[0-9]+.[0-9]+(-preview-[0-9]+)?)|latest' | Out-Null
        $SYNCER_REV = $Matches[0]
        If ($SYNCER_REV -eq "latest")
        {
            $JSON = curl -s -L "https://$ENV:DOWNLOAD_SYNC_USER@api.$ENV:ARANGODB_GIT_HOST/repos/$ENV:ARANGODB_GIT_ORGA/arangosync/releases/latest" | ConvertFrom-Json
            $SYNCER_REV = $JSON.name
        }
        $ASSET = curl -s -L "https://$ENV:DOWNLOAD_SYNC_USER@api.$ENV:ARANGODB_GIT_HOST/repos/$ENV:ARANGODB_GIT_ORGA/arangosync/releases/tags/$SYNCER_REV" | ConvertFrom-Json
        $ASSET_ID = $(($ASSET.assets) | Where-Object -Property name -eq arangosync-windows-amd64.exe).id
        Write-Host "Download: Syncer $SYNCER_REV"
        curl -s -L -H "Accept: application/octet-stream" "https://$ENV:DOWNLOAD_SYNC_USER@api.$ENV:ARANGODB_GIT_HOST/repos/$ENV:ARANGODB_GIT_ORGA/arangosync/releases/assets/$ASSET_ID" -o "$global:ARANGODIR\build\arangosync.exe"
        If (Select-String -Path "$global:ARANGODIR\build\arangosync.exe" -Pattern '"message": "Not Found"')
        {
            Write-Host "Download: Syncer FAILED!"
            $global:ok = $false
        }
        Else
        {
            setupSourceInfo "Syncer" $SYNCER_REV
        }
    }
}

Function copyRclone
{
    findUseRclone
    If ($global:USE_RCLONE -eq "false")
    {
        Write-Host "Not copying rclone since it's not used!"
        return
    }
    findRcloneVersion
    Write-Host "Copying rclone from rclone\v${global:RCLONE_VERSION}\rclone-arangodb-windows-amd64.exe to $global:ARANGODIR\build\rclone-arangodb.exe ..."    
    Copy-Item -Path "$global:WORKDIR\rclone\v${global:RCLONE_VERSION}\rclone-arangodb-windows-amd64.exe" -Destination "$global:ARANGODIR\build\rclone-arangodb.exe" -Force
}

################################################################################
# git working copy manipulation
################################################################################

Function checkoutArangoDB
{
    Push-Location $pwd
    Set-Location $INNERWORKDIR
    If (-Not(Test-Path -PathType Container -Path "ArangoDB"))
    {
        proc -process "git" -argument "clone https://$ENV:ARANGODB_GIT_HOST/$ENV:ARANGODB_GIT_ORGA/ArangoDB" -logfile $false -priority "Normal"
    }
    Pop-Location
}

Function checkoutEnterprise
{
    checkoutArangoDB
    If ($global:ok)
    {
        Push-Location $pwd
        Set-Location $global:ARANGODIR
        If (-Not(Test-Path -PathType Container -Path "enterprise"))
        {
            proc -process "git" -argument "clone ssh://git@$ENV:ENTERPRISE_GIT_HOST/$ENV:ENTERPRISE_GIT_ORGA/enterprise" -logfile $false -priority "Normal"
        }
        Pop-Location
    }
}

Function checkoutIfNeeded
{
    If ($ENTERPRISEEDITION -eq "On")
    {
        If (-Not(Test-Path -PathType Container -Path $global:ENTERPRISEDIR))
        {
            checkoutEnterprise
        }
    }
    Else
    {
        If (-Not(Test-Path -PathType Container -Path $global:ARANGODIR))
        {
            checkoutArangoDB
        }
    }
}

Function convertSItoJSON
{
    If (Test-Path -PathType Leaf -Path $INNERWORKDIR\sourceInfo.log)
    {
        $fields = @()
        ForEach ($line in Get-Content $INNERWORKDIR\sourceInfo.log)
        {
            $var = $line.split(":")[0]
            switch -Regex ($var)
            {
                'oskar|VERSION|Community|Starter|Enterprise|Syncer|Rclone'
                {
                    $val = $line.split(" ")[1]
                    If (-Not [string]::IsNullOrEmpty($val))
                    {
                        $fields += "  `"$var`":`"$val`""
                    }
                }
            }
        }

        If (-Not [string]::IsNullOrEmpty($fields))
        {
            Write-Host "Convert $INNERWORKDIR\sourceInfo.log to $INNERWORKDIR\sourceInfo.json"
            Write-Output "{`n"($fields -join ',' + [Environment]::NewLine)"`n}" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.json" -NoNewLine
        }
    }
}

Function initSourceInfo
{
    Push-Location $global:INNERWORKDIR
    
    $oskarCommit = $(git rev-parse --verify HEAD)
    If ($oskarCommit -eq $null -or $oskarCommit -eq "")
    {
        Write-Output "oskar: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log"
    }
    Else
    {
        Write-Output "oskar: $oskarCommit" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log"
    }
      
    Write-Output "VERSION: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log" -Append
    Write-Output "Community: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log" -Append
    Write-Output "Starter: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log" -Append
    Write-Output "Enterprise: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log" -Append
    Write-Output "Syncer: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log" -Append
    Write-Output "Rclone: N/A" | Out-File -Encoding "utf8" "$global:INNERWORKDIR\sourceInfo.log" -Append -NoNewLine
  
    Pop-Location
    convertSItoJSON
}

function setupSourceInfo($field,$value)
{
    (Get-Content $global:INNERWORKDIR\sourceInfo.log) -replace "${field}:.*", "${field}: $value" | Out-File -Encoding UTF8 "$global:INNERWORKDIR\sourceInfo.log"

    convertSItoJSON
}

Function switchBranches($branch_c,$branch_e)
{
    $branch_c = $branch_c.ToString()

    checkoutIfNeeded
    Push-Location $pwd
    Set-Location $global:ARANGODIR;comm
    proc -process "git" -argument "config --system core.longpaths true" -logfile $false -priority "Normal"
    If ($global:ok)
    {
        proc -process "git" -argument "clean -fdx" -logfile $false -priority "Normal"
    }
    If ($global:ok)
    {
        proc -process "git" -argument "checkout -f -- ." -logfile $false -priority "Normal"
    }
    If ($global:ok)
    {
        proc -process "git" -argument "fetch" -logfile $false -priority "Normal"
    }
    If ($global:ok)
    {
        proc -process "git" -argument "fetch --tags -f" -logfile $false -priority "Normal"
    }
    If ($global:ok)
    {
        proc -process "git" -argument "checkout -f $branch_c" -logfile $false -priority "Normal"
    }
    If ($branch_c.StartsWith("v"))
    {
        If ($global:ok)
        {
            proc -process "git" -argument "checkout -- ." -logfile $false -priority "Normal"
        }
    }
    Else
    {
        If ($global:ok) 
        {
            proc -process "git" -argument "reset --hard origin/$branch_c" -logfile $false -priority "Normal"
        }
    }
    If ($global:ok)
    {
        proc -process "git" -argument "submodule update --init --force" -logfile $false -priority "Normal"
    }
    If ($global:ok)
    {
        setupSourceInfo "VERSION" $(Get-Content $INNERWORKDIR/$ENV:ARANGODB_GIT_ORGA/ARANGO-VERSION)
        setupSourceInfo "Community" $(git rev-parse --verify HEAD)
        findArangoDBVersion
    }
    Else
    {
        Write-Output "Failed to checkout Community branch!"
        setupSourceInfo "VERSION" "N/A"
        setupSourceInfo "Community" "N/A"
    }
    If ($global:ok -And $ENTERPRISEEDITION -eq "On")
    {
        $branch_e = $branch_e.ToString()

        Push-Location $pwd
        Set-Location $global:ENTERPRISEDIR;comm
        If ($global:ok)
        {
            proc -process "git" -argument "clean -fdx" -logfile $false -priority "Normal"
        }
        If ($global:ok)
        {
            proc -process "git" -argument "checkout -f -- ." -logfile $false -priority "Normal"
        }
        If ($global:ok)
        {
            proc -process "git" -argument "fetch" -logfile $false -priority "Normal"
        }
        If ($global:ok)
        {
            proc -process "git" -argument "fetch --tags -f" -logfile $false -priority "Normal"
        }
        If ($global:ok)
        {
            proc -process "git" -argument "checkout -f $branch_e" -logfile $false -priority "Normal"
        }
        If ($branch_e.StartsWith("v"))
        {
            If ($global:ok)
            {
                proc -process "git" -argument "checkout -- ." -logfile $false -priority "Normal"
            }
        }
        Else
        {
            If ($global:ok)
            {
                proc -process "git" -argument "reset --hard origin/$branch_e" -logfile $false -priority "Normal"
            }
        }
        If ($global:ok)
        {
            setupSourceInfo "Enterprise" $(git rev-parse --verify HEAD)
        }
        Else
        {
            Write-Output "Failed to checkout Enterprise branch!"
            setupSourceInfo "Enterprise" "N/A"
        }
        
        Pop-Location
    }
    Pop-Location
    
    findCompilerVersion
}

Function updateOskar
{
    Push-Location $pwd
    Set-Location $WORKDIR
    If ($global:ok) 
    {
        proc -process "git" -argument "checkout -- ." -logfile $false -priority "Normal"
    }
    If ($global:ok) 
    {
        proc -process "git" -argument "reset --hard origin/${ENV:OSKAR_BRANCH}" -logfile $false -priority "Normal"
    }
    Pop-Location
}

Function clearResults
{
    ForEach ($report in $(Get-ChildItem -Path $INNERWORKDIR -Filter "testreport*"))
    {
        Remove-Item -Force $report.FullName
    }
    ForEach ($log in $(Get-ChildItem -Path $INNERWORKDIR -Filter "*.log" -Exclude "sourceInfo*"))
    {
        Remove-Item -Force $log.FullName
    }
    If (Test-Path -PathType Leaf -Path $INNERWORKDIR\test.log)
    {
        Remove-Item -Force $INNERWORKDIR\test.log
    }
    If (Test-Path -PathType Leaf -Path $ENV:TMP\testProtocol.txt)
    {
        Remove-Item -Force $ENV:TMP\testProtocol.txt
    }
    If (Test-Path -PathType Leaf -Path $INNERWORKDIR\testfailures.txt)
    {
        Remove-Item -Force $INNERWORKDIR\testfailures.txt
    }
    ForEach ($file in $(Get-ChildItem -Path $INNERWORKDIR -Filter "ArangoDB3*-*.exe"))
    {
        Remove-Item -Force $INNERWORKDIR\$file
    }
    ForEach ($file in $(Get-ChildItem -Path $INNERWORKDIR -Filter "ArangoDB3*-*.zip"))
    {
        Remove-Item -Force $INNERWORKDIR\$file
    }
    ForEach ($file in $(Get-ChildItem -Path $INNERWORKDIR -Filter "ArangoDB3*-*.7z"))
    {
        Remove-Item -Force $INNERWORKDIR\$file
    }
    comm
}

Function clearWorkdir
{
    $Excludes = [System.Collections.ArrayList]@(
        ("$global:ARANGODIR*" | split-path -leaf),
        ("$ENV:TMP*" | split-path -leaf),
        ("$ENV:CLCACHE_DIR*" | split-path -leaf),
        ("$ENV:CMAKE_CONFIGURE_DIR*" | split-path -leaf),
        ("${global:INNERWORKDIR}\sourceInfo*" | split-path -leaf)
    )
    If ((isGCE) -eq $False)
    {
        $Excludes += ("${global:INNERWORKDIR}\OpenSSL*" | split-path -leaf)
    }
    ForEach ($item in $(Get-ChildItem -Path $INNERWORKDIR -Exclude $Excludes))
    {
        Remove-Item $item -Force -Recurse -ErrorAction SilentlyContinue
    }
    comm
}

################################################################################
# ArangoDB git working copy manipulation
################################################################################

Function getRepoState
{
    Push-Location $pwd
    Set-Location $global:ARANGODIR; comm
    $global:repoState = "$(git rev-parse HEAD)`r`n"+$(git status -b -s | Select-String -Pattern "^[?]" -NotMatch)
    If ($ENTERPRISEEDITION -eq "On")
    {
        Push-Location $pwd
        Set-Location $global:ENTERPRISEDIR; comm
        $global:repoStateEnterprise = "$(git rev-parse HEAD)`r`n$(git status -b -s | Select-String -Pattern "^[?]" -NotMatch)"
        Pop-Location
    }
    Else
    {
        $global:repoStateEnterprise = ""
    }
    Pop-Location
}

Function noteStartAndRepoState
{
    getRepoState
    If (Test-Path -PathType Leaf -Path $ENV:TMP\testProtocol.txt)
    {
        Remove-Item -Force $ENV:TMP\testProtocol.txt
    }
    New-Item -Force $ENV:TMP\testProtocol.txt
    $(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH.mm.ssZ") | Add-Content $ENV:TMP\testProtocol.txt
    Write-Output "========== Status of main repository:" | Add-Content $ENV:TMP\testProtocol.txt
    Write-Host "========== Status of main repository:"
    ForEach ($line in $global:repoState)
    {
        Write-Output " $line" | Add-Content $ENV:TMP\testProtocol.txt
        Write-Host " $line"
    }
    If ($ENTERPRISEEDITION -eq "On")
    {
        Write-Output "Status of enterprise repository:" | Add-Content $ENV:TMP\testProtocol.txt
        Write-Host "Status of enterprise repository:"
        ForEach ($line in $global:repoStateEnterprise)
        {
            Write-Output " $line" | Add-Content $ENV:TMP\testProtocol.txt
            Write-Host " $line"
        }
    }
}


Function getCacheID
{
       
    If ($ENTERPRISEEDITION -eq "On")
    {
        Get-ChildItem -Include "CMakeLists.txt","VERSIONS","*.cmake" -Recurse  | ? { $_.Directory -NotMatch '.*build.*' } | Get-FileHash > $ENV:TMP\allHashes.txt
    }
    Else
    {
        # if there happenes to be an enterprise directory, we ignore it.
        Get-ChildItem -Include "CMakeLists.txt","VERSIONS","*.cmake" -Recurse | ? { $_.Directory -NotMatch '.*enterprise.*' } | ? { $_.Directory -NotMatch '.*build.*' } | Get-FileHash > $ENV:TMP\allHashes.txt
    }
    
    $hash = "$((Get-FileHash $ENV:TMP\allHashes.txt).Hash)" + ($ENV:OPENSSL_ROOT_DIR).GetHashCode() + (Split-Path $ENV:CLCACHE_CL).GetHashCode()
    $hashStr = "$ENV:CMAKE_CONFIGURE_DIR\${hash}-EP_${ENTERPRISEEDITION}.zip"
    Remove-Item -Force $ENV:TMP\allHashes.txt
    return $hashStr
}

################################################################################
# Compiling & package generation
################################################################################

Function generateJsSha1Sum ($jsdir = "")
{
    If ($jsdir -eq $null -or $jsdir -eq "")
    {
      $jsdir="$global:ARANGODIR\js"
    }

    If (Test-Path $jsdir)
    {
        Push-Location $jsdir
        Try
        {
            $files = @{}
            Remove-Item -Force .\* -Include JS_FILES.txt, JS_SHA1SUM.txt
            ForEach ($file in Get-ChildItem -Recurse -File -Name)
            {
              $files[$file] = ""
            }
            If ($ENTERPRISEEDITION -eq "On")
            {
                Push-Location "$jsdir\..\enterprise\js"
                ForEach ($file in Get-ChildItem -Recurse -File -Name)
                {
                  $files[$file] = "$jsdir\..\enterprise\js\"
                }
                Pop-Location
            }
            ForEach ($file in $files.GetEnumerator() | sort -Property Name)
            {
                $fileHash += (Get-FileHash -Algorithm SHA1 -Path ($file.Value + $file.Name)).Hash.toLower() + "  .\" + $file.Name.toString() | Out-File -Append -FilePath JS_FILES.txt
            }
            $hash = (Get-FileHash -Algorithm SHA1 -Path "JS_FILES.txt").Hash.toLower() + "  JS_FILES.txt"  > "JS_SHA1SUM.txt"
            Remove-Item -Force "$jsdir\JS_FILES.txt"
            Pop-Location
        }
        Catch
        {
          Pop-Location
          $global:ok = $false
        }
    }
}

Function configureWindows
{
    If (Test-Path -PathType Container -Path "$global:ARANGODIR\build")
    {
        Remove-Item -Path "$global:ARANGODIR\build\*" -Recurse
    }
    Else
    {
        New-Item -ItemType Directory -Path "$global:ARANGODIR\build"
    }

    findCompilerVersion
    If ($USE_OSKAR_OPENSSL -eq "On")
    {
      oskarOpenSSL
    }
    Else
    {
      If (Test-Path "env:OPENSSL_ROOT_DIR") { Remove-Item env:\OPENSSL_ROOT_DIR }
    }

    If ($global:ok)
    {
      configureCache
      #$cacheZipFN = getCacheID
      $haveCache = $False #$(Test-Path -Path $cacheZipFN)
      Push-Location $pwd
      Set-Location "$global:ARANGODIR\build"
      If ($haveCache)
      {
          Write-Host "Extracting cmake configure zip: ${cacheZipFN}"
          # Touch the file, so a cleanup job sees its used:
          $file = Get-Item $cacheZipFN
          $file.LastWriteTime = (get-Date)
          # extract it
          7unzip $cacheZipFN
      }
      $ARANGODIR_SLASH = $global:ARANGODIR -replace "\\","/"
      If ($ENTERPRISEEDITION -eq "On")
      {
          if ($global:PACKAGING -eq "On") {
            downloadStarter
            downloadSyncer
          }
          If (-Not $global:ok)
          {
              return
          }
          If ($global:ARANGODB_VERSION_MAJOR -eq 3 -And $global:ARANGODB_VERSION_MINOR -lt 12)
          {
              $THIRDPARTY_SBIN_LIST="$ARANGODIR_SLASH/build/arangosync.exe"
          }
          If ($global:USE_RCLONE -eq "true")
          {
              copyRclone
              $THIRDPARTY_SBIN_LIST="$THIRDPARTY_SBIN_LIST;$ARANGODIR_SLASH/build/rclone-arangodb.exe"
          }
          Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"   
          Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"$GENERATORID$MSVS_COMPILER,host=x64`" -DVERBOSE=On -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DBUILD_REPO_INFO=`"$BUILD_REPO_INFO`" -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DUSE_CCACHE=`"Off`" -DTHIRDPARTY_SBIN=`"$THIRDPARTY_SBIN_LIST`" -DARANGODB_BUILD_DATE=`"$ARANGODB_BUILD_DATE`" $global:CMAKEPARAMS `"$global:ARANGODIR`""
          proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"$GENERATORID$MSVS_COMPILER,host=x64`" -DVERBOSE=On -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DBUILD_REPO_INFO=`"$BUILD_REPO_INFO`" -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DUSE_CCACHE=`"Off`" -DTHIRDPARTY_SBIN=`"$THIRDPARTY_SBIN_LIST`" -DARANGODB_BUILD_DATE=`"$ARANGODB_BUILD_DATE`" $global:CMAKEPARAMS `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake" -priority "Normal"
      }
      Else
      {
          if ($global:PACKAGING -eq "On") {
            downloadStarter
          }
          Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
          Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"$GENERATORID$MSVS_COMPILER,host=x64`" -DVERBOSE=On -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DBUILD_REPO_INFO=`"$BUILD_REPO_INFO`" -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DUSE_CCACHE=`"Off`" -DARANGODB_BUILD_DATE=`"$ARANGODB_BUILD_DATE`" $global:CMAKEPARAMS `"$global:ARANGODIR`""
          proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"$GENERATORID$MSVS_COMPILER,host=x64`" -DVERBOSE=On -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DBUILD_REPO_INFO=`"$BUILD_REPO_INFO`" -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DUSE_CCACHE=`"Off`" -DARANGODB_BUILD_DATE=`"$ARANGODB_BUILD_DATE`" $global:CMAKEPARAMS `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake" -priority "Normal"
      }
      #If (!$haveCache)
      #{
      #    Write-Host "Archiving cmake configure zip: ${cacheZipFN}"
      #    7zip -Path $global:ARANGODIR\build\* -DestinationPath $cacheZipFN "-xr!*.exe"; comm
      #}
      Write-Host "Clcache Statistics"
      showCacheStats
      Pop-Location
    }
}

Function buildWindows 
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    Write-Host "Build: cmake --build . --config `"$BUILDMODE`" --parallel -- /p:CL_MPcount=$numberSlots $global:BUILDPARAMS"
    #Remove-Item -Force "${global:INNERWORKDIR}\*.pdb.${global:PDBS_ARCHIVE_TYPE}" -ErrorAction SilentlyContinue
    $ENV:UseMultiToolTask = "true"
    $ENV:EnforceProcessCountAcrossBuilds = "true"
    $ENV:EnableClServerMode= "true"
    proc -process "cmake" -argument "--build . --config `"$BUILDMODE`" --parallel -- /p:CL_MPcount=$numberSlots" -logfile "$INNERWORKDIR\build $global:BUILDPARAMS" -priority "Normal"
    If ($global:ok)
    {
        Copy-Item "$global:ARANGODIR\build\bin\$BUILDMODE\*" -Destination "$global:ARANGODIR\build\bin\"; comm
        If (Test-Path -PathType Container -Path "$global:ARANGODIR\build\tests\$BUILDMODE")
        {
          Copy-Item "$global:ARANGODIR\build\tests\$BUILDMODE\*" -Destination "$global:ARANGODIR\build\tests\"; comm
        }
        generateJsSha1Sum
    }
    Write-Host "Clcache Statistics"
    showCacheStats
    Pop-Location
}

Function packageWindows
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    ForEach ($TARGET in @("package-arangodb-server-nsis","package-arangodb-server-zip","package-arangodb-client-nsis"))
    {
        Write-Host "Build: cmake --build . --config `"$BUILDMODE`" --target `"$TARGET`""
        proc -process "cmake" -argument "--build . --config `"$BUILDMODE`" --target `"$TARGET`"" -logfile "$INNERWORKDIR\$TARGET-package" -priority "Normal"
        If (-not $global:ok)
        {
            Write-Host "Build: cmake --build . --config `"$BUILDMODE`" --target `"$TARGET`" failed!"
            break
        }
    }
    Write-Host "Clcache Statistics"
    showCacheStats
    Pop-Location
}

Function signWindows
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build\"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    ForEach ($PACKAGE in $(Get-ChildItem -Filter ArangoDB3*.exe).FullName)
    {
        Write-Host "Sign: signtool.exe sign /sm /fd sha1 /td sha1 /sha1 D4F9266E06107CF3C29AA7E5635AD5F76018F6A3 /tr `"http://timestamp.digicert.com`" `"$PACKAGE`""
        proc -process signtool.exe -argument "sign /sm /fd sha1 /td sha1 /sha1 D4F9266E06107CF3C29AA7E5635AD5F76018F6A3 /tr `"http://timestamp.digicert.com`" `"$PACKAGE`"" -logfile "$INNERWORKDIR\$($PACKAGE.Split('\')[-1])-sign.log" -priority "Normal"
    }
    Pop-Location
}

Function storeSymbols
{
    If (-Not((Get-Content $INNERWORKDIR\ArangoDB\CMakeLists.txt) -match 'set\(ARANGODB_VERSION_RELEASE_TYPE \"nightly\"'))
    {
        Push-Location $pwd
        Set-Location "$global:ARANGODIR\build\"
        If (-not((Get-SmbMapping -LocalPath S: -ErrorAction SilentlyContinue).Status -eq "OK"))
        {
            New-SmbMapping -LocalPath 'S:' -RemotePath '\\symbol.arangodb.biz\symbol' -Persistent $true
        }
        findArangoDBVersion | Out-Null
        ForEach ($SYMBOL in $((Get-ChildItem "$global:ARANGODIR\build\bin\$BUILDMODE" -Recurse -Filter "*.pdb").FullName))
        {
            Write-Host "Symbol: symstore.exe add /f `"$SYMBOL`" /s `"S:\symsrv_arangodb$global:ARANGODB_VERSION_MAJOR$global:ARANGODB_VERSION_MINOR`" /t ArangoDB /compress"
            proc -process "symstore.exe" -argument "add /f `"$SYMBOL`" /s `"S:\symsrv_arangodb$global:ARANGODB_VERSION_MAJOR$global:ARANGODB_VERSION_MINOR`" /t ArangoDB /compress" -logfile "$INNERWORKDIR\symstore" -priority "Normal"
        }
        #uploadSymbols functionality moved to jenkins/releaseUploadFiles3.fish due to problems with gsutil on Windows
        #uploadSymbols
        Pop-Location
    }
}

Function setNightlyVersion
{
    checkoutIfNeeded
    (Get-Content $ARANGODIR\CMakeLists.txt) -replace 'set\(ARANGODB_VERSION_RELEASE_TYPE .*', 'set(ARANGODB_VERSION_RELEASE_TYPE "nightly")' | Out-File -Encoding UTF8 $ARANGODIR\CMakeLists.txt
    (Get-Content $ARANGODIR\CMakeLists.txt) -replace 'set\(ARANGODB_VERSION_RELEASE_NUMBER.*', ('set(ARANGODB_VERSION_RELEASE_NUMBER "' + (Get-Date).ToString("yyyyMMdd") + '")') | Out-File -Encoding UTF8 $ARANGODIR\CMakeLists.txt
    findArangoDBVersion
    setupSourceInfo "VERSION" $global:ARANGODB_FULL_VERSION
    nightlyBuildRepoInfo
}

Function movePackagesToWorkdir
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build\"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    ForEach ($PACKAGE in $(Get-ChildItem $pwd\* -Filter ArangoDB3* -Include *.exe, *.zip).FullName)
    {
        Write-Host "Move $PACKAGE to $global:INNERWORKDIR"
        Move-Item "$PACKAGE" -Force -Destination "$global:INNERWORKDIR"; comm
    }
    Pop-Location
}

Function preserveSymbolsToWorkdir
{
    Push-Location $pwd
    Set-Location $global:ARANGODIR
    If (findArangoDBVersion)
    {
        Set-Location "$global:ARANGODIR\build\bin\$BUILDMODE"
        $suffix = If ($ENTERPRISEEDITION -eq "On") {"e"} Else {""}
        $ARANGODB_PDB_PACKAGE = "ArangoDB3${suffix}-${global:ARANGODB_FULL_VERSION}.pdb.${global:PDBS_ARCHIVE_TYPE}"
        If ("$global:ARANGODB_VERSION_RELEASE_TYPE" -eq "nightly")
        {
            $ARANGODB_PDB_PACKAGE = $ARANGODB_PDB_PACKAGE -replace "nightly.*pdb.${global:PDBS_ARCHIVE_TYPE}", "nightly.pdb.${global:PDBS_ARCHIVE_TYPE}"
        }
        Write-Host "Preserve symbols (PDBs) to ${global:INNERWORKDIR}\$ARANGODB_PDB_PACKAGE"
        If (Test-Path -Path "$global:ARANGODIR\build\bin\$BUILDMODE\arango*.pdb")
        {
            Write-Host "Remove existing ${global:INNERWORKDIR}\$ARANGODB_PDB_PACKAGE"
            Remove-Item -Force "${global:INNERWORKDIR}\$ARANGODB_PDB_PACKAGE" -ErrorAction SilentlyContinue
            Write-Host "Save arango*.pdb to ${global:INNERWORKDIR}\$ARANGODB_PDB_PACKAGE"
            7zip -Path arango*.pdb -DestinationPath "${global:INNERWORKDIR}\$ARANGODB_PDB_PACKAGE"; comm
        }
        Else
        {
            Write-Host "No symbol (PDB) files found at ${global:ARANGODIR}\build\bin\${BUILDMODE}"
        }
    }
    Pop-Location
}

Function buildArangoDB
{
    checkoutIfNeeded
    If ($global:KEEPBUILD -eq "Off")
    {
       If (Test-Path -PathType Container -Path "$global:ARANGODIR\build")
       {
          Remove-Item -Recurse -Force -Path "$global:ARANGODIR\build"
          Write-Host "Delete Builddir OK."
       }
    }
    configureWindows
    If ($global:ok)
    {
        Push-Location $ENV:WORKSPACE
        Get-VSSetupInstance | Out-File -FilePath .\vssetup.reg.log
        Get-ChildItem Env: | Out-File -FilePath .\env.reg.log
        Pop-Location

        Write-Host "Configure OK."
        buildWindows
        If ($global:ok)
        {
            Write-Host "Build OK."
            If ($SKIPPACKAGING -eq "Off")
            {
                preserveSymbolsToWorkdir
                packageWindows
                If ($global:ok)
                {
                    Write-Host "Package OK."
                    If ($SIGN)
                    {
                        signWindows
                        If ($global:ok)
                        {
                            Write-Host "Sign OK."
                        }
                        Else
                        {
                            Write-Host "Sign error, see $INNERWORKDIR\*-sign.* for details."
                            movePackagesToWorkdir
                            $global:ok = $false
                        }
                    }
                    movePackagesToWorkdir
                }
                Else
                {
                    Write-Host "Package error, see $INNERWORKDIR\package.* for details."
                }                
            }
        }
        Else
        {
            Write-Host "Build error, see $INNERWORKDIR\build.* for details."
        }
    }
    Else
    {
        Write-Host "cmake error, see $INNERWORKDIR\cmake.* for details."
        if (isGCE) {
            Push-Location $ENV:WORKSPACE
            Invoke-Command  {reg export HKLM hklm.reg.log}
            Invoke-Command  {reg export HKCU hkcu.reg.log}
            Invoke-Command  {reg export HKCR hkcr.reg.log}
            Get-VSSetupInstance | Out-File -FilePath .\vssetup.reg.log
            Get-ChildItem Env: | Out-File -FilePath .\env.reg.log
            ForEach ($file in $(Get-ChildItem . -Filter "*.reg.log"))
            {
                Write-Host "Regfile $file"
            }
            Pop-Location
        }
    }
}

Function buildStaticArangoDB
{
    staticExecutablesOn
    buildArangoDB
}

Function moveResultsToWorkspace
{
    findArangoDBVersion
    Write-Host "Moving reports and logs to $ENV:WORKSPACE ..."
    Write-Host "test.log ..."
    If (Test-Path -PathType Leaf "$INNERWORKDIR\test.log")
    {
        If ($global:result -eq "BAD" -Or $global:WORKSPACE_LOGS -eq "all")
        {
            ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter testreport*))
            {
                Write-Host "Move $INNERWORKDIR\$file"
                Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
            } 
        }
        Else
        {
            ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "testreport*"))
            {
                Write-Host "Remove $INNERWORKDIR\$file"
                Remove-Item -Force "$INNERWORKDIR\$file"; comm 
            } 
        }
    }
    If (Test-Path -PathType Leaf "$INNERWORKDIR\test.log")
    {
        Write-Host "Move $INNERWORKDIR\test.log"
        Move-Item -Force -Path "$INNERWORKDIR\test.log" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "*.zip ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "*.zip" | ? { $_.Name -notlike "ArangoDB3*.zip"}))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "*.7z ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "*.7z" | ? { $_.Name -notlike "ArangoDB3*.zip"}))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "*.tar ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "*.tar" | ? { $_.Name -notlike "ArangoDB3*.tar"}))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "build* ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "build*"))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "cmake* ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "cmake*" -File))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "sourceInfo* ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "sourceInfo*" -File))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "package* ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "package*"))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "*-sign* ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "*-sign*"))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    If (Test-Path -Path $INNERWORKDIR\ArangoDB\build\CMakeFiles)
    {
        Write-Host "CMakeOutput ..."
        ForEach ($file in $(Get-ChildItem $INNERWORKDIR\ArangoDB\build\CMakeFiles -Filter "*.log"))
        {
            Write-Host "Move $INNERWORKDIR\ArangoDB\build\CMakeFiles\$file"
            Move-Item -Force -Path "$INNERWORKDIR\ArangoDB\build\CMakeFiles\$file" -Destination $ENV:WORKSPACE; comm
        }
    }

    If ($PDBS_TO_WORKSPACE -eq "always" -or ($PDBS_TO_WORKSPACE -eq "crash" -and $global:hasTestCrashes))
    {
        Write-Host "ArangoDB3*-${global:ARANGODB_FULL_VERSION}.pdb.${global:PDBS_ARCHIVE_TYPE} ..."
        ForEach ($file in $(Get-ChildItem "$INNERWORKDIR" -Filter "ArangoDB3*-${global:ARANGODB_FULL_VERSION}.pdb.${global:PDBS_ARCHIVE_TYPE}"))
        {
            Write-Host "Move $INNERWORKDIR\$file"
            Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm 
        }
    }

    If ($SKIPPACKAGING -eq "Off")
    {
        Write-Host "ArangoDB3*.exe ..."
        ForEach ($file in $(Get-ChildItem "$INNERWORKDIR" -Filter "ArangoDB3*.exe"))
        {
            Write-Host "Move $INNERWORKDIR\$file"
            Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm 
        }
        Write-Host "ArangoDB3*.zip ..."
        ForEach ($file in $(Get-ChildItem "$global:INNERWORKDIR\" -Filter "ArangoDB3*.zip"))
        {
            Write-Host "Move $INNERWORKDIR\$file"
            Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm 
        }
    }
    Write-Host "testfailures.txt"
    If (Test-Path -PathType Leaf "$INNERWORKDIR\testfailures.txt")
    {
        Write-Host "Move $INNERWORKDIR\testfailures.txt"
        Move-Item -Force -Path "$INNERWORKDIR\testfailures.txt" -Destination $ENV:WORKSPACE; comm 
    }
    Write-Host "testrunXml"
    If (Test-Path "$INNERWORKDIR\ArangoDB\testrunXml")
    {
        Write-Host "Move $INNERWORKDIR\ArangoDB\testrunXml"
        Move-Item -Force -Path "$INNERWORKDIR\ArangoDB\testrunXml" -Destination $ENV:WORKSPACE; comm 
    }
}

################################################################################
# Oskar entry points
################################################################################

Function configureDumpsArangoDB
{
    Write-Host "Configure crashdumps for arango* processes to reside in ${global:COREDIR}..."
    clearWER
    ForEach ($executable in (Get-ChildItem -File -Filter "arango*.exe" -Path "$global:ARANGODIR\build\bin\$BUILDMODE"))
    {
        configureWER -executable $executable -path $global:COREDIR
    }
    comm
}

Function oskarCheck
{
    If ($PDBS_TO_WORKSPACE -eq "always" -or ($PDBS_TO_WORKSPACE -eq "crash" -and $global:hasTestCrashes))
    {
        preserveSymbolsToWorkdir
    }

    $global:ok = ($global:ok -and $global:result -eq "GOOD")
}

Function oskar
{
    checkoutIfNeeded
    If ($global:ok)
    {
        configureDumpsArangoDB
        . "$global:SCRIPTSDIR\runTests.ps1"
    }
    oskarCheck
}

Function oskarFull
{
    checkoutIfNeeded
    If ($global:ok)
    {
        configureDumpsArangoDB
        . "$global:SCRIPTSDIR\runFullTests.ps1"
    }
    oskarCheck
}

Function oskar1
{
    showConfig
    buildStaticArangoDB
    If ($global:ok)
    {
        oskar
    }
}

Function oskar1Full
{
    showConfig
    buildStaticArangoDB
    If ($global:ok)
    {
        oskarFull
    }
}

Function oskar2
{
    showConfig
    buildStaticArangoDB
    cluster
    oskar
    single
    oskar
    cluster
    comm
}

Function oskar4
{
    showConfig
    buildStaticArangoDB
    rocksdb
    cluster
    oskar
    single
    oskar
    mmfiles
    cluster
    oskar
    single
    oskar
    cluster
    rocksdb
    comm
}

Function oskar8
{
    showConfig
    enterprise
    buildStaticArangoDB
    rocksdb
    cluster
    oskar
    single
    oskar
    mmfiles
    cluster
    oskar
    single
    oskar
    community
    buildArangoDB
    rocksdb
    cluster
    oskar
    single
    oskar
    mmfiles
    cluster
    oskar
    single
    oskar
    cluster
    rocksdb
    comm
}

Function rlogCompile
{
    showConfig
    $global:CMAKEPARAMS = "-DDEBUG_SYNC_REPLICATION=On -DUSE_FAILURE_TESTS=On -DUSE_SEPARATE_REPLICATION2_TESTS_BINARY=On"
    buildStaticArangoDB
}

Function rlogTests
{
    checkoutIfNeeded
    If ($global:ok)
    {
        configureDumpsArangoDB
        . "$global:SCRIPTSDIR\rlog\pr.ps1"
    }
    oskarCheck
}

Function makeCommunityRelease
{
    setPDBsArchiveZip
    maintainerOff
    staticExecutablesOn
    skipPackagingOff
    signPackageOn
    community
    buildArangoDB
}

Function makeEnterpriseRelease
{
    setPDBsArchiveZip
    maintainerOff
    staticExecutablesOn
    skipPackagingOff
    signPackageOn
    enterprise
    buildArangoDB
}

Function makeRelease
{
    makeEnterpriseRelease
    If ($global:ok) 
    {
        makeCommunityRelease
    }
}

parallelism ([int]$ENV:NUMBER_OF_PROCESSORS)
initSourceInfo

$global:SYSTEM_IS_WINDOWS=$true
