Start-Transcript -path C:\PerfLogs\userdata_output.log -append

Write-Host 'Getting IP address of host!'
$myip = Get-Netipaddress -addressfamily ipv4

$firstoctate = $myip[0].ipaddress.Substring(0,4)
$secondoctate = $myip[0].ipaddress.Substring(5,4)

Write-Host $firstoctate
Write-Host $secondoctate

Write-Host 'Deciphering the Environment!'
if($firstoctate -eq "10.8")
{
$environment = "notprod"

}

elseif($firstoctate -eq "10.2")
{
$environment = "prod"

}

else {
$environment = "test"

}

Write-Host ">>>>>>>>>>> Environment is $environment! <<<<<<<<<<<<<"

Write-Host 'Deciphering the Bastion!'
if($secondoctate -eq "0.12")
{
$bastion = "WIN-BASTION-1"

}

elseif($secondoctate -eq "0.13")
{
$bastion = "WIN-BASTION-2"

}

elseif($secondoctate -eq "0.14")
{
$bastion = "WIN-BASTION-3"

}

else {
$bastion = "WIN-BASTION-4"

}

Write-Host ">>>>>>>>>>> Host is $bastion <<<<<<<<<<<<<"

Write-Host 'Adding bucket variable'
[Environment]::SetEnvironmentVariable("S3_OPS_CONFIG_BUCKET", "s3-dq-ops-config-$environment/sqlworkbench", "Machine")
[System.Environment]::SetEnvironmentVariable('S3_OPS_CONFIG_BUCKET','s3-dq-ops-config-$environment/sqlworkbench')

Write-Host 'Adding Tableau Development RDP Shortcuts to Desktop'
Copy-Item -Filter *$environment* -Path 'C:\misc\*' -Destination 'C:\Users\Public\Desktop'

Write-Host 'Installing the Windows RDS services'
Install-WindowsFeature -name windows-internal-database -Verbose
Install-WindowsFeature -Name RDS-RD-Server -Verbose -IncludeAllSubFeature
Install-WindowsFeature -Name RDS-licensing -Verbose
Install-WindowsFeature -Name RDS-connection-broker -IncludeAllSubFeature -verbose


Write-Host 'Installing pgAdmin4 and Creating Shortcut to Desktop'
choco install pgadmin4 --version 6.1 -y
Move-Item 'C:\Users\Administrator\AppData\Local\Programs\pgAdmin 4' 'C:\Program Files'
$SourceFileLocation = 'C:\Program Files\pgAdmin 4\v6\runtime\pgAdmin4.exe'
$ShortcutLocation = 'C:\Users\Public\Desktop\pgAdmin4.lnk'
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation)
$Shortcut.TargetPath = $SourceFileLocation
$Shortcut.Save()
Write-Host 'pgAdmin4 Shortcut created! Click on pgAdmin 4 Folder to initialize shortcut!'

Write-Host 'Join System to the DQ domain'
$joiner_pw = (Get-SSMParameter -Name "AD_AdminPasswordd" -WithDecryption $True).Value
$domain = 'dq.homeoffice.gov.uk'
$username = 'dq\domain_joiner'
$password = ConvertTo-SecureString $joiner_pw -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

Rename-Computer -NewName $bastion
sleep 20
Add-Computer -DomainName $domain -Options JoinWithNewName,AccountCreate -Credential $credential -restart -force

Stop-Transcript