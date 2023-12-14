Start-Transcript -path C:\PerfLogs\userdata_output.log -append

# First work out if host has joined a Domain or is still part of Workgroup
Write-Host "Checking if host joined to a domain, yet"
$is_part_of_domain = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
$workgroup = (Get-WmiObject -Class Win32_ComputerSystem).Workgroup
$is_part_of_workgroup = $workgroup -eq "WORKGROUP"
$is_part_of = ""
$is_part_of_valid = $false

if ($is_part_of_domain -eq $true -and $is_part_of_workgroup -eq $false)
{
    $is_part_of = "DOMAIN"
    $my_domain = Get-ADDomain
    $my_domain_name = $my_domain.Name
    $my_domain_name_full = $my_domain.Forest
    $is_part_of_valid = $true
}
elseif ($is_part_of_workgroup -eq $true -and $is_part_of_domain -eq $false)
{
    $is_part_of = "WORKGROUP"
    $is_part_of_valid=$true
}
elseif ($is_part_of_domain -eq $true -and $is_part_of_workgroup -eq $true)
{
    $is_part_of = "BOTH"
    Write-Host "ERROR! The host appears to be part of a DOMAIN AND a WORKGROUP!"
}
elseif (-not $is_part_of_domain -eq $true -and -not $is_part_of_workgroup -eq $true)
{
    $is_part_of = "NEITHER"
    Write-Host "ERROR! The host appears to be neither part of a DOMAIN NOR part of a WORKGROUP!"
}
else
{
    $is_part_of = "ERROR"
    Write-Host "ERROR! Cannot work out if host is part of a DOMAIN or part of a WORKGROUP!"
}

if ($is_part_of_valid)
{
    Write-Host "Host is part of $is_part_of"
    if ($my_domain_name_full)
    {
        Write-Host "Domain = $my_domain_name_full"
    }
}
else
{
    Write-Host "DEBUG! is_part_of_domain = $is_part_of_domain, is_part_of_workgroup = $is_part_of_workgroup"
}


# Get the IP Address and break it down into managable parts
Write-Host 'Getting IP address of host!'
$my_ip_full = Get-Netipaddress -addressfamily ipv4
$my_ip = $my_ip_full[0].ipaddress
Write-Host "IP address of host = $my_ip"

$octets = $my_ip -split "\."
$subnet_part = $octets[0] + "." + $octets[1]
$host_part = $octets[2] + "." + $octets[3]


# Try to figure out the Environment from the IP address
Write-Host "Deciphering the Environment from subnet part of the IP Address $subnet_part"
if($subnet_part -eq "10.8")
{
    $environment = "NotProd"
}
elseif($subnet_part -eq "10.2")
{
    $environment = "Prod"
}
elseif ($octets[0] -eq "172")
{
    # When Packer is building the Instance (or copying the AMI) the IP address starts 172.
    # No point in trying to do anything clever in this userdata script yet
    $environment = "Building..."
}
else
{
    $environment = "UNKNOWN"
}
$environment_lc = $environment.ToLower()
Write-Host ">>>>>>>>>>> Environment is $environment! <<<<<<<<<<<<<"


# Get current hostname
$current_hostname = $env:computername
Write-Host "The current hostname is $current_hostname"


# Stop if not a valid environment
if ($environment -eq "NotProd" -or $environment -eq "Prod")
{
    Write-Host "The environment is  $environment, continuing to configure computer..."
}
else
{
    Write-Host "As the environment is $environment, not trying set up any more. Exiting..."
    Exit 0
}


# Decipher desired host name
Write-Host "Deciphering the desired name of the host from the host part of the IP Address $host_part !"
if (-not $host_part)
{
    $new_hostname = "UNKNOWN"
}
elseif ($host_part -eq "0.12")
{
    $new_hostname = "WIN-BASTION-1"
}
elseif ($host_part -eq "0.13")
{
    $new_hostname = "WIN-BASTION-2"
}
elseif ($host_part -eq "0.14")
{
    $new_hostname = "WIN-BASTION-3"
}
elseif ($host_part -eq "0.15")
{
    $new_hostname = "WIN-BASTION-4"
}
elseif ($host_part -eq "0.16")
{
    $new_hostname = "WIN-BASTION-5"
}
else
{
    $new_hostname = "WIN-BASTION-" + $octets[3]
}
Write-Host ">>>>>>>>>>> Host should be named $new_hostname <<<<<<<<<<<<<"


# Env vars
Write-Host 'Environment Variables'
$env_flag_file = "\PerfLogs\env.txt"
$env_flag = (Test-Path $env_flag_file)
if (-not $env_flag)
{
    Write-Host 'Setting config bucket environment variable'
    [Environment]::SetEnvironmentVariable("S3_OPS_CONFIG_BUCKET", "s3-dq-ops-config-$environment_lc/sqlworkbench", "Machine")
    [System.Environment]::SetEnvironmentVariable("S3_OPS_CONFIG_BUCKET", "s3-dq-ops-config-$environment_lc/sqlworkbench")
    New-Item -Path $env_flag_file -ItemType "file" -Value "Environment variables set. Remove this file to re-run." | Out-Null
}
else
{
    Write-Host 'Environment variables already set'
}


# Rename Computer
# If the host has not already been renamed
if ($current_hostname -ne $new_hostname)
{
    Write-Host "Renaming host from $current_hostname to $new_hostname - and RESTARTING"
    Rename-Computer -NewName $new_hostname -Force -Restart
    Sleep 600 # To prevent script from continuing before restart takes effect
}
else
{
    Write-Host "Hostname already correct ($current_hostname = $new_hostname)"
}



#  Join to Domain
# If the host has not already joined the domain
if ($is_part_of_domain -eq $false -and $is_part_of_valid -eq $true)
{
    Write-Host 'Join Computer to the DQ domain'
    Write-Host "Retrieving joiner username and password"
    $joiner_usr = (Get-SSMParameter -Name "AD_Domain_Joiner_Username" -WithDecryption $False).Value
    if (!$?)
    {
        Write-Host "Cannot retrieve Domain Joiner Username. Exiting..."
        Exit 1
    }
    $joiner_pwd = (Get-SSMParameter -Name "AD_Domain_Joiner_Password" -WithDecryption $True).Value
    if (!$?)
    {
        Write-Host "Cannot retrieve Domain Joiner Password. Exiting..."
        Exit 1
    }
    Write-Host "Successfully retrieved joiner username ($joiner_usr) and password"
    $domain = 'dq.homeoffice.gov.uk'
    $username = $joiner_usr + "@" + $domain
    $password = ConvertTo-SecureString $joiner_pwd -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username,$password)

    Write-Host "Joining host to Domain $domain using user $username - without rename option - and RESTARTING"
    Add-Computer -DomainName $domain -Credential $credential -Restart -Force
    Sleep 600 # To prevent script from continuing before restart takes effect
}
else
{
    Write-Host "Host already joined to domain"
}


# Tab Dev RDP shortcuts
Write-Host 'Tableau Development RDP Shortcuts'
$rdp_flag_file = "\PerfLogs\rdp.txt"
$rdp_flag = (Test-Path $rdp_flag_file)
if (-not $rdp_flag)
{
    Write-Host 'Adding Tableau Development RDP Shortcuts to Desktop'
    Copy-Item -Path C:\misc\* -Filter *-$environment_lc* -Destination C:\Users\Public\Desktop -Recurse
    if ($?)
    {
        New-Item -Path $rdp_flag_file -ItemType "file" -Value "Tableau Development RDP Shortcuts added to Desktop. Remove this file to re-add." | Out-Null
    }
    else
    {
        Write-Host "Failed to add Tableau Development RDP Shortcuts to Desktop"
    }
}
else
{
    Write-Host 'Tableau Development RDP Shortcuts already added to Desktop'
}


# RDS - Windows Remote Desktop Services
Write-Host 'Windows Remote Desktop Services'
$rds_flag_file = "\PerfLogs\rds.txt"
$rds_flag = (Test-Path $rds_flag_file)
if (-not $rds_flag)
{
    Write-Host 'Installing Windows Remote Desktop Services'
    Install-WindowsFeature -name windows-internal-database -Verbose
    $result1 = $?
    Install-WindowsFeature -Name RDS-RD-Server -Verbose -IncludeAllSubFeature
    $result2 = $?
    Install-WindowsFeature -Name RDS-licensing -Verbose
    $result3 = $?
    Install-WindowsFeature -Name RDS-connection-broker -IncludeAllSubFeature -verbose
    $result4 = $?
    if ($result1 -and $result2 -and $result3 -and $result4)
    {
        New-Item -Path $rds_flag_file -ItemType "file" -Value "Windows Remote Desktop Services installed. Remove this file to re-add." | Out-Null
        Write-Host "Windows Remote Desktop Services installed - RESTARTING"
        Restart-Computer -Force
        # By default the computer will restart in 5 seconds - so sleep while waiting...
        Sleep 600 # To prevent script from continuing before restart takes effect
    }
    else
    {
        Write-Host "Failed to install Windows Remote Desktop Services"
    }
}
else
{
    Write-Host 'Windows Remote Desktop Services already installed'
}


# pgAdmin shortcut
Write-Host 'pgAdmin4 Shortcut'
$pga_flag_file = "\PerfLogs\pga.txt"
$pga_flag = (Test-Path $pga_flag_file)
if (-not $pga_flag)
{
    Write-Host 'Creating pgAdmin4 Shortcut on Desktop'
    $SourceFileLocation = 'C:\Program Files\pgAdmin 4\v6\runtime\pgAdmin4.exe'
    $ShortcutLocation = 'C:\Users\Public\Desktop\pgAdmin4.lnk'
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation)
    $Shortcut.TargetPath = $SourceFileLocation
    $Shortcut.Save()
    Write-Host 'pgAdmin4 Shortcut created! Click on pgAdmin4 Folder to initialize shortcut!'
    if ($?)
    {
        New-Item -Path $pga_flag_file -ItemType "file" -Value "pgAdmin4 shortcut added to Desktop. Remove this file to re-add." | Out-Null
    }
    else
    {
        Write-Host "Failed to add pgAdmin4 shortcut to Desktop"
    }
}
else
{
    Write-Host 'pgAdmin4 shortcut already added to Desktop'
}

# These settings seem a little flaky.
# Check each value each time until all 4 settings are set - then set the flag file to skip this for subsequent runs
Write-Host 'Region and Locale'
$reg_flag_file = "\PerfLogs\reg.txt"
$reg_flag = (Test-Path $reg_flag_file)
if (-not $reg_flag)
{
    Write-Host "Home Location"
    $reg_home_loc = $False
    $home_location = Get-WinHomeLocation
    if ($home_location.GeoId -eq "242")
    {
        Write-Host "Home Location already set to United Kingdom"
        $reg_home_loc = $True # only set to true when confirmed correct via Get (not after Set)
    }
    else
    {
        Write-Host 'Setting home location to the United Kingdom'
        Set-WinHomeLocation 242
    }


    Write-Host 'System Locale'
    $reg_sys_loc = $False
    $sys_loc = Get-WinSystemLocale
    if ($sys_loc.Name -eq "en-GB")
    {
        Write-Host "System Locale already set to British"
        $reg_sys_loc = $True # only set to true when confirmed correct via Get (not after Set)
    }
    else
    {
        Write-Host "Setting System Locale to British"
        Set-WinSystemLocale en-GB
    }


    Write-Host "Region"
    $reg_reg_cult = $False
    $reg_cult = Get-Culture
    if ($reg_cult.Name -eq "en-GB")
    {
        Write-Host "Regional format already set to British"
        $reg_reg_cult = $True # only set to true when confirmed correct via Get (not after Set)
    }
    else
    {
        Write-Host 'Setting regional format (date/time etc.) to British - only applies to current user'
        Set-Culture en-GB
    }


    Write-Host "TimeZone"
    $reg_time_zone = $False
    $time_zone = Get-TimeZone
    if ($time_zone.Id -eq "GMT Standard Time")
    {
        Write-Host "TimeZone already set to GMT"
        $reg_time_zone = $True # only set to true when confirmed correct via Get (not after Set)
    }
    else
    {
        Write-Host 'Setting TimeZone to GMT'
        Set-TimeZone "GMT Standard Time"
    }


    if ($reg_home_loc -and $reg_sys_loc -and $reg_reg_cult -and $reg_time_zone)
    {
        New-Item -Path $reg_flag_file -ItemType "file" -Value "Region and Locale set. Remove this file to re-add." | Out-Null
    }
    else
    {
        Write-Host "Region and Locale not confirmed as set yet"
    }
}
else
{
    Write-Host 'Region and Locale already set'
}

# Enable SMBv2 client - then set the flag file to skip this for subsequent runs
Write-Host 'Enable SMBv2 client'
$smb_flag_file = "\PerfLogs\smb.txt"
$smb_flag = (Test-Path $smb_flag_file)
if (-not $smb_flag)
{
    Write-Host "Get SMB config"
    $smb_config = Get-SmbClientConfiguration
    if ($smb_config.RequireSecuritySignature -eq $true)
    {
        Write-Host "SMBv2 client is enabled"
        New-Item -Path $smb_flag_file -ItemType "file" -Value "SMBv2 client enabled. Remove this file to re-enable." | Out-Null
    }
    else
    {
        Write-Host 'Enabling SMBv2 client'
        Set-SmbClientConfiguration -Force -RequireSecuritySignature $true
    }
}
else
{
    Write-Host 'SMBv2 client already enabled'
}

# Enable Firewall
Write-Host 'Enable Firewall'
$frw_flag_file = "\PerfLogs\frw.txt"
$frw_flag = (Test-Path $frw_flag_file)
if (-not $frw_flag)
{
    Write-Host "Get Firewall config"
    $frw_config = Get-NetFirewallProfile
    if ($frw_config.Length -ne 3) {
        Write-Host "WARNING: Expected 3 profiles, but got" $frw_config.Length
    }
    $frw_all_enabled = $true #check if all firewalls have already been enabled 
    for ($i = 0; $i -lt $frw_config.Length; $i++) {
        if ($frw_config[$i].Enabled -eq $true) {
            Write-Host $frw_config[$i].Name "Firewall is enabled"
        }
        else {
            $frw_all_enabled = $false
            Write-Host "Enabling Firewall for" $frw_config[$i].Name
            Set-NetFirewallProfile -Profile $frw_config[$i].Name -Enabled True
        }
    }
    if ($frw_all_enabled -eq $true) {
        New-Item -Path $frw_flag_file -ItemType "file" -Value "Firewall enabled. Remove this file to re-enable." | Out-Null
    }
}
else
{
    Write-Host 'Firewall already enabled for All'
}

# Enable Firewall logging
Write-Host 'Enable Firewall logging'
$fwl_flag_file = "\PerfLogs\fwl.txt"
$fwl_flag = (Test-Path $fwl_flag_file)
if (-not $fwl_flag)
{
    Write-Host "Get Firewall config for logging"
    $fwl_config = Get-NetFirewallProfile
    if ($fwl_config.Length -ne 3) {
        Write-Host "WARNING: Expected 3 profiles, but got" $fwl_config.Length
    }
        $fwl_all_enabled = $true #check if all firewalls logs have already been enabled 
    for ($i = 0; $i -lt $fwl_config.Length; $i++) {
        if ($fwl_config[$i].Enabled -eq $true -and $fwl_config[$i].LogFileName -eq "%systemroot%\system32\LogFiles\Firewall\firewall.log" -and $fwl_config[$i].LogMaxSizeKilobytes -eq '2000' -and $fwl_config[$i].LogBlocked -eq $true) {
            Write-Host $fwl_config[$i].Name "Firewall logging is enabled"
        }
        else {
            $fwl_all_enabled = $false
            Write-Host "Enabling Firewall logging for" $fwl_config[$i].Name
            Set-NetFireWallProfile -Profile $fwl_config[$i].Name -LogBlocked True -LogMaxSizeKilobytes 20000 -LogFileName %systemroot%\system32\LogFiles\Firewall\firewall.log
        }
    }
    if ($fwl_all_enabled -eq $true) {
        New-Item -Path $fwl_flag_file -ItemType "file" -Value "Firewall logging enabled. Remove this file to re-enable." | Out-Null
    }
}
else
{
    Write-Host 'Firewall logging already enabled for Domain,Private,Public'
}


# Copy symantec client to windows machine from S3
Write-Host 'Symantec client'
$sym_flag_file = "\PerfLogs\sym.txt"
$sym_flag = (Test-Path $sym_flag_file)
if (-not $sym_flag)
{
# Try to figure out the Environment from the IP address
    Write-Host "Deciphering the Environment from subnet part of the IP Address $subnet_part"
    if($subnet_part -eq "10.8"){
        Write-Host "Copying the notprod symantec client from aws"
        aws s3 cp s3://s3-dq-ops-config-notprod/symantec-client/DQ_Win_Servers_WIN64BIT/Symantec_Endpoint_Protection_version_14.3.10148.8000/setup.exe C:\tmp\setup.exe
        Write-Host "Installing notprod symantec client"
        Start-Process "C:\tmp\setup.exe" "powershell" -Verb RunAs -Wait
        New-Item -Path $sym_flag_file -ItemType "file" -Value "Symantec notprod client installed. Remove this file to re-enable." | Out-Null
    }
    elseif($subnet_part -eq "10.2"){
        Write-Host "Copying the prod symantec client from aws"
        aws s3 cp s3://s3-dq-ops-config-prod/symantec-client/DQ_Win_Servers_WIN64BIT/Symantec_Endpoint_Protection_version_14.3.10148.8000/setup.exe C:\tmp\setup.exe
        Write-Host "Installing prod symantec client"
        Start-Process "C:\tmp\setup.exe" "powershell" -Verb RunAs -Wait
        New-Item -Path $sym_flag_file -ItemType "file" -Value "Symantec prod client installed. Remove this file to re-enable." | Out-Null
    }
    else{
        Write-Host "UNKNOWN"
    }
}
else
{
    Write-Host 'Symantec client already present'
}

# Final Restart
# Despite the various restarts in this userdata script,
# it has been found during testing that one final restart is often required to get a newly deployed
# Windows Bastion to successfully connect via RDP to a client.
# Hence we will force a restart now
$rst_flag_file = "\PerfLogs\rst.txt"
$rst_flag = (Test-Path $rst_flag_file)
if (-not $rst_flag)
{
    New-Item -Path $rst_flag_file -ItemType "file" -Value "Final restart triggered. Remove this file to re-trigger." | Out-Null
    Write-Host "Final restart required to get RDP to work - RESTARTING"
    Restart-Computer -Force
    # By default the computer will restart in 5 seconds - so sleep while waiting...
    Sleep 600 # To prevent script from continuing before restart takes effect
}
else
{
    Write-Host "Final restart already triggered once - not restarting again."
}

# Enable file extentions
Write-Host 'Enable file extentions'
$ext_flag_file = "\PerfLogs\ext.txt"
$ext_flag = (Test-Path $ext_flag_file)
if (-not $ext_flag)
{
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $registryPath) {
        Write-Host "Path does exist"
        Push-Location
        Set-Location $registryPath
        Write-Host "Get Item Property config"
        $ext_config = Get-ItemProperty .
        if ($ext_config.HideFileExt -eq 0) {
            Pop-Location
            Write-Host "File extentions is enabled"
            New-Item -Path $ext_flag_file -ItemType "file" -Value "File extentions enabled. Remove this file to re-enable." | Out-Null
        }
        else {
            Write-Host 'Enabling file extentions'
            Set-ItemProperty . HideFileExt "0"
            Pop-Location
            Stop-Process -processName: Explorer -force # This will restart the Explorer service to make this work.
        }
    }
    else {
        Write-Host "Path does not exist"
    }
}
else
{
    Write-Host 'File extentions already enabled'
}

Stop-Transcript
