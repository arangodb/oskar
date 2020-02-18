Import-Module "$PSScriptRoot\lib\Utils.psm1"

################################################################################
# Test control
################################################################################

# EXPECTED_VERSION=3.6.1

function arangodbServiceCheck{
	
#setup loop

$ServiceName = 'arangodb'
$myService = Get-Service -Name $ServiceName

$TimeStart = Get-Date
$TimeEnd = $timeStart.AddSeconds(30)
Write-Host "Start Time: $TimeStart"
write-host "End Time:   $TimeEnd"
write-host 'ArangoDB Current status: ' $myService.status

	Do { 
	$TimeNow = Get-Date
	if ( ($TimeNow -ge $TimeEnd) -or ($myService.Status -eq 'Running') ) {
		Write-host "ArangoDB service is now Running."
		$TimeNow = $TimeNow.AddSeconds(30)

	} else {
		Write-Host "Still working on it..."
		Start-Service $ServiceName
		write-host 'ArangoDB service initiating'
		$myService.Refresh()
	}
	Start-Sleep -Seconds 5
		}
	Until ($TimeNow -ge $TimeEnd)

	#fail check
	if ($myService.Status -ne 'Running') {
		Write-host "ArangoDB service Not available."
	}
}

#random password generator
function randomPass($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}

$password = randomPass -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
Write-Host $password


#calculate the installation directory and generate a random root password for example 'aa' and should be different each time (use timestamp)

function randomPass($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}

$password = randomPass -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
Write-Host $password

$PASSWORD = $password





$installPrefix= "C:\tmp"

$INSTALLER = "C:\ArangoDB3-3.6.1_win64.exe"

$INSTALLATIONFOLDER = "${installPrefix}/PROG"
$DBFOLDER = "${installPrefix}/DB"
$APPFOLDER = "${installPrefix}/APP"
$PASSWORD = $password

echo "${INSTALLER} /PASSWORD=$password /INSTDIR=${INSTALLATIONFOLDER} /DATABASEDIR=${DBFOLDER} /APPDIR=${APPFOLDER} /PATH=0 /S /INSTALL_SCOPE_ALL=1"

& ${INSTALLER} "/PASSWORD=$password" "/INSTDIR=${INSTALLATIONFOLDER}" "/DATABASEDIR=${DBFOLDER}" "/APPDIR=${APPFOLDER}" /PATH=0 /S /INSTALL_SCOPE_ALL=1

#check whether the service is up and running

Start-Service -Name arangoDB

#find the specific service and then check the condition and then apply new cmd
arangodbServiceCheck

#check with Arangosh whether the service version is match with expected version

#stop service and start service

Stop-Service -Name arangoDB

#check with Arangosh whether the service version is match with expected version (2nd time)

runTests
