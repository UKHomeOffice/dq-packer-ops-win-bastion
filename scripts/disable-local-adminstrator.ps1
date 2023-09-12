function Change-groupadmin {
   Add-LocalGroupMember -Group Users -Member "Administrator"  
}
function Disable-Localadmin {   
   Remove–LocalGroupMember -Group Administrators -Member "Administrator"  
}
Change-groupadmin
Disable-Localadmin
