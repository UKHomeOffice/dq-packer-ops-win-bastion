Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v5.4/windows/pgadmin4-5.4-x64.exe"
$output = "C:\tmp\install\pgadmin4-5.4-x64.exe"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $output)
C:\tmp\install\pgadmin4-5.4-x64.exe
