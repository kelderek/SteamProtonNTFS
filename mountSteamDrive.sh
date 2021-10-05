#!/bin/bash
#Created by Michael Magill
#https://github.com/kelderek/SteamProtonNTFS
#Version 1.0

#*****************Begin configuration*****************

#Set the device name of the Steam game drive and Steam folder.  Remember Linux is case sensitive
#e.g. _STEAMDRIVE=/dev/nvme0n1p5
#e.g. _STEAMFOLDER="Program Files (x86)/Steam"
_STEAMDRIVE=
_STEAMFOLDER=

#******************End configuration******************

#Make sure variables are set
if [ "$_STEAMDRIVE" = "" ] || [ "$_STEAMFOLDER" = "" ]; then
   echo "ERROR: The _STEAMDRIVE and _STEAMFOLDER variables in this script are not set."
   echo "Please edit the script and set them to the correct values for your system."
   exit 100
fi

#Make sure the Steam game drive is available
if [ ! -e "$_STEAMDRIVE" ]; then
   echo "ERROR: Couldn't find $_STEAMDRIVE"
   echo "Please make sure the _STEAMDRIVE variable in the script is set to the correct device and the device is plugged in."
   exit 200
fi

#Unmount the Steam drive if it is already mounted in case it was mounted to a special location.
#NOTE: If the drive was mounted with sudo mount or in /etc/fstab, the user will get prompted
#      for admin rights.  This script is not intended for when the drive is mounted by root.
if [ "$(mount | grep "$_STEAMDRIVE")" != "" ]; then
   echo "WARNING: This script will unmount and remount the drive $_STEAMDRIVE."
   echo "It it is currently mounted at $(mount | grep "$_STEAMDRIVE" | awk '{ print $3 }')"
   echo "Please close any open files open on it, and when you are ready you can"
   read -p "press Enter to continue.  To cancel, press ctrl-c or close the window."
   echo
   udisksctl unmount -b "$_STEAMDRIVE"
fi

#Drive isn't unmounted for whatever reason, so it isn't possible to complete the script
if [ "$(mount | grep "$_STEAMDRIVE")" != "" ]; then
   echo "ERROR: Couldn't unmount $_STEAMDRIVE"
   echo "Please manually unmount the drive and try the script again."
   exit 300
fi

#mount the game drive and get the mounting location
echo "Mounting $_STEAMDRIVE"
udisksctl mount -b "$_STEAMDRIVE"
_MOUNTLOCATION=$(mount | grep "$_STEAMDRIVE" | awk '{ print $3 }')
echo "Mounted $_STEAMDRIVE at $_MOUNTLOCATION"

#Make sure there is a UserMapping file to update
if [ ! -f "$_MOUNTLOCATION/.NTFS-3G/UserMapping" ]; then
   echo "Couldn't find the UserMapping file."
   echo "Please setup an initial NTFS usermapping file per the README.md file."
   exit 400
fi

#Make the compatdata folder and recreate the symlink to it on the Steam drive
echo "Updating the compatdata folder symlink"
mkdir -p ~/.steam/steam/steamapps/compatdata
rm -f "$_MOUNTLOCATION/$_STEAMFOLDER/steamapps/compatdata"
ln -s ~/.steam/steam/steamapps/compatdata "$_MOUNTLOCATION/$_STEAMFOLDER/steamapps/"

#Get the Windows SID of the Steam folder owner
_STEAMOWNER=$(ntfssecaudit "$_STEAMDRIVE/$_STEAMFOLDER" 2> /dev/null | grep "Windows owner" | awk '{ print $3 }')

#Update the NTFS user map file so the Owner of the Steam folder is set to the current user,
#then reset permissions on the updated file because sed leaves it as no access on ntfs for some reason
echo "Updating the NTFS user mapping so the Steam folder gets owned by the current user"
sed -i "s/.*$_STEAMOWNER/$(id -u):$(id -g):$_STEAMOWNER/g" "$_MOUNTLOCATION/.NTFS-3G/UserMapping"
chmod 666 "$_MOUNTLOCATION/.NTFS-3G/UserMapping"

#Wait a second, then remount the drive to get the updated mapping
printf "Waiting a few seconds before unmounting %s" $_STEAMDRIVE
for x in {1..3}; do printf "."; sleep 1; done
printf "\n"

udisksctl unmount -b $_STEAMDRIVE 2> /dev/null
if [ $? -ne 0 ]; then
   printf "Couldn't unmount the drive, it might just be busy.  We'll give it a few more seconds and try again"
   for x in {1..3}; do printf "."; sleep 1; done
   printf "\n"

   udisksctl unmount -b $_STEAMDRIVE
   if [ $? -ne 0 ]; then
      echo "ERROR: Couldn't unmount $_STEAMDRIVE"
      echo "Please manually unmount the drive and remount it to get the updated mapping"
      echo "Unmount command: udisksctl unmount -b $_STEAMDRIVE"
      echo "Remount command: udisksctl mount -b $_STEAMDRIVE"
      exit 800
   fi
fi

udisksctl mount -b $_STEAMDRIVE
if [ $? -ne 0 ]; then
   echo "ERROR: Couldn't remount $_STEAMDRIVE"
   echo "Please manually remount it with the command: udisksctl mount -b $_STEAMDRIVE"
   exit 900
fi

echo
echo "Done!  If you haven't already, add $_MOUNTLOCATION/$_STEAMFOLDER"
echo "as library in the Downloads section of Steam's settings."
