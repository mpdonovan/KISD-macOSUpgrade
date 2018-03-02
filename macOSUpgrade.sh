#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copyright (c) 2018 Jamf.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the Jamf nor the names of its contributors may be
#                 used to endorse or promote products derived from this software without
#                 specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a Self Service policy to ensure specific
# requirements have been met before proceeding with an inplace upgrade of the macOS,
# as well as to address changes Apple has made to the ability to complete macOS upgrades
# silently.
#
# VERSION: v2.5
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.10.5 or later
#           - macOS Installer 10.12.4 or later
#           - Look over the USER VARIABLES and configure as needed.
#
#
# For more information, visit https://github.com/kc9wwh/macOSUpgrade
#
#
# Written by: Joshua Roskos | Professional Services Engineer | Jamf
#
# Created On: January 5th, 2017
# Updated On: January 30th, 2018
# Modified for KISD by Mike Donovan March 1, 2018
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
unattendedInstall(){

jamf policy -event installLoginLog

	/bin/cat <<EOF > /Library/LaunchAgents/se.gu.it.LoginLog.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>se.gu.it.LoginLog</string>
  <key>LimitLoadToSessionType</key>
  <array>
    <string>LoginWindow</string>
  </array>
  <key>ProgramArguments</key>
  <array>
    <string>/Library/PrivilegedHelperTools/LoginLog.app/Contents/MacOS/LoginLog</string>
    <string>-logfile</string>
    <string>"/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

/usr/sbin/chown root:wheel /Library/LaunchAgents/se.gu.it.LoginLog.plist
/bin/chmod 644 /Library/LaunchAgents/se.gu.it.LoginLog.plist

launchctl load -S LoginWindow /Library/LaunchAgents/se.gu.it.LoginLog.plist

}

## Run jamf manage to ensure the device is removed from any software restrictions
jamf manage

# Remove log file if present
file="/Library/Application Support/JAMF/bin/DEP/macOSinPlaceUpgrade.log"
if [ -f "$file" ];then
	echo "Found"
	rm "/Library/Application Support/JAMF/bin/DEP/macOSinPlaceUpgrade.log"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# USER VARIABLES
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

##Enter 0 for Full Screen, 1 for Utility window (screenshots available on GitHub)
userDialog=0

#Specify path to OS installer. Use Parameter 4 in the JSS, or specify here
#Example: /Applications/Install macOS High Sierra.app
OSInstaller="$4"

##Version of OS. Use Parameter 5 in the JSS, or specify here.
#Example: 10.12.5
version="$5"

#Trigger used for download. Use Parameter 6 in the JSS, or specify here.
#This should match a custom trigger for a policy that contains an installer
#Example: download-sierra-install
download_trigger="$6"

#Title of OS
#Example: macOS High Sierra
#macOSname=$(echo "$OSInstaller" |sed 's/^\/Applications\/Install \(.*\)\.app$/\1/')
macOSname="$7"

##Title to be used for userDialog (only applies to Utility Window)
title="$macOSname Upgrade"

##Heading to be used for userDialog
heading="Please wait as we prepare your computer for $macOSname..."

##Title to be used for userDialog
description="
This initial process will take approximately 5-10 minutes.
Once completed your computer will reboot and begin the upgrade. Which may take up to 45 minutes."

#Description to be used prior to downloading the OS installer
dldescription="We need to download $macOSname to your computer, this will \
take several minutes."

##Icon to be used for userDialog
##Default is macOS Installer logo which is included in the staged installer package
#icon="$OSInstaller/Contents/Resources/InstallAssistant.icns"
icon="/Library/Application Support/JAMF/bin/KISDColorsealWithBG.png"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# SYSTEM CHECKS
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "[$(date)]" > "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"

##Get Current User
currentUser=$( stat -f %Su /dev/console )

if [[ ${currentUser} == "root" ]]; then
    userDialog=2
		echo "[$(date +%H:%M:%S)]Current User is root begin unattended upgrade" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
		echo "This process should take approx 20mins before the computer restarts." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
		echo "If the computer has not restarted in 30mins use CMD+Q to quit this screen and restart manually." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
else
		echo "[$(date +%H:%M:%S)]Current User ${currentUser}" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
fi

#Check if ethernet is Active
wiredactive="NO"

wiredservices=$(networksetup -listnetworkserviceorder | grep 'Hardware Port' | grep -e 'Ethernet' -e 'USB-C LAN')

while read line; do
    sdev=$(echo $line | awk -F  "(, )|(: )|[)]" '{print $4}')
		checkActive=$(ifconfig $sdev 2>/dev/null | grep status | cut -d ":" -f2)
		if [ "$checkActive" == " active" ]; then
			wiredactive="YES"
		fi
done <<< "$(echo "$wiredservices")"

if [[ ${wiredactive} == "YES" ]]; then
    netStatus="OK"
    /bin/echo "[$(date +%H:%M:%S)]Network Check: OK - Ethernet Detected" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
else
    netStatus="ERROR"
    /bin/echo "[$(date +%H:%M:%S)]Network Check: ERROR - No Ethernet Detected" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
fi

##Check if device is on battery or ac power
pwrAdapter=$( /usr/bin/pmset -g ps )
if [[ ${pwrAdapter} == *"AC Power"* ]]; then
    pwrStatus="OK"
    /bin/echo "[$(date +%H:%M:%S)]Power Check: OK - AC Power Detected" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
else
    pwrStatus="ERROR"
    /bin/echo "[$(date +%H:%M:%S)]Power Check: ERROR - No AC Power Detected" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
fi

##Check if free space > 15GB
osMinor=$( /usr/bin/sw_vers -productVersion | awk -F. {'print $2'} )
if [[ $osMinor -ge 12 ]]; then
    freeSpace=$( /usr/sbin/diskutil info / | grep "Available Space" | awk '{print $6}' | cut -c 2- )
else
    freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $6}' | cut -c 2- )
fi

if [[ ${freeSpace%.*} -ge 15000000000 ]]; then
    spaceStatus="OK"
    /bin/echo "[$(date +%H:%M:%S)]Disk Check: OK - ${freeSpace%.*} Bytes Free Space Detected" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
else
    spaceStatus="ERROR"
    /bin/echo "[$(date +%H:%M:%S)]Disk Check: ERROR - ${freeSpace%.*} Bytes Free Space Detected" >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
fi

##Check for existing OS installer
if [ -e "$OSInstaller" ]; then
  /bin/echo "$OSInstaller found, checking version." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
  OSVersion=$(/usr/libexec/PlistBuddy -c 'Print :"System Image Info":version' "$OSInstaller/Contents/SharedSupport/InstallInfo.plist")
  /bin/echo "OSVersion is $OSVersion"
  if [ $OSVersion = $version ]; then
    downloadOS="No"
  else
    downloadOS="Yes"
    ##Delete old version.
    /bin/echo "[$(date +%H:%M:%S)]Installer found, but old. Deleting..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
    /bin/rm -rf "$OSInstaller"
  fi
else
  downloadOS="Yes"
fi

##Download OS installer if needed
if [ $downloadOS = "Yes" ]; then
  if [[ ${userDialog} != 2 ]]; then
      /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper \
      -windowType fs -title "" -heading "$title" -description "$dldescription" \
      -icon "$icon" -iconSize 100 &
      jamfHelperPID=$(echo $!)
	else
		unattendedInstall
  fi
  ##Run policy to cache installer
  /bin/echo "[$(date +%H:%M:%S)]Downloading Installer..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
  /usr/local/jamf/bin/jamf policy -event $download_trigger
  if [[ ${userDialog} != 2 ]]; then
		kill ${jamfHelperPID}
	fi

else
	/bin/echo "$macOSname installer with $version was already present, continuing..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
	if [[ ${userDialog} == 2 ]]; then
		unattendedInstall
		/bin/echo "[$(date +%H:%M:%S)]Installer Present continuing..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
	fi
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CREATE FIRST BOOT SCRIPT
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

/bin/mkdir /usr/local/jamfps

/bin/echo "#!/bin/bash
## First Run Script to remove the installer.
## Clean up files
/bin/rm -fdr "$OSInstaller"
/bin/sleep 2
## Update Device Inventory
/usr/local/jamf/bin/jamf recon
touch /var/db/.AppleSetupDone
## Remove LaunchDaemon
/bin/rm -f /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
## Remove Script
/bin/rm -fdr /usr/local/jamfps
exit 0" > /usr/local/jamfps/finishOSInstall.sh

/usr/sbin/chown root:admin /usr/local/jamfps/finishOSInstall.sh
/bin/chmod 755 /usr/local/jamfps/finishOSInstall.sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# LAUNCH DAEMON
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

cat << EOF > /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jamfps.cleanupOSInstall</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>/usr/local/jamfps/finishOSInstall.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

##Set the permission on the file just made.
/usr/sbin/chown root:wheel /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
/bin/chmod 644 /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# LAUNCH AGENT FOR FILEVAULT AUTHENTICATED REBOOTS
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

##Determine Program Argument
if [[ $osMinor -ge 11 ]]; then
    progArgument="osinstallersetupd"
elif [[ $osMinor -eq 10 ]]; then
    progArgument="osinstallersetupplaind"
fi

cat << EOP > /Library/LaunchAgents/com.apple.install.osinstallersetupd.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple.install.osinstallersetupd</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>MachServices</key>
    <dict>
        <key>com.apple.install.osinstallersetupd</key>
        <true/>
    </dict>
    <key>TimeOut</key>
    <integer>Aqua</integer>
    <key>OnDemand</key>
    <true/>
    <key>ProgramArguments</key>
    <array>
        <string>$OSInstaller/Contents/Frameworks/OSInstallerSetup.framework/Resources/$progArgument</string>
    </array>
</dict>
</plist>
EOP

##Set the permission on the file just made.
/usr/sbin/chown root:wheel /Library/LaunchAgents/com.apple.install.osinstallersetupd.plist
/bin/chmod 644 /Library/LaunchAgents/com.apple.install.osinstallersetupd.plist

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# APPLICATION
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

##Caffeinate
/usr/bin/caffeinate -dis &
caffeinatePID=$(echo $!)

if [[ ${pwrStatus} == "OK" ]] && [[ ${spaceStatus} == "OK" ]] && [[ ${netStatus} == "OK" ]]; then
    ##Launch jamfHelper
    if [[ ${userDialog} == 0 ]]; then
        /bin/echo "[$(date +%H:%M:%S)]Launching jamfHelper as FullScreen..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
        /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -title "" -icon "$icon" -heading "$heading" -description "$description" &
        jamfHelperPID=$(echo $!)
    fi
    if [[ ${userDialog} == 1 ]]; then
        /bin/echo "[$(date +%H:%M:%S)]Launching jamfHelper as Utility Window..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
        /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "$title" -icon "$icon" -heading "$heading" -description "$description" -iconSize 100 &
        jamfHelperPID=$(echo $!)
    fi

    if [[ ${userDialog} == 2 ]]; then
			##Unattended unLoad LaunchAgent
			launchctl unload /Library/LaunchAgents/se.gu.it.LoginLog.plist
			rm -f /Library/LaunchAgents/se.gu.it.LoginLog.plist
			/bin/echo "[$(date +%H:%M:%S)]Unloading Unattended LaunchAgent..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
		fi

		if [[ ${userDialog} == 0 ]] || [[ ${userDialog} == 1 ]]; then
			## Attended Begin Upgrade
			/bin/echo "[$(date +%H:%M:%S)]Launching Attended startosinstall..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
			"$OSInstaller/Contents/Resources/startosinstall" --applicationpath "$OSInstaller" --nointeraction --pidtosignal $jamfHelperPID >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log" &
	  else
			##Unattended Begin Upgrade
			/bin/echo "[$(date +%H:%M:%S)]Launching Unattended startosinstall..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"
			"$OSInstaller/Contents/Resources/startosinstall" --applicationpath "$OSInstaller" --nointeraction >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log" &
		fi
    /bin/sleep 3
else
    ## Remove Script
    /bin/rm -f /usr/local/jamfps/finishOSInstall.sh
    /bin/rm -f /Library/LaunchDaemons/com.jamfps.cleanupOSInstall.plist
    /bin/rm -f /Library/LaunchAgents/com.apple.install.osinstallersetupd.plist

		/bin/echo "[$(date +%H:%M:%S)]Launching jamfHelper Dialog (Requirements Not Met)..." >> "/Library/Application Support/JAMF/bin/macOSinPlaceUpgrade.log"

    if [[ ${userDialog} != 2 ]]; then
      /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "$title" -icon "$icon" -heading "Requirements Not Met" -description "We were unable to prepare your computer for $macOSname. Please ensure you are connected to both power and ethernet and that you have at least 15GB of Free Space.

      If you continue to experience this issue, please contact your CTSS." -iconSize 100 -button1 "OK" -defaultButton 1
    fi
fi

##Kill Caffeinate
kill ${caffeinatePID}

exit 0
