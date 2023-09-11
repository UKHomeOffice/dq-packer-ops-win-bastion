#Step 1: Add the user Administrator to the Users group 
 
Add-LocalGroupMember –Group “Users” -Member “Administrator” 
 
#Step 2: Remove the user Administrator from the Administrators group: 
 
Remove–LocalGroupMember –Group “Administrators” -Member “Administrator” 
