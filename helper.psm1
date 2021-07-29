$global:WORKDIR = $pwd
$global:SCRIPTSDIR = Join-Path -Path $global:WORKDIR -ChildPath scripts

If(-Not($ENV:WORKSPACE))
{
    $ENV:WORKSPACE = Join-Path -Path $global:WORKDIR -ChildPath work
}

If(-Not($ENV:OSKAR_BRANCH))
{
    $ENV:OSKAR_BRANCH = "master"
}

If(-Not(Test-Path -PathType Container -Path "work"))
{
    New-Item -ItemType Directory -Path "work"
}

$global:TSHARK = ((Get-ChildItem -ErrorAction SilentlyContinue -Recurse "${env:ProgramFiles}" tshark.exe).FullName | Select-Object -Last 1) -replace ' ', '` '

If(-Not($global:TSHARK))
{
    Write-Host "failed to locate TSHARK"
}
Else
{
    If((Invoke-Expression "$global:TSHARK -D" | Select-String -SimpleMatch Npcap ) -match '^(\d).*')
    {
        $global:dumpDevice = $Matches[1]
        if ($global:dumpDevice -notmatch '\d+') {
            Write-Host "unable to detect the loopback-device. we expect this to have an Npcacp one:"
            Invoke-Expression $global:TSHARK -D
            Exit 1
        }
        Else {
            $global:TSHARK = $global:TSHARK -replace '` ', ' '
        }
    }
    Else
    {
        Write-Host "failed to get loopbackdevice - check NCAP Driver installation"
        $global:TSHARK = ""
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
$global:COREDIR = "$env:WORKSPACE\core"
if (-Not(Test-Path -Path $global:COREDIR))
{
  New-Item -ItemType "directory" -Path "$global:COREDIR"
}
else
{
  Remove-Item "$global:COREDIR\*" -Recurse -Force
}
$global:RUBY = (Get-Command ruby.exe).Path
$global:INNERWORKDIR = "$WORKDIR\work"
$global:ARANGODIR = "$INNERWORKDIR\ArangoDB"
$global:ENTERPRISEDIR = "$global:ARANGODIR\enterprise"
$global:UPGRADEDATADIR = "$global:ARANGODIR\upgrade-data-tests"
$env:TMP = "$INNERWORKDIR\tmp"
$env:CLCACHE_DIR = "$INNERWORKDIR\.clcache.windows"
$env:CMAKE_CONFIGURE_DIR = "$INNERWORKDIR\.cmake.windows"
$env:CLCACHE_LOG = 0
$env:CLCACHE_HARDLINK = 1
$env:CLCACHE_OBJECT_CACHE_TIMEOUT_MS = 120000

$global:launcheableTests = @()
$global:maxTestCount = 0
$global:testCount = 0
$global:portBase = 10000
$global:result = "GOOD"
$global:hasTestCrashes = "false"

$global:ok = $true

if (-Not(Test-Path -Path $env:TMP))
{
  New-Item -ItemType "directory" -Path "$env:TMP"
}
if (-Not(Test-Path -Path $env:CMAKE_CONFIGURE_DIR))
{
  New-Item  -ItemType "directory" -Path "$env:CMAKE_CONFIGURE_DIR"
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
    If($logfile -eq $false)
    {
        $p = Start-Process $process -ArgumentList $argument -NoNewWindow -PassThru
        $p.PriorityClass = $priority
        $h = $p.Handle
        $p.WaitForExit()
        If($p.ExitCode -ne 0)
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
        If($p.ExitCode -ne 0)
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
    Write-Host "7za.exe" -argument "a -mx9 $DestinationPath $Path $moreArgs" -logfile $false -priority "Normal" 
    proc -process "7za.exe" -argument "a -mx9 $DestinationPath $Path $moreArgs" -logfile $false -priority "Normal" 
}

Function 7unzip($zip)
{
    Write-Host "7za.exe" -argument "x $zip -aoa" -logfile $false -priority "Normal" 
    proc -process "7za.exe" -argument "x $zip -aoa" -logfile $false -priority "Normal" 
}

Function hostKey
{
    If(Test-Path -PathType Leaf -Path "$HOME\.ssh\known_hosts")
    {
        Remove-Item -Force "$HOME\.ssh\known_hosts"
    }
    proc -process "ssh" -argument "-o StrictHostKeyChecking=no git@github.com" -logfile $false -priority "Normal"
    proc -process "ssh" -argument "-o StrictHostKeyChecking=no root@symbol.arangodb.biz exit" -logfile $false -priority "Normal"
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
    $global:OPENSSL_PATH = "${global:INNERWORKDIR}\OpenSSL\${OPENSSL_VERSION}"
    Write-Host "Use OpenSSL within oskar: build ${OPENSSL_VERSION} if not present in ${OPENSSL_PATH}"
    $global:ok = (checkOpenSSL $global:INNERWORKDIR $OPENSSL_VERSION $MSVS ${OPENSSL_MODES} ${OPENSSL_TYPES} $true)
    If ($global:ok)
    {
      Write-Host "Set OPENSSL_ROOT_DIR via environment variable to $OPENSSL_PATH"
      $env:OPENSSL_ROOT_DIR = $OPENSSL_PATH
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

If(-Not($USE_OSKAR_OPENSSL))
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
        If(Test-Path -PathType Leaf -Path "${OPENSSL_CHECK_PATH}\bin\openssl.exe")
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
      Write-Host "Build OpenSSL ${version} all configurations"
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
          ForEach($mode In $modes)
          {
            ForEach($type In $types)
            {
              $OPENSSL_BUILD="${type}-${mode}"
              $env:installdir = "${path}\OpenSSL\${version}\VS_${msvs}\${OPENSSL_BUILD}"
              If(Test-Path -PathType Leaf -Path "$env:installdir")
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
              $buildCommand = "call `"C:\Program Files (x86)\Microsoft Visual Studio\$msvs\Community\Common7\Tools\vsdevcmd`" -arch=amd64 && perl Configure $CONFIG_TYPE --$mode --prefix=`"${env:installdir}`" --openssldir=`"${env:installdir}\ssl`" VC-WIN64A && nmake clean && nmake && nmake install"
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
    If(-Not(Test-Path -PathType Leaf LOCK.$pid))
    {
        $pid | Add-Content LOCK.$pid
        While($true)
        {
            If($pidfound = Get-Content LOCK -ErrorAction SilentlyContinue)
            {
                If(-Not(Get-Process -Id $pidfound -ErrorAction SilentlyContinue))
                {
                    Remove-Item LOCK
                    Remove-Item LOCk.$pidfound
                    Write-Host "Removed stale lock"
                }
            }
            If(New-Item -ItemType HardLink -Name LOCK -Value LOCK.$pid -ErrorAction SilentlyContinue)
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
    If(Test-Path -PathType Leaf LOCK.$pid)
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
    If($CLCACHE -eq "On")
    {
        If($env:CLCACHE_CL)
        {
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-c" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
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
    If($CLCACHE -eq "On")
    {
        If($env:CLCACHE_CL)
        {
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-C" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-z" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
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
    If($CLCACHE -eq "On")
    {
        If($env:CLCACHE_CL)
        {
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-M 107374182400" -logfile $false -priority "Normal"
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
            
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
    If($CLCACHE -eq "On")
    {
        If($env:CLCACHE_CL)
        {
            $tmp_stats = $global:ok
            proc -process "$(Split-Path $env:CLCACHE_CL)\cl.exe" -argument "-s" -logfile $false -priority "Normal"
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
    Write-Host "User           : "$env:USERDOMAIN\$env:USERNAME
    Write-Host "Use cache      : "$CLCACHE
    Write-Host "Cache          : "$env:CLCACHE_CL
    Write-Host "Cachedir       : "$env:CLCACHE_DIR
    Write-Host "CMakeConfigureCache      : "$env:CMAKE_CONFIGURE_DIR
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
    Write-Host "DMP workspace  : "$ENABLE_REPORT_DUMPS
    Write-Host "Use rclone     : "$USE_RCLONE
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
    Write-Host "Workspace      : "$env:WORKSPACE
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "Cache Statistics"
    showCacheStats
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
    $global:TESTSUITE_TIMEOUT = 1800
}
If(-Not($TESTSUITE))
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
If(-Not($SKIPPACKAGING))
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
If(-Not($STATICEXECUTABLES))
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
If(-Not($SIGN))
{
    signPackageOn
}

Function VS2017
{
    $env:CLCACHE_CL = $($(Get-ChildItem $(Get-VSSetupInstance -All| Where {$_.DisplayName -match "Visual Studio Community 2017"}).InstallationPath -Filter cl_original.exe -Recurse | Select-Object Fullname |Where {$_.FullName -match "Hostx64\\x64"}).FullName | Select-Object -Last 1)
    $global:GENERATOR = "Visual Studio 15 2017 Win64"
    $global:GENERATORID = "v141"
    $global:MSVS = "2017"
}
Function VS2019
{
    $env:CLCACHE_CL = $($(Get-ChildItem $(Get-VSSetupInstance -All| Where {$_.DisplayName -match "Visual Studio Community 2019"}).InstallationPath -Filter cl_original.exe -Recurse | Select-Object Fullname |Where {$_.FullName -match "Hostx64\\x64"}).FullName | Select-Object -Last 1)
    $global:GENERATOR = "Visual Studio 16 2019"
    $global:GENERATORID = "v142"
    $global:MSVS = "2019"
}
If(-Not($global:GENERATOR))
{
    VS2017
}

Function findCompilerVersion
{
    If (Test-Path -Path "$global:ARANGODIR\VERSIONS")
    {
        $MSVC_WINDOWS = Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "MSVC_WINDOWS" | Select Line
        If ($MSVC_WINDOWS)
        {
            $MSVC_WINDOWS -match "`"(?<version>[0-9]*)`"" | Out-Null

                switch ($Matches['version'])
                {
                    2017 { VS2017 }
                    2019 { VS2019 }
                    default { VS2017 }
                }
            return
        }
    }

    VS2017
}

Function maintainerOn
{
    $global:MAINTAINER = "On"
}
Function maintainerOff
{
    $global:MAINTAINER = "Off"
}
If(-Not($MAINTAINER))
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
    $env:CLCACHE_DISABLE = "1"
}
If(-Not($CLCACHE))
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
if(-Not($SKIPNONDETERMINISTIC))
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
if(-Not($SKIPTIMECRITICAL))
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
if(-Not($SKIPGREY))
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
if(-Not($ONLYGREY))
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
If(-Not($BUILDMODE))
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

If(-Not($ENTERPRISEEDITION))
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

If(-Not($STORAGEENGINE))
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

If(-Not($VERBOSEOSKAR))
{
    verbose
}

Function parallelism($threads)
{
    $global:numberSlots = $threads
}

If(-Not($global:numberSlots))
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

If(-Not($KEEPBUILD))
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

If(-Not($WORKSPACE_LOGS))
{
    $global:WORKSPACE_LOGS = "fail"
}

Function setPDBsToWorkspaceOnCrashOnly
{
    $global:PDBS_TO_WORKSPACE = "crash"
}

Function setPDBsToWorkspaceAlways
{
    $global:PDBS_TO_WORKSPACE = "always"
}

If(-Not($WORKSPACE_PDB_CRASH_ONLY))
{
    $global:PDBS_TO_WORKSPACE = "always"
}

Function disableDumpsToReport
{
    $global:ENABLE_REPORT_DUMPS = "off"
}

Function enableDumpsToReport
{
    $global:ENABLE_REPORT_DUMPS = "on"
}

If(-Not($ENABLE_REPORT_DUMPS))
{
    enableDumpsToReport
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

If(-Not($USE_RCLONE))
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
            If ($OPENSSL_WINDOWS -match '[0-9]{1}\.[0-9]{1}\.[0-9]{1}[a-z]{1}' -And $Matches.count -eq 1)
            {
                $global:OPENSSL_VERSION = $Matches[0]
                return
            }
        }
    }
    Write-Host "No VERSIONS file with proper OPENSSL_WINDOWS record found! Using default version: ${OPENSSL_DEFAULT_VERSION}"
    $global:OPENSSL_VERSION = $global:OPENSSL_DEFAULT_VERSION
}

# ##############################################################################
# Version detection
# ##############################################################################

Function findArangoDBVersion
{
    If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_MAJOR")[0] -match '.*"([0-9a-zA-Z]*)".*')
    {
        $global:ARANGODB_VERSION_MAJOR = $Matches[1]
        If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_MINOR")[0] -match '.*"([0-9a-zA-Z]*)".*')
        {
            $global:ARANGODB_VERSION_MINOR = $Matches[1]
            
            $34AndAbove = Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_PATCH"
            $33AndBelow = Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_REVISION"
            
            If(($34AndAbove, "")[!$34AndAbove].toString() + ($33AndBelow, "")[!$33AndBelow].toString() -match '.*"([0-9a-zA-Z]*)".*')
            {
                $global:ARANGODB_VERSION_PATCH = $Matches[1]
                If($34AndAbove -and $(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_RELEASE_TYPE")[0] -match '.*"([0-9a-zA-Z]*)".*')
                {
                    $global:ARANGODB_VERSION_RELEASE_TYPE = $Matches[1]
                    If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_RELEASE_NUMBER")[0] -match '.*"([0-9a-zA-Z]*)".*')
                    {
                        $global:ARANGODB_VERSION_RELEASE_NUMBER = $Matches[1]  
                    }
                }

            }
        }

    }
    $global:ARANGODB_VERSION = "$global:ARANGODB_VERSION_MAJOR.$global:ARANGODB_VERSION_MINOR.$global:ARANGODB_VERSION_PATCH"
    $global:ARANGODB_REPO = "arangodb$global:ARANGODB_VERSION_MAJOR$global:ARANGODB_VERSION_MINOR"
    If($global:ARANGODB_VERSION_RELEASE_TYPE)
    {
        If($global:ARANGODB_VERSION_RELEASE_NUMBER)
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
    proc -process "ssh" -argument "root@symbol.arangodb.biz gsutil rsync -r /mnt/symsrv_$global:ARANGODB_REPO gs://download.arangodb.com/symsrv_$global:ARANGODB_REPO" -logfile $true -priority "Normal"; comm
}

################################################################################
# include External resources starter, syncer
################################################################################

Function downloadStarter
{
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "STARTER_REV")[0] -match '([0-9]+.[0-9]+.[0-9]+[\-]?[0-9a-z]*[\-]?[0-9]?)|latest' | Out-Null
    $STARTER_REV = $Matches[0]
    If($STARTER_REV -eq "latest")
    {
        $JSON = Invoke-WebRequest -Uri 'https://api.github.com/repos/arangodb-helper/arangodb/releases/latest' -UseBasicParsing | ConvertFrom-Json
        $STARTER_REV = $JSON.name
    }
    Write-Host "Download: Starter"
    (New-Object System.Net.WebClient).DownloadFile("https://github.com/arangodb-helper/arangodb/releases/download/$STARTER_REV/arangodb-windows-amd64.exe","$global:ARANGODIR\build\arangodb.exe")
}

Function downloadSyncer
{
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    If(-Not($env:DOWNLOAD_SYNC_USER))
    {
        Write-Host "Need  environment variable set!"
    }
    (Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "SYNCER_REV")[0] -match '([0-9]+.[0-9]+.[0-9]+)|latest' | Out-Null
    $SYNCER_REV = $Matches[0]
    If($SYNCER_REV -eq "latest")
    {
        $JSON = curl -s -L "https://$env:DOWNLOAD_SYNC_USER@api.github.com/repos/arangodb/arangosync/releases/latest" | ConvertFrom-Json
        $SYNCER_REV = $JSON.name
    }
    $ASSET = curl -s -L "https://$env:DOWNLOAD_SYNC_USER@api.github.com/repos/arangodb/arangosync/releases/tags/$SYNCER_REV" | ConvertFrom-Json
    $ASSET_ID = $(($ASSET.assets) | Where-Object -Property name -eq arangosync-windows-amd64.exe).id
    Write-Host "Download: Syncer"
    curl -s -L -H "Accept: application/octet-stream" "https://$env:DOWNLOAD_SYNC_USER@api.github.com/repos/arangodb/arangosync/releases/assets/$ASSET_ID" -o "$global:ARANGODIR\build\arangosync.exe"
}

Function copyRclone
{
    findUseRclone
    If ($global:USE_RCLONE -eq "false")
    {
        Write-Host "Not copying rclone since it's not used!"
        return
    }
    Write-Host "Copying rclone from rclone\rclone-arangodb-windows.exe to $global:ARANGODIR\build\rclone-arangodb.exe ..."
    Copy-Item ("$global:WORKDIR\rclone\" + $(Get-Content "$global:WORKDIR\rclone\rclone-arangodb-windows.exe")) -Destination "$global:ARANGODIR\build\rclone-arangodb.exe"
}

################################################################################
# git working copy manipulation
################################################################################

Function checkoutArangoDB
{
    Push-Location $pwd
    Set-Location $INNERWORKDIR
    If(-Not(Test-Path -PathType Container -Path "ArangoDB"))
    {
        proc -process "git" -argument "clone https://github.com/arangodb/ArangoDB" -logfile $false -priority "Normal"
    }
    Pop-Location
}

Function checkoutEnterprise
{
    checkoutArangoDB
    if($global:ok)
    {
        Push-Location $pwd
        Set-Location $global:ARANGODIR
        If(-Not(Test-Path -PathType Container -Path "enterprise"))
        {
            proc -process "git" -argument "clone ssh://git@github.com/arangodb/enterprise" -logfile $false -priority "Normal"
        }
        Pop-Location
    }
}

Function checkoutUpgradeDataTests
{
    If ($global:ok)
    {
        Push-Location $pwd
        If (Test-Path -PathType Container -Path $global:UPGRADEDATADIR)
        {
            Set-Location $global:UPGRADEDATADIR
            If (Test-Path -PathType Container -Path "$global:UPGRADEDATADIR\.git")
            {
                proc -process "git" -argument "rev-parse --is-inside-work-tree" -logfile $false -priority "Normal"
                If ($global:ok)
                {
                    If (($(git remote show -n origin) | Select-String -Pattern " Fetch " -CaseSensitive | %{$_.Line.Split("/")[-1]}) -eq 'upgrade-data-tests')
                    {
                        Write-Host "=="$(Get-Date)"== started fetch 'upgrade-data-tests'"
                        proc -process "git" -argument "remote update" -logfile $false -priority "Normal" 
                        proc -process "git" -argument "checkout -f" -logfile $false -priority "Normal"
                        Write-Host "=="$(Get-Date)"== finished fetch 'upgrade-data-tests'"
                        $needReset = $False
                        If ($(git status -uno) | Select-String -Pattern "behind" -CaseSensitive)
                        {
                            Write-Host "=="$(Get-Date)"== started clean and reset 'upgrade-data-tests'"
                            proc -process "git" -argument "clean -fdx" -logfile $false -priority "Normal"
                            proc -process "git" -argument "reset --hard origin/devel" -logfile $false -priority "Normal"
                            Write-Host "=="$(Get-Date)"== finished clean and reset 'upgrade-data-tests'"
                        }
                    } Else { $needReset = $True }
                } Else { $needReset = $True }
            } Else { $needReset = $True }
            If ($needReset -eq $True)
            {
              Set-Location $global:ARANGODIR
              Remove-Item -Recurse -Force $global:UPGRADEDATADIR
            }
        }
        If(-Not(Test-Path -PathType Container -Path $global:UPGRADEDATADIR))
        {
            If(Test-Path -PathType Leaf -Path "$HOME\.ssh\known_hosts")
            {
                Remove-Item -Force "$HOME\.ssh\known_hosts"
                proc -process "ssh" -argument "-o StrictHostKeyChecking=no git@github.com" -logfile $false -priority "Normal"
            }
            Set-Location $global:ARANGODIR
            Write-Host "=="$(Get-Date)"== started clone 'upgrade-data-tests'"
            proc -process "git" -argument "clone ssh://git@github.com/arangodb/upgrade-data-tests" -logfile $false -priority "Normal"
            Write-Host "=="$(Get-Date)"== finished clone 'upgrade-data-tests'"
        }
        Pop-Location
    }
}

Function checkoutIfNeeded
{
    If($ENTERPRISEEDITION -eq "On")
    {
        If(-Not(Test-Path -PathType Container -Path $global:ENTERPRISEDIR))
        {
            checkoutEnterprise
        }
    }
    Else
    {
        If(-Not(Test-Path -PathType Container -Path $global:ARANGODIR))
        {
            checkoutArangoDB
        }
    }
    checkoutUpgradeDataTests
}

Function switchBranches($branch_c,$branch_e)
{
    $branch_c = $branch_c.ToString()
    $branch_e = $branch_e.ToString()

    checkoutIfNeeded
    Push-Location $pwd
    Set-Location $global:ARANGODIR;comm
    If ($global:ok)
    {
        proc -process "git" -argument "clean -fdx" -logfile $false -priority "Normal"
    }
    If ($global:ok)
    {
        proc -process "git" -argument "checkout -- ." -logfile $false -priority "Normal"
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
        proc -process "git" -argument "checkout $branch_c" -logfile $false -priority "Normal"
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
        Write-Output "Community: $(git rev-parse --verify HEAD)" | Out-File "$global:INNERWORKDIR\sourceInfo.log"
    }
    If($ENTERPRISEEDITION -eq "On")
    {
        Push-Location $pwd
        Set-Location $global:ENTERPRISEDIR;comm
        If ($global:ok)
        {
            proc -process "git" -argument "clean -fdx" -logfile $false -priority "Normal"
        }
        If ($global:ok)
        {
            proc -process "git" -argument "checkout -- ." -logfile $false -priority "Normal"
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
            proc -process "git" -argument "checkout $branch_e" -logfile $false -priority "Normal"
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
            Write-Output "Enterprise: $(git rev-parse --verify HEAD)" | Out-File "$global:INNERWORKDIR\sourceInfo.log" -Append -NoNewLine
        }
        Pop-Location
    }
    Pop-Location
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
    ForEach($report in $(Get-ChildItem -Path $INNERWORKDIR -Filter "testreport*"))
    {
        Remove-Item -Force $report.FullName
    }
    ForEach($log in $(Get-ChildItem -Path $INNERWORKDIR -Filter "*.log"))
    {
        Remove-Item -Force $log.FullName
    }
    If(Test-Path -PathType Leaf -Path $INNERWORKDIR\test.log)
    {
        Remove-Item -Force $INNERWORKDIR\test.log
    }
    If(Test-Path -PathType Leaf -Path $env:TMP\testProtocol.txt)
    {
        Remove-Item -Force $env:TMP\testProtocol.txt
    }
    If(Test-Path -PathType Leaf -Path $INNERWORKDIR\testfailures.txt)
    {
        Remove-Item -Force $INNERWORKDIR\testfailures.txt
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
    If($ENTERPRISEEDITION -eq "On")
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
    If(Test-Path -PathType Leaf -Path $env:TMP\testProtocol.txt)
    {
        Remove-Item -Force $env:TMP\testProtocol.txt
    }
    New-Item -Force $env:TMP\testProtocol.txt
    $(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH.mm.ssZ") | Add-Content $env:TMP\testProtocol.txt
    Write-Output "========== Status of main repository:" | Add-Content $env:TMP\testProtocol.txt
    Write-Host "========== Status of main repository:"
    ForEach($line in $global:repoState)
    {
        Write-Output " $line" | Add-Content $env:TMP\testProtocol.txt
        Write-Host " $line"
    }
    If($ENTERPRISEEDITION -eq "On")
    {
        Write-Output "Status of enterprise repository:" | Add-Content $env:TMP\testProtocol.txt
        Write-Host "Status of enterprise repository:"
        ForEach($line in $global:repoStateEnterprise)
        {
            Write-Output " $line" | Add-Content $env:TMP\testProtocol.txt
            Write-Host " $line"
        }
    }
}


Function getCacheID
{
       
    If ($ENTERPRISEEDITION -eq "On")
    {
        Get-ChildItem -Include "CMakeLists.txt","VERSIONS","*.cmake" -Recurse  | ? { $_.Directory -NotMatch '.*build.*' } | Get-FileHash > $env:TMP\allHashes.txt
    }
    else
    {
        # if there happenes to be an enterprise directory, we ignore it.
        Get-ChildItem -Include "CMakeLists.txt","VERSIONS","*.cmake" -Recurse | ? { $_.Directory -NotMatch '.*enterprise.*' } | ? { $_.Directory -NotMatch '.*build.*' } | Get-FileHash > $env:TMP\allHashes.txt
    }
    
    $hash = "$((Get-FileHash $env:TMP\allHashes.txt).Hash)" + ($env:OPENSSL_ROOT_DIR).GetHashCode() + (Split-Path $env:CLCACHE_CL).GetHashCode()
    $hashStr = "$env:CMAKE_CONFIGURE_DIR\${hash}-EP_${ENTERPRISEEDITION}.zip"
    Remove-Item -Force $env:TMP\allHashes.txt
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
            If($ENTERPRISEEDITION -eq "On")
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
    If(Test-Path -PathType Container -Path "$global:ARANGODIR\build")
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

    if ($global:ok)
    {
      configureCache
      #$cacheZipFN = getCacheID
      $haveCache = $False #$(Test-Path -Path $cacheZipFN)
      Push-Location $pwd
      Set-Location "$global:ARANGODIR\build"
      if($haveCache)
      {
          Write-Host "Extracting cmake configure zip: ${cacheZipFN}"
          # Touch the file, so a cleanup job sees its used:
          $file = Get-Item $cacheZipFN
          $file.LastWriteTime = (get-Date)
          # extract it
          7unzip $cacheZipFN
      }
      $ARANGODIR_SLASH = $global:ARANGODIR -replace "\\","/"
      If($ENTERPRISEEDITION -eq "On")
      {
          downloadStarter
          downloadSyncer
          copyRclone
          $THIRDPARTY_SBIN_LIST="$ARANGODIR_SLASH/build/arangosync.exe"
          If ($global:USE_RCLONE -eq "true")
          {
              $THIRDPARTY_SBIN_LIST="$THIRDPARTY_SBIN_LIST;$ARANGODIR_SLASH/build/rclone-arangodb.exe"
          }
          Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"   
          Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"$GENERATORID,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DTHIRDPARTY_SBIN=`"$THIRDPARTY_SBIN_LIST`" `"$global:ARANGODIR`""
          proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"$GENERATORID,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DTHIRDPARTY_SBIN=`"$THIRDPARTY_SBIN_LIST`" `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake" -priority "Normal"
      }
      Else
      {
          downloadStarter
          Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
          Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"$GENERATORID,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" `"$global:ARANGODIR`""
          proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"$GENERATORID,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DUSE_STRICT_OPENSSL_VERSION=On -DTHIRDPARTY_BIN=`"$ARANGODIR_SLASH/build/arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake" -priority "Normal"
      }
      #if(!$haveCache)
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
    Write-Host "Build: cmake --build . --config `"$BUILDMODE`""
    Remove-Item -Force "${global:INNERWORKDIR}\*.pdb" -ErrorAction SilentlyContinue
    proc -process "cmake" -argument "--build . --config `"$BUILDMODE`"" -logfile "$INNERWORKDIR\build" -priority "Normal"
    If($global:ok)
    {
        Copy-Item "$global:ARANGODIR\build\bin\$BUILDMODE\*" -Destination "$global:ARANGODIR\build\bin\"; comm
        If(Test-Path -PathType Container -Path "$global:ARANGODIR\build\tests\$BUILDMODE")
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
    ForEach($TARGET in @("package-arangodb-server-nsis","package-arangodb-server-zip","package-arangodb-client-nsis"))
    {
        Write-Host "Build: cmake --build . --config `"$BUILDMODE`" --target `"$TARGET`""
        proc -process "cmake" -argument "--build . --config `"$BUILDMODE`" --target `"$TARGET`"" -logfile "$INNERWORKDIR\$TARGET-package" -priority "Normal"
        if (-not $global:ok)
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
    ForEach($PACKAGE in $(Get-ChildItem -Filter ArangoDB3*.exe).FullName)
    {
        Write-Host "Sign: signtool.exe sign /tr `"http://sha256timestamp.ws.symantec.com/sha256/timestamp`" `"$PACKAGE`""
        proc -process "signtool.exe" -argument "sign /tr `"http://sha256timestamp.ws.symantec.com/sha256/timestamp`" `"$PACKAGE`"" -logfile "$INNERWORKDIR\$($PACKAGE.Split('\')[-1])-sign" -priority "Normal"
    }
    Pop-Location
}

Function storeSymbols
{
    If(-Not((Get-Content $INNERWORKDIR\ArangoDB\CMakeLists.txt) -match 'set\(ARANGODB_VERSION_RELEASE_TYPE \"nightly\"'))
    {
        Push-Location $pwd
        Set-Location "$global:ARANGODIR\build\"
        If(-not((Get-SmbMapping -LocalPath S: -ErrorAction SilentlyContinue).Status -eq "OK"))
        {
            New-SmbMapping -LocalPath 'S:' -RemotePath '\\symbol.arangodb.biz\symbol' -Persistent $true
        }
        findArangoDBVersion | Out-Null
        ForEach($SYMBOL in $((Get-ChildItem "$global:ARANGODIR\build\bin\$BUILDMODE" -Recurse -Filter "*.pdb").FullName))
        {
            Write-Host "Symbol: symstore.exe add /f `"$SYMBOL`" /s `"S:\symsrv_arangodb$global:ARANGODB_VERSION_MAJOR$global:ARANGODB_VERSION_MINOR`" /t ArangoDB /compress"
            proc -process "symstore.exe" -argument "add /f `"$SYMBOL`" /s `"S:\symsrv_arangodb$global:ARANGODB_VERSION_MAJOR$global:ARANGODB_VERSION_MINOR`" /t ArangoDB /compress" -logfile "$INNERWORKDIR\symstore" -priority "Normal"
        }
        #uploadSymbols functionality moved to jenkins/releaseUploadFiles3.fish due to problems with gsutil on Windows
        #uploadSymbols
        Pop-Location
    }
}

Function setNightlyRelease
{
    checkoutIfNeeded
    (Get-Content $ARANGODIR\CMakeLists.txt) -replace 'set\(ARANGODB_VERSION_RELEASE_TYPE .*', 'set(ARANGODB_VERSION_RELEASE_TYPE "nightly")' | Out-File -Encoding UTF8 $ARANGODIR\CMakeLists.txt
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
        Write-Host "Preserve symbols (PDBs) to ${global:INNERWORKDIR}\ArangoDB3${suffix}-${global:ARANGODB_FULL_VERSION}.pdb.zip"
        If (Test-Path -Path "$global:ARANGODIR\build\bin\$BUILDMODE\*.pdb")
        {
            Remove-Item -Force "${global:INNERWORKDIR}\ArangoDB3${suffix}-${global:ARANGODB_FULL_VERSION}.pdb.zip" -ErrorAction SilentlyContinue
            7zip -Path *.pdb -DestinationPath "${global:INNERWORKDIR}\ArangoDB3${suffix}-${global:ARANGODB_FULL_VERSION}.pdb.zip"; comm
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
    If($KEEPBUILD -eq "Off")
    {
       If(Test-Path -PathType Container -Path "$global:ARANGODIR\build")
       {
          Remove-Item -Recurse -Force -Path "$global:ARANGODIR\build"
          Write-Host "Delete Builddir OK."
       }
    }
    configureWindows
    If($global:ok)
    {
        Write-Host "Configure OK."
        buildWindows
        if($global:ok)
        {
            Write-Host "Build OK."
            preserveSymbolsToWorkdir
            if($SKIPPACKAGING -eq "Off")
            {
                packageWindows
                if($global:ok)
                {
                    Write-Host "Package OK."
                    if($SIGN)
                    {
                        signWindows
                        if($global:ok)
                        {
                            Write-Host "Sign OK."
                        }
                        Else
                        {
                            Write-Host "Sign error, see $INNERWORKDIR\sign.* for details."
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
    If(Test-Path -PathType Leaf "$INNERWORKDIR\test.log")
    {
        If((Get-Content -Path "$INNERWORKDIR\test.log" -Head 1 | Select-String -Pattern "BAD" -CaseSensitive) -Or $global:WORKSPACE_LOGS -eq "all")
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
    If(Test-Path -PathType Leaf "$INNERWORKDIR\test.log")
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
    If(Test-Path -PathType Leaf "$INNERWORKDIR\sourceInfo.log")
    {
        Write-Host "Move $INNERWORKDIR\sourceInfo.log"
        Move-Item -Force -Path "$INNERWORKDIR\sourceInfo.log" -Destination $ENV:WORKSPACE; comm
    }
    Write-Host "package* ..."
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "package*"))
    {
        Write-Host "Move $INNERWORKDIR\$file"
        Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
    }
    
    If ($PDBS_TO_WORKSPACE -eq "always" -or ($PDBS_TO_WORKSPACE -eq "crash" -and $global:hasTestCrashes -eq "true"))
    {
        Write-Host "ArangoDB3*pdb.zip ..."
        ForEach ($file in $(Get-ChildItem "$INNERWORKDIR" -Filter "ArangoDB3*pdb.zip"))
        {
            Write-Host "Move $INNERWORKDIR\$file"
            Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm 
        }
    }

    If($SKIPPACKAGING -eq "Off")
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
    Write-Host "testfailures.log"
    If(Test-Path -PathType Leaf "$INNERWORKDIR\testfailures.log")
    {
        Write-Host "Move $INNERWORKDIR\testfailures.log"
        Move-Item -Force -Path "$INNERWORKDIR\testfailures.log" -Destination $ENV:WORKSPACE; comm 
    }
}

################################################################################
# Oskar entry points
################################################################################

Function configureDumpsArangoDB
{
    Write-Host "Configure crashdumps for arango* processes to reside in ${global:COREDIR}..."
    clearWER
    ForEach($executable in (Get-ChildItem -File -Filter "arango*.exe" -Path "$global:ARANGODIR\build\bin\$BUILDMODE"))
    {
        configureWER -executable $executable -path $global:COREDIR
    }
    comm
}

Function oskar
{
    checkoutIfNeeded
    if($global:ok)
    {
        configureDumpsArangoDB
        & "$global:SCRIPTSDIR\runTests.ps1"
    }
}

Function oskarFull
{
    checkoutIfNeeded
    if($global:ok)
    {
        configureDumpsArangoDB
        & "$global:SCRIPTSDIR\runFullTests.ps1"
    }
}

Function oskar1
{
    showConfig
    buildStaticArangoDB
    if($global:ok)
    {
        oskar
    }
}

Function oskar1Full
{
    showConfig
    buildStaticArangoDB
    if($global:ok)
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

Function makeCommunityRelease
{
    maintainerOff
    staticExecutablesOn
    skipPackagingOff
    signPackageOn
    community
    buildArangoDB
    If ($global:ok) 
    {
        storeSymbols
    }
}

Function makeEnterpriseRelease
{
    maintainerOff
    staticExecutablesOn
    skipPackagingOff
    signPackageOn
    enterprise
    buildArangoDB
    If ($global:ok) 
    {
        storeSymbols
    }
}

Function makeRelease
{
    makeEnterpriseRelease
    If ($global:ok) 
    {
        makeCommunityRelease
    }
}

parallelism ([int]$env:NUMBER_OF_PROCESSORS)

$global:SYSTEM_IS_WINDOWS=$true
