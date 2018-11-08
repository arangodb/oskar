$global:WORKDIR = $pwd

If(-Not($ENV:WORKSPACE))
{
    $ENV:WORKSPACE = Join-Path -Path $global:WORKDIR -ChildPath work
}

If(-Not(Test-Path -PathType Container -Path "work"))
{
    New-Item -ItemType Directory -Path "work"
}

$global:INNERWORKDIR = "$WORKDIR\work"
$global:ARANGODIR = "$INNERWORKDIR\ArangoDB"
$global:ENTERPRISEDIR = "$global:ARANGODIR\enterprise"
$env:TMP = "$INNERWORKDIR\tmp"
$env:CLCACHE_DIR="$INNERWORKDIR\.clcache.windows"

$global:GENERATOR = "Visual Studio 15 2017 Win64"

$global:launcheableTests = @()
$global:maxTestCount = 0
$global:testCount = 0
$global:portBase = 10000

$global:ok = $true

################################################################################
# Utilities
################################################################################

#ToDo
#Function transformBundleSniplet
#{   
#}

While (Test-Path Alias:curl) 
{
    Remove-Item Alias:curl
}

Function proc($process,$argument,$logfile)
{
    If($logfile -eq $false)
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
    Else
    {
        $p = Start-Process $process -ArgumentList $argument -RedirectStandardOutput "$logfile.stdout.log" -RedirectStandardError "$logfile.stderr.log" -PassThru
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

Function 7zip($Path,$DestinationPath)
{
    7za.exe a -mx9 $DestinationPath $Path 
}

################################################################################
# Locking
################################################################################

Function lockDirectory
{
    Push-Location $pwd
    Set-Location $WORKDIR
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

Function showConfig
{
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "Global Configuration"
    Write-Host "User           : "$env:USERDOMAIN\$env:USERNAME
    Write-Host "Cache          : "$env:CLCACHE_CL
    Write-Host "Cachedir       : "$env:CLCACHE_DIR
    Write-Host " "
    Write-Host "Build Configuration"
    Write-Host "Buildmode      : "$BUILDMODE
    Write-Host "Enterprise     : "$ENTERPRISEEDITION
    Write-Host "Maintainer     : "$MAINTAINER
    Write-host "SkipGrey       : "$SKIPGREY
    Write-Host " "
    Write-Host "Generator      : "$GENERATOR
    Write-Host "Packaging      : "$PACKAGING
    Write-Host "Static exec    : "$STATICEXECUTABLES
    Write-Host "Static libs    : "$STATICLIBS
    Write-Host "Failure tests  : "$USEFAILURETESTS
    Write-Host "Keep build     : "$KEEPBUILD
    Write-Host " "	
    Write-Host "Test Configuration"
    Write-Host "Storage engine : "$STORAGEENGINE
    Write-Host "Test suite     : "$TESTSUITE
    Write-Host " "
    Write-Host "Internal Configuration"
    Write-Host "Parallelism    : "$numberSlots
    Write-Host "Verbose        : "$VERBOSEOSKAR
    Write-Host " "
    Write-Host "Directories"
    Write-Host "Inner workdir  : "$INNERWORKDIR
    Write-Host "Workdir        : "$WORKDIR
    Write-Host "Workspace      : "$env:WORKSPACE
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " "
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

Function debugMode
{
    $global:BUILDMODE = "Debug"
}
Function releaseMode
{
    $global:BUILDMODE = "RelWithDebInfo"
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


################################################################################
# Version detection
################################################################################

Function  findArangoDBVersion
{
    If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_MAJOR")[0] -match '.*"([0-9a-zA-Z]*)".*')
    {
        $global:ARANGODB_VERSION_MAJOR = $Matches[1]
        If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_MINOR")[0] -match '.*"([0-9a-zA-Z]*)".*')
        {
            $global:ARANGODB_VERSION_MINOR = $Matches[1]
            If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_PATCH")[0] -match '.*"([0-9a-zA-Z]*)".*')
            {
                $global:ARANGODB_VERSION_PATCH = $Matches[1]
                If($(Select-String -Path $global:ARANGODIR\CMakeLists.txt -SimpleMatch "set(ARANGODB_VERSION_RELEASE_TYPE")[0] -match '.*"([0-9a-zA-Z]*)".*')
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

################################################################################
# git working copy manipulation
################################################################################

Function checkoutArangoDB
{
    Push-Location $pwd
    Set-Location $INNERWORKDIR
    If(-Not(Test-Path -PathType Container -Path "ArangoDB"))
    {
        proc -process "git" -argument "clone https://github.com/arangodb/ArangoDB" -logfile $false
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
            If(Test-Path -PathType Leaf -Path "$HOME\.ssh\known_hosts")
            {
                Remove-Item -Force "$HOME\.ssh\known_hosts"
                proc -process "ssh" -argument "-o StrictHostKeyChecking=no git@github.com" -logfile $false
            }
            proc -process "git" -argument "clone ssh://git@github.com/arangodb/enterprise" -logfile $false
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
}

Function switchBranches($branch_c,$branch_e)
{
    checkoutIfNeeded
    Push-Location $pwd
    Set-Location $global:ARANGODIR;comm
    If ($global:ok) 
    {
        proc -process "git" -argument "clean -fdx" -logfile $false
    }
    If ($global:ok) 
    {
        proc -process "git" -argument "checkout -- ." -logfile $false
    }
    If ($global:ok) 
    {
        proc -process "git" -argument "fetch" -logfile $false
    }
    If ($global:ok) 
    {
        proc -process "git" -argument "checkout $branch_c" -logfile $false
    }
    If ($branch_c.StartsWith("v"))
    {
        If ($global:ok) 
        {
            proc -process "git" -argument "checkout -- ." -logfile $false
        }
    }
    Else
    {
        If ($global:ok) 
        {
            proc -process "git" -argument "reset --hard origin/$branch_c" -logfile $false
        }
    }
    If($ENTERPRISEEDITION -eq "On")
    {
        Push-Location $pwd
        Set-Location $global:ENTERPRISEDIR;comm
        If ($global:ok) 
        {
            proc -process "git" -argument "clean -fdx" -logfile $false
        }
        If ($global:ok) 
        {
            proc -process "git" -argument "checkout -- ." -logfile $false
        }
        If ($global:ok) 
        {
            proc -process "git" -argument "fetch" -logfile $false
        }
        If ($global:ok) 
        {
            proc -process "git" -argument "checkout $branch_e" -logfile $false
        }
        If ($branch_e.StartsWith("v"))
        {
            If ($global:ok) 
            {
                proc -process "git" -argument "checkout -- ." -logfile $false
            }
        }
        Else
        {
            If ($global:ok) 
            {
                proc -process "git" -argument "reset --hard origin/$branch_e" -logfile $false
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
        proc -process "git" -argument "checkout -- ." -logfile $false
    }
    If ($global:ok) 
    {
        proc -process "git" -argument "reset --hard origin/master" -logfile $false
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

################################################################################
# Compiling & package generation
################################################################################

Function configureWindows
{
    If(-Not(Test-Path -PathType Container -Path "$global:ARANGODIR\build"))
    {
        New-Item -ItemType Directory -Path "$global:ARANGODIR\build"
    }
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build"
    If($ENTERPRISEEDITION -eq "On")
    {
        downloadStarter
        downloadSyncer
        Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"   
        Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" -DTHIRDPARTY_SBIN=`"$global:ARANGODIR\build\arangosync.exe`" `"$global:ARANGODIR`""
	    proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" -DTHIRDPARTY_SBIN=`"$global:ARANGODIR\build\arangosync.exe`" `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake"
    }
    Else
    {
        downloadStarter
        Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
        Write-Host "Configure: cmake -G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" `"$global:ARANGODIR`""
	    proc -process "cmake" -argument "-G `"$GENERATOR`" -T `"v141,host=x64`" -DUSE_MAINTAINER_MODE=`"$MAINTAINER`" -DUSE_ENTERPRISE=`"$ENTERPRISEEDITION`" -DCMAKE_BUILD_TYPE=`"$BUILDMODE`" -DPACKAGING=NSIS -DCMAKE_INSTALL_PREFIX=/ -DSKIP_PACKAGING=`"$SKIPPACKAGING`" -DUSE_FAILURE_TESTS=`"$USEFAILURETESTS`" -DSTATIC_EXECUTABLES=`"$STATICEXECUTABLES`" -DOPENSSL_USE_STATIC_LIBS=`"$STATICLIBS`" -DTHIRDPARTY_BIN=`"$global:ARANGODIR\build\arangodb.exe`" `"$global:ARANGODIR`"" -logfile "$INNERWORKDIR\cmake"
    }
    #"
    Pop-Location
}

Function buildWindows 
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    Write-Host "Build: cmake --build . --config `"$BUILDMODE`""
    proc -process "cmake" -argument "--build . --config `"$BUILDMODE`"" -logfile "$INNERWORKDIR\build"
    If($global:ok)
    {
        Copy-Item "$global:ARANGODIR\build\bin\$BUILDMODE\*" -Destination "$global:ARANGODIR\build\bin\"; comm
    }
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
        proc -process "cmake" -argument "--build . --config `"$BUILDMODE`" --target `"$TARGET`"" -logfile "$INNERWORKDIR\$TARGET-package"
    }
    #`
    Pop-Location
}

Function signWindows
{
    Push-Location $pwd
    Set-Location "$global:ARANGODIR\build\"
    #"
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    $SIGNTOOL = $(Get-ChildItem C:\ -Recurse "signtool.exe" -ErrorAction SilentlyContinue).FullName[0]
    ForEach($PACKAGE in $(Get-ChildItem -Filter ArangoDB3*.exe).FullName)
    {
        Write-Host "Sign: $SIGNTOOL sign /tr `"http://sha256timestamp.ws.symantec.com/sha256/timestamp`" `"$PACKAGE`""
        proc -process "$SIGNTOOL" -argument "sign /tr `"http://sha256timestamp.ws.symantec.com/sha256/timestamp`" `"$PACKAGE`"" -logfile "$INNERWORKDIR\$PACKAGE-sign"
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
    Write-Host "Moving reports and logs to $ENV:WORKSPACE ..."
    Write-Host "test.log ..."
    If(Test-Path -PathType Leaf "$INNERWORKDIR\test.log")
    {
        If(Get-Content -Path "$INNERWORKDIR\test.log" -Head 1 | Select-String -Pattern "BAD" -CaseSensitive)
        {
            ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter testreport*))
            {
                Write-Host "Move $INNERWORKDIR\$file"
                Move-Item -Force -Path "$INNERWORKDIR\$file" -Destination $ENV:WORKSPACE; comm
            } 
        }
        Else
        {
            ForEach ($file in $(Get-ChildItem $INNERWORKDIR -Filter "testreport*" -Exclude "*.zip"))
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
# Test control
################################################################################

Function launchTest($which) {
    Push-Location $pwd
    Set-Location $global:ARANGODIR; comm
    $arangosh = "$global:ARANGODIR\build\bin\$BUILDMODE\arangosh.exe"
    $test = $global:launcheableTests[$which]
    Write-Host "Test: " $test['testname'] " - " $test['identifier']
    Write-Host "Time: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))"
    Write-Host $arangosh " --- " $test['commandline'] 
    Write-Host "-RedirectStandardOutput " $test['StandardOutput']
    Write-Host "-RedirectStandardError " $test['StandardError']

    $process = $(Start-Process -FilePath "$arangosh" -ArgumentList $test['commandline'] -RedirectStandardOutput $test['StandardOutput'] -RedirectStandardError $test['StandardError'] -PassThru)
    
    $global:launcheableTests[$which]['pid'] = $process.Id
    $global:launcheableTests[$which]['launchDate'] = $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ'))

    $str=$($test | where {($_.Name -ne "commandline")} | Out-String)
    Write-Host $str
    Pop-Location
}

Function registerTest($testname, $index, $bucket, $filter, $moreParams, $cluster, $weight)
{
    Write-Host "$global:ARANGODIR\UnitTests\OskarTestSuitesBlackList"
    If(-Not(Select-String -Path "$global:ARANGODIR\UnitTests\OskarTestSuitesBlackList" -pattern $testname))
    {
    	$testWeight = 1
    	$testparams = ""
    	If ($filter) {
    	   $testparams = $testparams+" --test $filter"
    	}
    	if ($bucket) {
    	    $testparams = $testparams+" --testBuckets $bucket"
    	}
    	if ($cluster -eq $true)
        {
    	    $testWeight = 4
            $cluster = "true"
    	}
        else
        {
            $cluster = "false"
        }
        if ($weight) {
          $testWeight = $weight
        }
    	$output = $testname
    	if ($index) {
    	  $output = $output+"_$index"
    	}
    	$testparams = $testparams+" --cluster $cluster --coreCheck true --storageEngine $STORAGEENGINE --minPort $global:portBase --maxPort $($global:portBase + 99) --skipNondeterministic true --skipTimeCritical true --writeXmlReport true --skipGrey $global:SKIPGREY"
    	
    	$testparams = $testparams+" --testOutput $env:TMP\$output.out"
    	
    	$testparams + $testparams+$moreParams
    	
    	$PORT=Get-Random -Minimum 20000 -Maximum 65535
    	$i = $global:testCount
    	$global:testCount = $global:testCount+1
    	$global:launcheableTests += @{
    	  weight=$testWeight;
   	  testname=$testname;
   	  identifier=$output;
    	  commandline=" -c $global:ARANGODIR\etc\relative\arangosh.conf --log.level warning --server.endpoint tcp://127.0.0.1:$PORT --javascript.execute $global:ARANGODIR\UnitTests\unittest.js -- $testname $testparams";
    	  StandardOutput="$global:ARANGODIR\$output.stdout.log";
    	  StandardError="$global:ARANGODIR\$output.stderr.log";
    	  pid=-1;
    	}
    	$global:maxTestCount = $global:maxTestCount+1
    	
    	$global:portBase = $($global:portBase + 100)
    }
    Else
    {
        Write-Host "Test suite $testname skipped by UnitTests/OskarTestSuitesBlackList"
    }
    comm
}

Function registerSingleTests()
{
    noteStartAndRepoState

    Write-Host "Registering tests..."
    registerTest -testname "shell_server"
    registerTest -testname "shell_client"
    registerTest -testname "recovery" -index "0" -bucket "4/0"
    registerTest -testname "recovery" -index "1" -bucket "4/1"
    registerTest -testname "recovery" -index "2" -bucket "4/2"
    registerTest -testname "recovery" -index "3" -bucket "4/3"
    registerTest -testname "replication_sync" -weight 2
    registerTest -testname "replication_static" -weight 2
    registerTest -testname "replication_ongoing" -weight 2
    registerTest -testname "http_server"
    registerTest -testname "ssl_server"
    registerTest -testname "shell_server_aql" -index "0" -bucket "5/0"
    registerTest -testname "shell_server_aql" -index "1" -bucket "5/1"
    registerTest -testname "shell_server_aql" -index "2" -bucket "5/2"
    registerTest -testname "shell_server_aql" -index "3" -bucket "5/3"
    registerTest -testname "shell_server_aql" -index "4" -bucket "5/4"
    registerTest -testname "shell_client_aql"
    registerTest -testname "dump"
    registerTest -testname "server_http"
    # registerTest -testname "agency"
    registerTest -testname "shell_replication" -weight 2
    registerTest -testname "http_replication" -weight 2
    registerTest -testname "catch"
    registerTest -testname "version"
    registerTest -testname "endpoints"
    comm
}

Function registerClusterTests()
{
    noteStartAndRepoState
    Write-Host "Registering tests..."
    registerTest -cluster $true -testname "resilience" -index "move" -filter "moving-shards-cluster.js"
    registerTest -cluster $true -testname "resilience" -index "failover" -filter "resilience-synchronous-repl-cluster.js"
    registerTest -cluster $true -testname "shell_client"
    registerTest -cluster $true -testname "shell_server"
    registerTest -cluster $true -testname "http_server"
    registerTest -cluster $true -testname "ssl_server"
    registerTest -cluster $true -testname "resilience" -index "sharddist" -filter "shard-distribution-spec.js"
    registerTest -cluster $true -testname "shell_server_aql" -index "0" -bucket "5/0"
    registerTest -cluster $true -testname "shell_server_aql" -index "1" -bucket "5/1"
    registerTest -cluster $true -testname "shell_server_aql" -index "2" -bucket "5/2"
    registerTest -cluster $true -testname "shell_server_aql" -index "3" -bucket "5/3"
    registerTest -cluster $true -testname "shell_server_aql" -index "4" -bucket "5/4"
    registerTest -cluster $true -testname "shell_client_aql"
    registerTest -cluster $true -testname "dump"
    registerTest -cluster $true -testname "server_http"
    # registerTest -cluster $true -testname "agency"
    comm
}

Function LaunchController($seconds)
{
    $timeSlept = 0;
    $nextLauncheableTest = 0
    $currentScore = 0
    $currentRunning = 1
    While (($seconds -gt 0) -and ($currentRunning -gt 0)) {
        while (($currentScore -lt $global:numberSlots) -and ($nextLauncheableTest -lt $global:maxTestCount)) {
            Write-Host "Launching $nextLauncheableTest '" $global:launcheableTests[$nextLauncheableTest ]['identifier'] "'"
            launchTest $nextLauncheableTest 
            $currentScore = $currentScore+$global:launcheableTests[$nextLauncheableTest ]['weight']
            Start-Sleep 20
            $seconds = $seconds - 20
            $nextLauncheableTest = $nextLauncheableTest+1
        }
        $currentRunning = 0
        $currentRunningNames = @()
        ForEach ($test in $global:launcheableTests) {
            if ($test['pid'] -gt 0) {
                if ($(Get-WmiObject win32_process | Where {$_.ProcessId -eq $test['pid']})) {
                  $currentRunningNames += $test['identifier']
                  $currentRunning = $currentRunning+1
                }
                Else {
                    $currentScore = $currentScore - $test['weight']
                    Write-Host "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ')) Testrun finished: "$test['identifier'] $test['launchdate']
                    $str=$($test | where {($_.Name -ne "commandline")} | Out-String)
                    $test['pid'] = -1
                }
            }
        }
        Start-Sleep 5
        $a = $currentRunningNames -join ","
        Write-Host "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ')) - Waiting  - "$seconds" - Running Tests: "$a
        $seconds = $seconds - 5
    }
    Write-Host "tests done or timeout reached. Current state of worker jobs:"
    $str=$global:launcheableTests | Out-String
    Write-Host $str
    if ($currentRunning -gt 0) {
        Get-WmiObject win32_process | Output-File 
        Write-Host "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH.mm.ssZ')) we have "$currentRunning" tests that timed out! Currently running processes:"
        ForEach ($test in $global:launcheableTests) {
            if ($test['pid'] -gt 0) {
              Write-Host "Testrun timeout:"
              $str=$($test | where {($_.Name -ne "commandline")} | Out-String)
              Write-Host $str
              ForEach ($childProcesses in $(Get-WmiObject win32_process | Where {$_.ParentProcessId -eq $test['pid']})) {
                ForEach ($childChildProcesses in $(Get-WmiObject win32_process | Where {$_.ParentProcessId -eq $test['pid']})) {
                  ForEach ($childChildChildProcesses in $(Get-WmiObject win32_process | Where {$_.ParentProcessId -eq $test['pid']})) {
                    Write-Host "killing child3: "
                    $str=$childChildChildProcesses | Out-String
                    Write-Host $str
                    Stop-Process -Force -Id $childChildChildProcesses.Handle
                  }
                  Write-Host "killing child2: "
                  $str=$childChildProcesses | Out-String
                  Write-Host $str
                  Stop-Process -Force -Id $childChildProcesses.Handle
                }
                Write-Host "killing child: "
                $str=$childProcesses | Out-String
                Write-Host $str

                Stop-Process -Force -Id $childProcesses.Handle
              }
              Stop-Process -Force -Id $test['pid']
            }
        }
        Get-WmiObject win32_process | Output-File 
    }
    comm
}

################################################################################
# report generation
################################################################################

Function showLog
{
    Get-Content "$INNERWORKDIR\test.log" | Out-GridView -Title "$INNERWORKDIR\test.log";comm
}

Function log([array]$log)
{
    ForEach($l in $log)
    {
        Write-Host $l
        $l | Add-Content "$INNERWORKDIR\test.log"
    }
    comm
}

Function createReport
{
    $date = $(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH.mm.ssZ")
    $date | Add-Content "$env:TMP\testProtocol.txt"
    $global:result = "GOOD"
    $global:badtests = $null
    new-item $env:TMP\oskar-junit-report -itemtype directory
    ForEach($dir in (Get-ChildItem -Path $env:TMP  -Directory -Filter "*.out"))
    {
        if ($(Get-ChildItem -filter "*.xml" -path $dir.FullName | Measure-Object | Select -ExpandProperty Count) -gt 0) {
          Copy-Item -Path "$($dir.FullName)\*.xml" $env:TMP\oskar-junit-report
        }
        Write-Host "Looking at directory $($dir.BaseName)"
        If(Test-Path -PathType Leaf -Path "$($dir.FullName)\UNITTEST_RESULT_EXECUTIVE_SUMMARY.json")
            {
                        If(-Not($(Get-Content "$($dir.FullName)\UNITTEST_RESULT_EXECUTIVE_SUMMARY.json") -eq "true"))
                        {
                            $global:result = "BAD"
                            $file = $($dir.BaseName).Substring(0,$($dir.BaseName).Length-4)+".stdout.log"
                            Write-Host "Bad result in $file"
                            "Bad result in $file" | Add-Content "$env:TMP\testProtocol.txt"
                            $global:badtests = $global:badtests + "Bad result in $file`r`n"
                        }   
            }
        Elseif(Test-Path -PathType Leaf -Path "$($dir.FullName)\UNITTEST_RESULT_CRASHED.json")
            {
                        If(-Not($(Get-Content "$($dir.FullName)\UNITTEST_RESULT_CRASHED.json") -eq "false"))
                        {
                            $global:result = "BAD"
                            $file = $($dir.BaseName).Substring(0,$($dir.BaseName).Length-4)+".stdout.log"
                            Write-Host "Crash occured in $file"
                            "Crash occured in $file" | Add-Content "$env:TMP\testProtocol.txt"
                            $global:badtests = $global:badtests + "Crash occured in $file`r`n"
                        }   
            }
        Else
            {
                Write-Host "No Testresult found at directory $($dir.BaseName)"
                $global:result = "BAD"
                "No Testresult found at directory $($dir.BaseName)" | Add-Content "$env:TMP\testProtocol.txt"
                $global:badtests = $global:badtests + "No Testresult found at directory $($dir.BaseName)`r`n"   
            }
    }
    $global:result | Add-Content "$env:TMP\testProtocol.txt"
    If(Get-ChildItem -Path "$env:TMP" -Filter "core_*" -Recurse -ErrorAction SilentlyContinue -Force)
    {
        Write-Host "7zip -Path `"$global:ARANGODIR\build\bin\$BUILDMODE\`" -DestinationPath `"$INNERWORKDIR\crashreport-$date.zip`""
        7zip -Path "$global:ARANGODIR\build\bin\$BUILDMODE\" -DestinationPath "$INNERWORKDIR\crashreport-$date.zip"
        ForEach($core in (Get-ChildItem -Path "$env:TMP" -Filter "core_*" -Recurse -ErrorAction SilentlyContinue))
        {
            Write-Host "7zip -Path $($core.FullName) -DestinationPath `"$INNERWORKDIR\crashreport-$date.zip`""   
            7zip -Path $($core.FullName) -DestinationPath "$INNERWORKDIR\crashreport-$date.zip"
            Write-Host "Remove-Item $($core.FullName)"
            Remove-Item $($core.FullName)
        }
    }
    If(Test-Path -PathType Leaf -Path "$global:ARANGODIR\innerlogs.zip")
    {
        Remove-Item -Force "$global:ARANGODIR\innerlogs.zip"
    }
    Write-Host "7zip -Path `"$env:TMP\`" -DestinationPath `"$global:ARANGODIR\innerlogs.zip`""
    7zip -Path "$env:TMP\" -DestinationPath "$global:ARANGODIR\innerlogs.zip"
    ForEach($log in $(Get-ChildItem -Path $global:ARANGODIR -Filter "*.log"))
    {
        Write-Host "7zip -Path $($log.FullName)  -DestinationPath `"$INNERWORKDIR\testreport-$date.zip`""
        7zip -Path $($log.FullName)  -DestinationPath "$INNERWORKDIR\testreport-$date.zip"
    }
    ForEach($archive in $(Get-ChildItem -Path $global:ARANGODIR -Filter "*.zip"))
    {
        Write-Host "7zip -Path $($archive.FullName) -DestinationPath `"$INNERWORKDIR\testreport-$date.zip`""
        7zip -Path $($archive.FullName) -DestinationPath "$INNERWORKDIR\testreport-$date.zip"
    }
    Write-Host "7zip -Path $env:TMP\testProtocol.txt -DestinationPath `"$INNERWORKDIR\testreport-$date.zip`""
    7zip -Path "$env:TMP\testProtocol.txt" -DestinationPath "$INNERWORKDIR\testreport-$date.zip"

    log "$date $TESTSUITE $global:result M:$MAINTAINER $BUILDMODE E:$ENTERPRISEEDITION $STORAGEENGINE",$global:repoState,$global:repoStateEnterprise,$badtests
    If(Test-Path -PathType Leaf -Path "$INNERWORKDIR\testfailures.log")
    {
        Remove-Item -Force "$INNERWORKDIR\testfailures.log"
    }
    ForEach($file in (Get-ChildItem -Path $env:TMP -Filter "testfailures.txt" -Recurse).FullName)
    {
        Get-Content $file | Add-Content "$INNERWORKDIR\testfailures.log"; comm
    }
}

################################################################################
# test main control
################################################################################

Function runTests
{
    If(Test-Path -PathType Container -Path $env:TMP)
    {
        Remove-Item -Recurse -Force -Path $env:TMP
        New-Item -ItemType Directory -Path $env:TMP
    }
    Else
    {
        New-Item -ItemType Directory -Path $env:TMP
    }
    Push-Location $pwd
    Set-Location $global:ARANGODIR
    ForEach($log in $(Get-ChildItem -Filter "*.log"))
    {
        Remove-Item -Recurse -Force $log 
    }
    Pop-Location

    Switch -Regex ($TESTSUITE)
    {
        "cluster"
        {
            registerClusterTests
            LaunchController 18000
            createReport  
            Break
        }
        "single"
        {
            registerSingleTests
            LaunchController 5400
            createReport
            Break
        }
        "resilience"
        {
            Write-Host "resilience tests currently not implemented"
            $global:result = "BAD"
            Break
        }
        "catchtest"
        {
            registerTest -testname "catch"
            LaunchController 1800
            createReport
            Break
        }
        "*"
        {
            Write-Host "Unknown test suite $TESTSUITE"
            $global:result = "BAD"
            Break
        }
    }

    If($global:result -eq "GOOD")
    {
        Set-Variable -Name "ok" -Value $true -Scope global
    }
    Else
    {
        Set-Variable -Name "ok" -Value $false -Scope global
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
        runTests
    }
}

Function oskar1
{
    showConfig
    buildArangoDB
    if($global:ok)
    {
        oskar
    }
}

Function oskar2
{
    showConfig
    buildArangoDB
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

Function oskar8
{
    showConfig
    enterprise
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

Function makeRelease
{
    maintainerOff
    staticExecutablesOn
    skipPackagingOff
    signPackageOn
    community
    buildArangoDB
    moveResultsToWorkspace
    enterprise
    buildArangoDB
    moveResultsToWorkspace
}
