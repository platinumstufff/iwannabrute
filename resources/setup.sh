#!/bin/bash
echo "32-bit Bruteforce SSH Ramdisk by meowcat454,AJAIZ and platinumstuff"
echo "--------------------------------"
echo "RAMDISK SETUP: STARTING" > /dev/console

# remount r/w
echo "RAMDISK SETUP: REMOUNTING ROOTFS" > /dev/console
mount -o rw,union,update /

# free space
#rm /usr/local/standalone/firmware/*
#rm /usr/standalone/firmware/*
#mv /sbin/reboot /sbin/reboot_bak

# Fix the auto-boot
echo "RAMDISK SETUP: SETTING AUTOBOOT" > /dev/console
nvram auto-boot=1

# Start SSHD
echo "RAMDISK SETUP: STARTING SSHD" > /dev/console
/sbin/sshd

# Run restored_external
echo "RAMDISK SETUP: COMPLETE" > /dev/console
/usr/local/bin/restored_external.sshrd > /dev/console

echo "Mounting Partitions..." > /dev/console
/bin/mount.sh > /dev/console

echo "Starting bruteforce..." > /dev/console
/usr/bin/bruteforce > /dev/console

echo "Fixing disabled"

cd /mnt2/mobile/Library/Preferences/ > /mnt1/private/etc/antilock.txt
for file in com.apple.springboard.plist.???????; do
    if [ -f "$file" ]; then
        rm "$file"
        echo "Deleted: $file"
    fi
done
mv /mnt2/mobile/Library/Preferences/com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist.bak
rm /mnt2/mobile/Library/Preferences/com.apple.springboard.plist > /dev/null
rm /mnt2/mobile/Library/SpringBoard/LockoutStateJournal.plist > /dev/null
