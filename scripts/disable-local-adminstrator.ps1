function Change-groupadmin {
   Get-LocalUser | Where-Object {$_.Name -eq "Administrator"} | Disable-LocalUser
}
Change-groupadmin
