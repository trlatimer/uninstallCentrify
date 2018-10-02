#!/bin/bash

##########################################################################################################################
#
# Remove Centrify
#
##########################################################################################################################
#
#   Version 1.2
#   Date: 10/1/2018
#
#   Author: Tyler Latimer
#
# DESCRIPTION
#   This script is to remove Centrify from Mac OS X systems in order to upgrade to the newer OS without conflicts.
#   The script begins by unjoining the domain through adleave. If adleave does not work, the uninstall script will unjoin automatically. Once off the domain, the script checks for the version of Centrify and runs the appropriate uninstall.sh file.
#   After uninstalling Centrify, the jamf event trigger "bind" is triggered which joins the system back to the domain.
#   The user files are also transferred over from the Centrify account to the new user account.
#
# PRECAUTIONS
#   The script currently only handles one mobile user account. For systems with more than one mobile user, you will need to gather the UID for each and manually move their files over.
#
#   The script checks the length of the hostname of the system. If the name exceeds 15 characters, the domain will not allow the script to join it to the domain. The script is configured to exit and prompt to change the name.
#
#   `chown -R "${username}:staff" "/Users/${username}"` is currently being used for transferring user data. This command still needs further testing but seems to work better with this script than `/usr/bin/find / -uid $userID -exec chown $username {} \;`
#
#   The script was configured to run on a machine that is connected to the domain. You will need to modify the hostname check to include .local if you wish to run on systems not on a domain.
#
# KNOWN ISSUES
#   You may encounter an issue where adleave unjoins the domain and uninstalls Centrify but is unable to join through JAMF
#       Possible Causes:
#           Too many join attempts, name collisions, JAMF policy failing
#       What happens:
#           When the script is unable to rejoin the domain, the new mobile accounts will not be created and the user files/permissions will not be transferred. This will continue to cause the user to not be able to log in with AD accounts
#       How to correct:
#           You can edit the script and comment out the leaveDomain and uninstallCentrify function calls. It is recommended to manually join the domain or run the JAMF policy seperate and ensure the domain is joined before running again. Make sure to comment out the JAMF policy line as well. You can then run the script again and it should move the user files.
#               1. Edit script, commenting out leaveDomain, uninstallCentrify, and JAMF policy calls as needed
#               2. Join the domain through JAMF policy or manually adding
#               3. Run script again
#               4. Check logs and ensure that user files were transferred appropriately
#               5. Log out and attempt to log in as AD user and ensure that files are accessible
#           OR
#           Manually join the domain and manually run the commands to transfer permissions.
#               1. Join the domain through JAMF policy or System Preferences
#               2. Open terminal
#               3. Run sudo /System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -n <username>
#               4. Run sudo chown -R <username>:staff /Users/<username>
#               5. Repeat steps 3 and 4 for each mobile account that needs moved
#               6. Log out and attempt to log in as AD user and ensure that files are accessible
#
#   May encounter access issues after logging in as an AD user
#       Possible Causes:
#           Not all file permissions are getting corrected with command
#       What happens:
#           You are able to log into the user's account but can't access files within documents or other directories.
#       How to correct:
#           Apply permissions to enclosed folders
#               1. Go to Finder > HDD > Users
#               2. Right click folder experiencing the issues
#               3. Click Get Info
#               4. Unlock Get Info pane in order to access the permissions
#               5. Click the gear box at the bottom and select 'Apply to enclosed items...'
#               6. Click Apply if prompted to
#               
###########################################################################################################################

## For error handling
## set -x
## trap read debug

# Check if hostname qualifies for joining domain
hostname=`hostname`
name=${hostname%.lcsc*}
nameLength=`echo $name | wc -m`

# Obtain mobile user accounts
# Lists directories under /Users and obtains username for each
#listUsers=($(/usr/bin/dscl . list /Users OriginalNodeName | awk '{print $1}' 2>/dev/null))
/bin/echo "Creating array of user accounts..."
listUsers=($(ls -d /Users/* | grep / | sed -e 's/\/Users\///g'))

# Create empty array to fill during loop
mobileUsers=()

# Loop through list of User directories to remove Shared, st3ve, and gromit local accounts
# If you add more local accounts you will need to add it into the statement
# If there is a local account you are unaware of, the script will continue, it will just flag an error in the console that it was unable to create mobile account
for i in "${listUsers[@]}"
do
if [[ $i == Shared || $i == st3ve || $i == gromit ]]; then
    /bin/echo "$i is not an AD mobile account"
else
    /bin/echo "$i is an AD mobile account"
#	Push all other users into the mobileUsers array
    mobileUsers=("${mobileUsers[@]}" "$i")
fi
done

/bin/echo "Mobile users are:"
/bin/echo "${mobileUsers[@]}"


# Obtain version of Centrify
centrifyMajor=`adinfo -v | grep adinfo | cut -c 20`
centrifyMinor=`adinfo -v | grep adinfo | cut -c 22`

##########################################################################################################################
#
# FUNCTIONS
#
##########################################################################################################################

#Leave domain
leaveDomain () {
    adleave -f
    status=$?
    # Check status of leave
    if [ $status == 0 ]; then
        /bin/echo "Successfully left the domain"
    elif [ $status == 1  ]; then
        /bin/echo "Unable to leave domain "
        exit
    fi
}

#Centrify uninstall.sh
uninstallCentrify () {
    # Check for appropriate Centrify uninstall location
    if [ $centrifyMajor -ge 5 ] && [ $centrifyMinor -gt 2 ]; then
	   /bin/echo “Version is above 5.2.4”
	   /usr/local/share/centrifydc/bin/uninstall.sh -n
    elif [ $centrifyMajor -le 5 ] && [ $centrifyMinor -le 2 ]; then
	   /bin/echo “Version is 5.2.4 or older”
	   /usr/share/centrifydc/bin/uninstall.sh -n
    else
        /bin/echo "Unable to determine Centrify version. It is either already uninstalled or an error has occurred. Exiting script now..."
        exit
    fi
    uninstallStatus=$?
    if [ $uninstallStatus == 0 ]; then
	   /bin/echo "Successfully uninstalled Centrify"
    elif [ $uninstallStatus == 1 ]; then
	   /bin/echo "Unable to uninstall Centrify "
    fi
}

#Migrate user files
migrateUser () {
    mobileUsers=$1
    for i in "${listUsers[@]}"
    do
        # Create mobile user account on new domain join
        /System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -n $i
        # Move user files to new mobile account
        chown -R "${i}:staff" "/Users/${i}"
        # /usr/bin/find / -uid $userID -exec chown $username {} \; - possible alternative command
        # Check status of migration
        migrateStatus=$?
        if [ $migrateStatus == 0 ]; then
            /bin/echo "Successfully migrated user files"
        elif [ $migrateStatus == 1 ]; then
            /bin/echo "Unable to migrate user files "
        fi
    done
}

#################################################################################################################
#
# MAIN APPLICATION
#
#################################################################################################################

# Display the system name
/bin/echo "Computer name is" $name
# Display the length of the system name
/bin/echo "Computer's name is" $nameLength "characters long"
# Verify that name length is acceptable for domain
# If name is too long, stop script and log that name needs to be shortened.
if [ $nameLength -gt 15 ]; then
    /bin/echo "Computer name is longer than 15 characters. Please shorten name and try again. Exiting script..."
    exit 1
else
    /bin/echo "Computer name length is acceptable. Continuing script..."
fi

# Unjoin system from domain through adleave (Centrify)
leaveDomain

# Uninstall Centrify
uninstallCentrify

# Rejoin to domain through JAMF policy
jamf policy -event bind

# Move user files to new mobile account
migrateUser "$mobileUsers"

# Exit application
exit