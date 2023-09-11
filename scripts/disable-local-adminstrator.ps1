function Disable-Localadmin {
   Add-LocalGroupMember –Group “Users” -Member “Administrator” 
   Remove–LocalGroupMember –Group “Administrators” -Member “Administrator”   
}
Disable-Localadmin

