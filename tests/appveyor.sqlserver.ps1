# Imports some assemblies
Write-Output "Importing dbatools"
try {
	Import-Module C:\github\dbatools\dbatools.psd1 -ErrorAction Stop
}
catch {
	Import-Module C:\projects\dbatools\dbatools.psd1
}

# This script spins up two local instances
$sql2008 = "localhost\sql2008r2sp2"
$sql2016 = "localhost\sql2016"

Write-Output "Creating migration & backup directories"
New-Item -Path C:\github -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path C:\temp\migration -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path C:\temp\backups -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

Write-Output "Cloning lab materials"
git clone -q --branch=master https://github.com/sqlcollaborative/appveyor-lab.git C:\github\appveyor-lab

Write-Output "Setting sql2016 Agent to Automatic"
Set-Service -Name 'SQLAgent$sql2016' -StartupType Automatic

$instances = "sql2016", "sql2008r2sp2"

foreach ($instance in $instances) {
	$port = switch ($instance) {
		"sql2008r2sp2" { "1433" }
		"sql2016" { "14333" }
	}
	
	Write-Output "Changing the port on $instance to $port"
	$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
	$uri = "ManagedComputer[@Name='$env:COMPUTERNAME']/ ServerInstance[@Name='$instance']/ServerProtocol[@Name='Tcp']"
	$Tcp = $wmi.GetSmoObject($uri)
	foreach ($ipAddress in $Tcp.IPAddresses) {
		$ipAddress.IPAddressProperties["TcpDynamicPorts"].Value = ""
		$ipAddress.IPAddressProperties["TcpPort"].Value = $port
	}
	$Tcp.Alter()
	
	Write-Output "Starting $instance"
	Start-Service "MSSQL`$$instance"
	
	if ($instance -eq "sql2016") {
		Write-Output "Starting Agent for $instance"
		Start-Service 'SQLAgent$sql2016'
	}
}

Write-Output "Add aliases"
foreach ($basekey in "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer", "HKLM:\SOFTWARE\Microsoft\MSSQLServer") {
	if ((Test-Path $basekey) -eq $false) {
		throw "Base key ($basekey) does not exist. Quitting."
	}
	
	$client = "$basekey\Client"
	
	if ((Test-Path $client) -eq $false) {
		Write-Output "Creating $client key"
		$null = New-Item -Path $client -Force
	}
	
	$connect = "$client\ConnectTo"
	
	if ((Test-Path $connect) -eq $false) {
		Write-Output "Creating $connect key"
		$null = New-Item -Path $connect -Force
	}
	
	if ($basekey -like "*WOW64*") {
		$architecture = "32-bit"
	}
	else {
		$architecture = "64-bit"
	}
	
	Write-Output "Creating/updating alias for $SqlServer for $architecture"
	$null = New-ItemProperty -Path $connect -Name sql2016 -Value "DBMSSOCN,localhost\sql2016" -PropertyType String -Force
	$null = New-ItemProperty -Path $connect -Name sql2008 -Value "DBMSSOCN,localhost" -PropertyType String -Force
	$null = New-ItemProperty -Path $connect -Name sql2008r2 -Value "DBMSSOCN,localhost" -PropertyType String -Force
}

# Add some jobs to the sql2008r2sp2 instance (1433 = default)
foreach ($file in (Get-ChildItem C:\github\appveyor-lab\ola\*.sql)) {
	Write-Output "Executing ola scripts - $file"
	Invoke-DbaSqlCmd -ServerInstance localhost\sql2016 -InputFile $file
}

Invoke-Pester C:\github\dbatools\tests\Restore-DbaDatabase.Tests.ps1