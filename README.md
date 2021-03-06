# Uninstall Centrify
Bash script for uninstalling Centrify from Macintosh systems and correcting user permissions

Version 1.2

Date: 10/1/2018

Author: Tyler Latimer

## DESCRIPTION:
This script is to remove Centrify from Mac OS X systems in order to upgrade to the newer OS without conflicts.
   
The script begins by unjoining the domain through adleave. If adleave does not work, the uninstall script will unjoin automatically. Once off the domain, the script checks for the version of Centrify and runs the appropriate uninstall.sh file. After uninstalling Centrify, the jamf event trigger "bind" is triggered which joins the system back to the domain. The user files are also transferred over from the Centrify account to the new user account.

## PRECAUTIONS:
The script currently only handles one mobile user account. For systems with more than one mobile user, you will need to gather the UID for each and manually move their files over.

The script checks the length of the hostname of the system. If the name exceeds 15 characters, the domain will not allow the script to join it to the domain. The script is configured to exit and prompt to change the name.

`chown -R "${username}:staff" "/Users/${username}"` is currently being used for transferring user data. This command still needs further testing but seems to work better with this script than `/usr/bin/find / -uid $userID -exec chown $username {} \;`

The script was configured to run on a machine that is connected to the domain. You will need to modify the hostname check to include .local if you wish to run on systems not on a domain.

## KNOWN ISSUES:
You may encounter an issue where adleave unjoins the domain and uninstalls Centrify but is unable to join through JAMF
- Possible Causes:
  - Too many join attempts, name collisions, JAMF policy failing
- What happens:
  - When the script is unable to rejoin the domain, the new mobile accounts will not be created and the user files/permissions will not be transferred. This will continue to cause the user to not be able to log in with AD account.
- How to correct:
  - You can edit the script and comment out the leaveDomain and uninstallCentrify function calls. It is recommended to manually join the domain or run the JAMF policy seperate and ensure the domain is joined before running again. Make sure to comment out the JAMF policy line as well. You can then run the script again and it should move the user files.
    - Edit script, commenting out leaveDomain, uninstallCentrify, and JAMF policy calls as needed
    - Join the domain through JAMF policy or manually adding
    - Run script again
    - Check logs and ensure that user files were transferred appropriately
    - Log out and attempt to log in as AD user and ensure that files are accessible
- OR
  - Manually join the domain and manually run the commands to transfer permissions.
    - Join the domain through JAMF policy or System Preferences
    - Open terminal
    - Run sudo /System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -n <username>
    - Run sudo chown -R <username>:staff /Users/<username>
    - Repeat steps 3 and 4 for each mobile account that needs moved
    - Log out and attempt to log in as AD user and ensure that files are accessible

May encounter access issues after logging in as an AD user
- Possible Causes:
  - Not all file permissions are getting corrected with command
- What happens:
  - You are able to log into the user's account but can't access files within documents or other directories.
- How to correct:
  - Apply permissions to enclosed folders
    - Go to Finder > HDD > Users
    - Right click folder experiencing the issues
    - Click Get Info
    - Unlock Get Info pane in order to access the permissions
    - Click the gear box at the bottom and select 'Apply to enclosed items...'
    - Click Apply if prompted to

## BUG REPORTING:
If you experience any bugs please report them to me at trlatimer95@gmail.com or submit a form through the website itself.
