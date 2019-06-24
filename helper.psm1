$global:WORKDIR = $pwd
$global:SCRIPTSDIR = Join-Path -Path $global:WORKDIR -ChildPath scripts

If(-Not($ENV:WORKSPACE))
{
    $ENV:WORKSPACE = Join-Path -Path $global:WORKDIR -ChildPath work
}

If(-Not(Test-Path -PathType Container -Path "work"))
{
    New-Item -ItemType Directory -Path "work"
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

$global:GENERATOR = "Visual Studio 15 2017 Win64"

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
        If($p.ExitCode -eq 0)
        {
            Set-Variable -Name "ok" -Value $true -Scope global
        }
        Else
        {
            Set-Variable -Name "ok" -Value $false -Scope global
        }
    }
    Else
    {
        $p = Start-Process $process -ArgumentList $argument -RedirectStandardOutput "$logfile.stdout.log" -RedirectStandardError "$logfile.stderr.log" -PassThru
        $p.PriorityClass = $priority
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
    Write-Host "Packaging      : "$PACKAGING
    Write-Host "Static exec    : "$STATICEXECUTABLES
    Write-Host "Static libs    : "$STATICLIBS
    Write-Host "Failure tests  : "$USEFAILURETESTS
    Write-Host "Keep build     : "$KEEPBUILD
    Write-Host "PDBs workspace : "$PDBS_TO_WORKSPACE
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
    (Select-String -Path "$global:ARANGODIR\VERSIONS" -SimpleMatch "STARTER_REV")[0] -match '([0-9]+.[0-9]+.[0-9]+)|latest' | Out-Null
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

Function copyRclone {
  Copy-Item "$global:WORKDIR\rclone\rclone-arangodb-windows.exe" -Destination "$global:ARANGODIR\build\rclone-arangodb.exe"
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
    if($global:ok)
    {
        Push-Location $pwd
        Set-Location $global:ARANGODIR
        If(-Not(Test-Path -PathType Container -Path "upgrade-data-tests"))
        {
            If(Test-Path -PathType Leaf -Path "$HOME\.ssh\known_hosts")
            {
                Remove-Item -Force "$HOME\.ssh\known_hosts"
                proc -process "ssh" -argument "-o StrictHostKeyChecking=no git@github.com" -logfile $false -priority "Normal"
            }
            proc -process "git" -argument "clone ssh://git@github.com/arangodb/upgrade-data-tests" -logfile $false -priority "Normal"
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
    If(-Not(Test-Path -PathType Container -Path $global:UPGRADEDATADIR))
    {
        checkoutUpgradeDataTests
    }
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
        proc -process "git" -argument "reset --hard origin/master" -logfile $false -priority "Normal"
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
        Get-ChildItem -Filter CMakeLists.txt -Recurse  | ? { $_.Directory -NotMatch '.*build.*' } |get-filehash > $env:TMP\allHashes.txt
    }
    else
    {
        # if there happenes to be an enterprise directory, we ignore it.
        Get-ChildItem -Filter CMakeLists.txt -Recurse | ? { $_.Directory -NotMatch '.*enterprise.*' } | ? { $_.Directory -NotMatch '.*build.*' } | get-filehash > $env:TMP\allHashes.txt
    }
    
    $hash = "$((get-filehash $env:TMP\allHashes.txt).Hash)"
    $hashStr = "$env:CMAKE_CONFIGURE_DIR\${hash}-EP_${ENTERPRISEEDITION}.zip"
    Remove-Item -Force $env:TMP\allHashes.txt
    return $hashStr
}

################################################################################
# Compiling & package generation
################################################################################

Function configureWindows
{
    If(-Not(Test-Path -PathType Container -Path "$global:ARANGODIR\build"))
    {
        New-Item -ItemType Directory -Path "$global:ARANGODIR\build"
    }

    configureCache
    $cacheZipFN = getCacheID
    $haveCache = $(Test-Path -Path $cacheZipFN)
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
    If($ENTERPRISEEDITION -eq "On")
    {
        downloadStarter
        downloadSyncer
        copyRclone
        Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"   
        Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DTHIRDPARTY_SBIN=`"$global:ARANGODIR\build\arangosync.exe`" `"$global:ARANGODIR`""
        proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" -DTHIRDPARTY_SBIN=`"$global:ARANGODIR\build\arangosync.exe`" `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake" -priority "Normal"
    }
    Else
    {
        downloadStarter
        Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
        Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" `"$global:ARANGODIR`""
        proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_GOOGLE_TESTS=`"$MAINTAINER`" -DUSE_CATCH_TESTS=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" -DUSE_CLCACHE_MODE=`"$CLCACHE`" `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake" -priority "Normal"
    }
    if(!$haveCache)
    {
        Write-Host "Archiving cmake configure zip: ${cacheZipFN}"
        7zip -Path $global:ARANGODIR\build\*  -DestinationPath $cacheZipFN "-xr!*.exe"; comm
    }
    Write-Host "Clcache Statistics"
    showCacheStats
    Pop-Location
}

Function buildWindows 
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    Write-Host "Build: cmake --build . --config `"$BUILDMODE`""
    proc -process "cmake" -argument "--build . --config `"$BUILDMODE`"" -logfile "$INNERWORKDIR\build" -priority "Normal"
    If($global:ok)
    {
        Copy-Item "$global:ARANGODIR\build\bin\$BUILDMODE\*" -Destination "$global:ARANGODIR\build\bin\"; comm
        If(Test-Path -PathType Container -Path "$global:ARANGODIR\build\tests\$BUILDMODE")
        {
          Copy-Item "$global:ARANGODIR\build\tests\$BUILDMODE\*" -Destination "$global:ARANGODIR\build\tests\"; comm
        }
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
        #uploadSymbols
        Pop-Location
    }
}

Function setNightlyRelease
{
    checkoutIfNeeded
    (Get-Content $ARANGODIR\CMakeLists.txt) -replace 'set\(ARANGODB_VERSION_RELEASE_TYPE .*', 'set(ARANGODB_VERSION_RELEASE_TYPE "nightly")' | Out-File -Encoding UTF8 $ARANGODIR\CMakeLists.txt
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
                        }
                    }
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
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "*.zip"))
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
    ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "cmake*"))
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
    If ($PDBS_TO_WORKSPACE -eq "always" -or ($PDBS_TO_WORKSPACE -eq "crash" -and $global:hasTestCrashes -eq "true"))
    {
        Write-Host "*.pdb ..."
        Push-Location $global:ARANGODIR\build\bin\$BUILDMODE
        If($ENTERPRISEEDITION -eq "On")
        {
            7zip -Path *.pdb -DestinationPath $ENV:WORKSPACE\ArangoDB3e-$global:ARANGODB_FULL_VERSION.pdb.zip; comm
        }
        Else
        {
            7zip -Path *.pdb -DestinationPath $ENV:WORKSPACE\ArangoDB3-$global:ARANGODB_FULL_VERSION.pdb.zip; comm
        }
        Pop-Location
    }

    if($SKIPPACKAGING -eq "Off")
    {
        Write-Host "ArangoDB3*.exe ..."
        ForEach ($file in $(Get-ChildItem "$global:ARANGODIR\build" -Filter "ArangoDB3*.exe"))
        {
            Write-Host "Move $global:ARANGODIR\build\$file"
            Move-Item -Force -Path "$global:ARANGODIR\build\$file" -Destination $ENV:WORKSPACE; comm 
        }
        Write-Host "ArangoDB3*.zip ..."
        ForEach ($file in $(Get-ChildItem "$global:ARANGODIR\build" -Filter "ArangoDB3*.zip"))
        {
            Write-Host "Move $global:ARANGODIR\build\$file"
            Move-Item -Force -Path "$global:ARANGODIR\build\$file" -Destination $ENV:WORKSPACE; comm 
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

Function oskar
{
    checkoutIfNeeded
    if($global:ok)
    {
        & "$global:SCRIPTSDIR\runTests.ps1"
    }
}

Function oskarFull
{
    checkoutIfNeeded
    if($global:ok)
    {
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
    storeSymbols
    moveResultsToWorkspace
}

Function makeEnterpriseRelease
{
    maintainerOff
    staticExecutablesOn
    skipPackagingOff
    signPackageOn
    enterprise
    buildArangoDB
    storeSymbols
    moveResultsToWorkspace
}

Function makeRelease
{
    makeCommunityRelease
    makeEnterpriseRelease
}

parallelism ([int]$env:NUMBER_OF_PROCESSORS)

$global:SYSTEM_IS_WINDOWS=$true
