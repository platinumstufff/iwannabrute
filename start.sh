#!/bin/bash

script_version="2.0"

mk_bruteforce_ramdisk() {
        device=$1
        version=$2

        echo "Making bruteforce ramdisk..."
        # ramdisk based on meowcat454 and @Ralph0045 work

        boardcfg="$((cat resources/firmware.json) | grep $device -A4 | grep BoardConfig | sed 's/"BoardConfig"//' | sed 's/: "//' | sed 's/",//' | xargs)"
        {
        if [ -z "$version" ]; then
        ipsw_link=$(curl "https://api.ipsw.me/v2.1/$device/earliest/url")
        version=$(curl "https://api.ipsw.me/v2.1/$device/earliest/info.json" | grep version | sed s+'"version": "'++ | sed s+'",'++ | xargs)
        BuildID=$(curl "https://api.ipsw.me/v2.1/$device/earliest/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)
        else
        ipsw_link=$(curl "https://api.ipsw.me/v2.1/$device/$version/url")
        BuildID=$(curl "https://api.ipsw.me/v2.1/$device/$version/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)
        fi
        } &> /dev/null
        iOS_Vers=`echo $version | awk -F. '{print $1}'`

        {
        ## Define RootFS name

        RootFS="$((curl "https://www.theiphonewiki.com/wiki/Firmware_Keys/$iOS_Vers.x") | grep "$BuildID"_"" |  grep $device -m 1| awk -F_ '{print $1}' | awk -F"wiki" '{print "wiki"$2}')"
        } &> /dev/null 

        mkdir -p ramdisks/bruteforce-$device-$version/work

        cd ramdisks/bruteforce-$device-$version/work

        echo "$script_version" > ../version

        ## Get wiki keys page

        echo Downloading firmware keys...

        curl "https://www.theiphonewiki.com/$RootFS"_"$BuildID"_"($device)" -o temp_keys.html &> /dev/null

        if [ -e "temp_keys.html" ]; then
        echo Done!
        else
        echo Failed to download firmware keys
        exit 1
        fi
        ../../../$dir/partialZipBrowser -g BuildManifest.plist $ipsw_link &> /dev/null

        images="iBSS.iBEC.applelogo.DeviceTree.kernelcache.RestoreRamDisk"
        for i in {1..6}
        do
            temp_type="$((echo $images) | awk -v var=$i -F. '{print $var}' | awk '{print tolower($0)}')"
            temp_type2="$((echo $images) | awk -v var=$i -F. '{print $var}')"

        eval "$temp_type"_iv="$((cat temp_keys.html) | grep "$temp_type-iv" | awk -F"</code>" '{print $1}' | awk -F"-iv\"\>" '{print $2}')"
        eval "$temp_type"_key="$((cat temp_keys.html) | grep "$temp_type-key" | awk -F"</code>" '{print $1}' | awk -F"$temp_type-key\"\>" '{print $2}')"
        iv=$temp_type"_iv"
        key=$temp_type"_key"

        if [ "$temp_type2" = "RestoreRamDisk" ]; then
            component="$((cat BuildManifest.plist) | grep -i $boardcfg -A 3000 | grep $temp_type2 -A 100| grep dmg -m 1 | sed s+'<string>'++ | sed s+'</string>'++ | xargs)"
        else
            component="$((cat BuildManifest.plist) | grep -i $boardcfg -A 3000 | grep $temp_type2 | grep string -m 1 | sed s+'<string>'++ | sed s+'</string>'++ | xargs)"
        fi
        
            echo Downloading $component...
        
            ../../../$dir/partialZipBrowser -g $component $ipsw_link &> /dev/null
        
            echo Done!
        
            if [ "$is_64" = "true" ]; then
                if [ "$temp_type2" = "RestoreRamDisk" ]; then
                    ../../../$dir/img4 -i $component -o RestoreRamDisk.raw.dmg ${!iv}${!key}
                        if [ "$iOS_Vers" -gt "11" ]; then
                        echo Downloading $component.trustcache...
                        ../../../$dir/partialZipBrowser -g Firmware/$component.trustcache $ipsw_link &> /dev/null
                        echo Done!
                    fi
            else
                    ../../../$dir/img4 -i $temp_type2* -o $temp_type2.raw ${!iv}${!key}
                fi
            else
        
                if [ "$temp_type2" = "RestoreRamDisk" ]; then
                    echo "decrypting $component"
                    echo "iv=${!iv} key=${!key}"
                    ../../../$dir/xpwntool $component RestoreRamDisk.dec.img3 -iv ${!iv} -k ${!key} -decrypt &> /dev/null
            else
                    echo "decrypting $component"
                    echo "iv=${!iv} key=${!key}"
                    ../../../$dir/xpwntool $temp_type2* $temp_type2.dec.img3 -iv ${!iv} -k ${!key} -decrypt &> /dev/null
                fi
            fi
        done
        echo "Making ramdisk..."
    bootargs="-v amfi=0xff cs_enforcement_disable=1 msgbuf=1048576 wdt=-1"


    if [ "$oscheck" != 'Darwin' ]; then
        echo "linak detektet!!!!"
        echo "pls work"
        ../../../$dir/xpwntool RestoreRamDisk.dec.img3 RestoreRamDisk.raw.dmg
        sleep 1
        echo "1"
        ../../../$dir/hfsplus grow 30000000 RestoreRamDisk.raw.dmg
        echo "2"


        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg mkdir usr/local/bin
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg mkdir usr/bin
        

        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg untar ../../../resources/ssh.tar.gz

        if [ "$iOS_Vers" -gt 7 ]; then
            echo "iOS 8 or later detected, patching restored_external..."
            ../../../$dir/hfsplus RestoreRamDisk.raw.dmg mv /usr/local/bin/restored_external /usr/local/bin/restored_external.real
            ../../../$dir/hfsplus RestoreRamDisk.raw.dmg add ../../../resources/setup.sh /usr/local/bin/restored_external
            ../../../$dir/hfsplus RestoreRamDisk.raw.dmg chmod 755 /usr/local/bin/restored_external
        fi

        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg mv /sbin/reboot /sbin/reboot_bak
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg mv /sbin/halt /sbin/halt_bak

        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg rm /usr/local/bin/restored_external.real
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg add ../../../resources/restored_external /usr/local/bin/restored_external.sshrd
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg chmod 755 /usr/local/bin/restored_external.sshrd
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg add ../../../resources/bruteforce /usr/bin/bruteforce
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg add ../../../resources/device_infos /usr/bin/device_infos
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg chmod 755 /usr/bin/bruteforce
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg chmod 755 /usr/bin/device_infos
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg add ../../../resources/setup.sh /usr/local/bin/restored_external
        ../../../$dir/hfsplus RestoreRamDisk.raw.dmg chmod 755 /usr/local/bin/restored_external

        ../../../$dir/xpwntool RestoreRamDisk.raw.dmg ramdisk.dmg -t RestoreRamDisk.dec.img3
        mv -v ramdisk.dmg ../
        ../../../$dir/xpwntool iBSS.dec.img3 iBSS.raw
        ../../../$dir/iBoot32Patcher iBSS.raw iBSS.patched -r
        cp iBSS.patched ../pwnediBSS
        ../../../$dir/xpwntool iBSS.patched iBSS -t iBSS.dec.img3
        mv -v iBSS ../
        ../../../$dir/xpwntool iBEC.dec.img3 iBEC.raw
        ../../../$dir/iBoot32Patcher iBEC.raw iBEC.patched -r -d -b "rd=md0 $bootargs"
        ../../../$dir/iBoot32Patcher iBEC.raw iBEC_boot.patched -r -d -b "$bootargs"
        ../../../$dir/xpwntool iBEC.patched iBEC -t iBEC.dec.img3
        ../../../$dir/xpwntool iBEC_boot.patched iBEC_boot -t iBEC.dec.img3
        mv -v iBEC ../
        mv -v iBEC_boot ../
        mv -v applelogo.dec.img3 ../applelogo
        mv -v DeviceTree.dec.img3 ../devicetree
        mv -v kernelcache.dec.img3 ../kernelcache
        cd ..
        rm -rf work

        echo "Patching kernel..."

        ../../$dir/aespatched kernelcache kernelcache.dec

        mv kernelcache kernelcache.orig

        ../../$dir/xpwntool kernelcache.dec kernelcache -t kernelcache.orig

        cd ../../
        exit
    else
        ../../../$dir/xpwntool RestoreRamDisk.dec.img3 RestoreRamDisk.raw.dmg
        hdiutil resize -size 30MB RestoreRamDisk.raw.dmg
        mkdir ramdisk_mountpoint
        sudo hdiutil attach -mountpoint ramdisk_mountpoint/ -owners off RestoreRamDisk.raw.dmg
        tar -xvf ../../../resources/ssh.tar.gz -C ramdisk_mountpoint/
        if [ "$iOS_Vers" -gt 7 ]; then
        echo "iOS 8 or later detected, patching restored_external..."
        cp ramdisk_mountpoint/usr/local/bin/restored_external ramdisk_mountpoint/usr/local/bin/restored_external.real
        cp ../../../resources/setup.sh ramdisk_mountpoint/usr/local/bin/restored_external
        chmod +x ramdisk_mountpoint/usr/local/bin/restored_external
        fi
        # Try to stop auto-reboot after around 5 minutes
        
        
        mv ramdisk_mountpoint/sbin/reboot ramdisk_mountpoint/sbin/reboot_bak
        mv ramdisk_mountpoint/sbin/halt ramdisk_mountpoint/sbin/halt_bak
        
        rm -f ramdisk_mountpoint/usr/local/bin/restored_external.real
        cp ../../../resources/restored_external ramdisk_mountpoint/usr/local/bin/restored_external.sshrd
        chmod +x ramdisk_mountpoint/usr/local/bin/restored_external.sshrd
        cp ../../../resources/bruteforce ramdisk_mountpoint/usr/bin/
        cp ../../../resources/device_infos ramdisk_mountpoint/usr/bin/
        chmod +x ramdisk_mountpoint/usr/bin/bruteforce
        chmod +x ramdisk_mountpoint/usr/bin/device_infos

        cp ../../../resources/setup.sh ramdisk_mountpoint/usr/local/bin/restored_external && chmod +x ramdisk_mountpoint/usr/local/bin/restored_external


        hdiutil detach ramdisk_mountpoint
        ../../../$dir/xpwntool RestoreRamDisk.raw.dmg ramdisk.dmg -t RestoreRamDisk.dec.img3
        mv -v ramdisk.dmg ../
        ../../../$dir/xpwntool iBSS.dec.img3 iBSS.raw
        ../../../$dir/iBoot32Patcher iBSS.raw iBSS.patched -r
        cp iBSS.patched ../pwnediBSS
        ../../../$dir/xpwntool iBSS.patched iBSS -t iBSS.dec.img3
        mv -v iBSS ../
        ../../../$dir/xpwntool iBEC.dec.img3 iBEC.raw
        ../../../$dir/iBoot32Patcher iBEC.raw iBEC.patched -r -d -b "rd=md0 $bootargs"
        ../../../$dir/iBoot32Patcher iBEC.raw iBEC_boot.patched -r -d -b "$bootargs"
        ../../../$dir/xpwntool iBEC.patched iBEC -t iBEC.dec.img3
        ../../../$dir/xpwntool iBEC_boot.patched iBEC_boot -t iBEC.dec.img3
        mv -v iBEC ../
        mv -v iBEC_boot ../
        mv -v applelogo.dec.img3 ../applelogo
        mv -v DeviceTree.dec.img3 ../devicetree
        mv -v kernelcache.dec.img3 ../kernelcache
        cd ..
        rm -rf work

        echo "Patching kernel..."

        ../../$dir/aespatched kernelcache kernelcache.dec

        mv kernelcache kernelcache.orig

        ../../$dir/xpwntool kernelcache.dec kernelcache -t kernelcache.orig

        cd ../../
    fi
}

clean() {
    kill $httpserver_pid $iproxy_pid $anisette_pid 2>/dev/null
    popd &>/dev/null
    rm -rf "$(dirname "$0")/tmp$$/"* "$(dirname "$0")/iP"*/ "$(dirname "$0")/tmp$$/" 2>/dev/null
    if [[ $platform == "macos" && $(ls "$(dirname "$0")" | grep -v tmp$$ | grep -c tmp) == 0 &&
          $no_finder != 1 ]]; then
        killall -CONT AMPDevicesAgent AMPDeviceDiscoveryAgent MobileDeviceUpdater
    fi
}

clean_sudo() {
    clean
    sudo rm -rf /tmp/futurerestore /tmp/*.json "$(dirname "$0")/tmp$$/"* "$(dirname "$0")/iP"*/ "$(dirname "$0")/tmp$$/"
    sudo kill $sudoloop_pid
}

clean_usbmuxd() {
    clean_sudo
    if [[ $(ls "$(dirname "$0")" | grep -v tmp$$ | grep -c tmp) != 0 ]]; then
        return
    fi
    sudo killall -9 usbmuxd usbmuxd2 2>/dev/null
    sleep 1
    if [[ $(command -v systemctl) ]]; then
        sudo systemctl restart usbmuxd
    elif [[ $(command -v rc-service) ]]; then
        sudo rc-service usbmuxd start
    fi
}

prepare_udev_rules() {
    local owner="$1"
    local group="$2"
    echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"05ac\", ATTR{idProduct}==\"122[27]|128[0-3]|1338\", OWNER=\"$owner\", GROUP=\"$group\", MODE=\"0660\" TAG+=\"uaccess\"" > 39-libirecovery.rules
}

install_depends() {
    echo "Installing dependencies..."
    rm -f "resources/firstrun"

    if [[ $platform == "linux" ]]; then
        echo "* iwannabrute will be installing dependencies from your distribution's package manager"
        echo "* Enter your user password when prompted"
        if [[ $distro != "debian" && $distro != "fedora-atomic" ]]; then
            echo
            echo "Before continuing, make sure that your system is fully updated first!"
            echo "${color_Y}* This operation can result in a partial upgrade and may cause breakage if your system is not updated${color_N}"
            echo
        fi
        pause
        prepare_udev_rules usbmux plugdev
    fi

    if [[ $distro == "arch" ]]; then
        sudo pacman -Sy --noconfirm --needed base-devel ca-certificates ca-certificates-mozilla curl git ifuse libimobiledevice libxml2 openssh pyenv python udev unzip usbmuxd usbutils vim zenity zip zstd
        prepare_udev_rules root storage

    elif [[ $distro == "debian" ]]; then
        if [[ -n $ubuntu_ver ]]; then
            sudo add-apt-repository -y universe
        fi
        sudo apt update
        sudo apt install -m -y build-essential ca-certificates curl git ifuse libssl3 libssl-dev libxml2 libzstd1 openssh-client patch python3 unzip usbmuxd usbutils xxd zenity zip zlib1g-dev
        if [[ $(command -v systemctl 2>/dev/null) ]]; then
            sudo systemctl enable --now udev systemd-udevd usbmuxd 2>/dev/null
        fi

    elif [[ $distro == "fedora" ]]; then
        sudo dnf install -y ca-certificates git ifuse libimobiledevice libxml2 libzstd openssl openssl-devel patch python3 systemd udev usbmuxd vim-common zenity zip zlib-devel
        sudo dnf group install -y c-development
        sudo ln -sf /etc/pki/tls/certs/ca-bundle.crt /etc/pki/tls/certs/ca-certificates.crt
        prepare_udev_rules root usbmuxd

    elif [[ $distro == "fedora-atomic" ]]; then
        rpm-ostree install patch vim-common zenity
        echo "* You may need to reboot to apply changes with rpm-ostree. Perform a reboot after this before running the script again."

    elif [[ $distro == "opensuse" ]]; then
        sudo zypper -n install ca-certificates curl git ifuse libimobiledevice-1_0-6 libopenssl-3-devel libxml2 libzstd1 openssl-3 patch pyenv python3 usbmuxd unzip vim zenity zip zlib-devel
        sudo zypper -n install -t pattern devel_basis
        prepare_udev_rules usbmux usbmux # idk if this is right

    elif [[ $distro == "gentoo" ]]; then
        sudo emerge -av --noreplace app-arch/zstd app-misc/ca-certificates app-pda/ifuse dev-libs/libxml2 libimobiledevice net-misc/curl openssh python udev unzip usbmuxd usbutils vim zenity zip

    elif [[ $distro == "void" ]]; then
        sudo xbps-install curl git patch openssh python3 unzip xxd zenity zip base-devel libffi-devel bzip2-devel openssl openssl-devel readline readline-devel sqlite-devel xz liblzma-devel zlib zlib-devel

    elif [[ $platform == "macos" ]]; then
        echo "* iwannabrute will be installing dependencies and setting up permissions of tools"
        xattr -cr ../bin/macos
        echo "Installing Xcode Command Line Tools"
        xcode-select --install
        echo "* Make sure to install requirements from Homebrew/MacPorts: https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/How-to-Use"
        pause
    fi

    echo "$platform_ver" > "resources/firstrun"
    if [[ $platform == "linux" && $distro != "fedora-atomic" ]]; then
        # from linux_fix and libirecovery-rules by Cryptiiiic
        if [[ $(command -v systemctl) ]]; then
            sudo systemctl enable --now systemd-udevd usbmuxd 2>/dev/null
        fi
        sudo cp 39-libirecovery.rules /etc/udev/rules.d/39-libirecovery.rules
        sudo chown root:root /etc/udev/rules.d/39-libirecovery.rules
        sudo chmod 0644 /etc/udev/rules.d/39-libirecovery.rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger -s usb
    fi

    echo "Install script done! Please run the script again to proceed"
    echo "If your iOS device is plugged in, unplug and replug your device"
    exit
}

pause() {
    echo "Press Enter/Return to continue (or press Ctrl+C to cancel)"
    read -s
}

set_tool_paths() {
    : '
    sets variables: platform, platform_ver, dir
    also checks architecture (linux) and macos version
    also set distro, debian_ver, ubuntu_ver, fedora_ver variables for linux

    list of tools set here:
    bspatch, jq, scp, ssh, sha1sum (for macos: shasum -a 1), zenity

    these ones "need" sudo for linux arm, not for others:
    futurerestore, gaster, idevicerestore, ipwnder, irecovery

    tools set here will be executed using:
    $name_of_tool

    the rest of the tools not listed here will be executed using:
    "$dir/$name_of_tool"
    '

    if [[ $OSTYPE == "linux"* ]]; then
        source /etc/os-release
        platform="linux"
        platform_ver="$PRETTY_NAME"
        dir="bin/Linux/"

        # architecture check
        if [[ $(uname -m) == "a"* && $(getconf LONG_BIT) == 64 ]]; then
            platform_arch="arm64"
        elif [[ $(uname -m) == "x86_64" ]]; then
            platform_arch="x86_64"
        else
            error "Your architecture ($(uname -m)) is not supported."
        fi
        dir+="$platform_arch"

        # version check
        if [[ -n $UBUNTU_CODENAME ]]; then
            case $UBUNTU_CODENAME in
                "jammy" | "kinetic"   ) ubuntu_ver=22;;
                "lunar" | "mantic"    ) ubuntu_ver=23;;
                "noble" | "oracular"  ) ubuntu_ver=24;;
                "plucky" | "questing" ) ubuntu_ver=25;;
            esac
            if [[ -z $ubuntu_ver ]]; then
                source /etc/upstream-release/lsb-release 2>/dev/null
                ubuntu_ver="$(echo "$DISTRIB_RELEASE" | cut -c -2)"
            fi
            if [[ -z $ubuntu_ver ]]; then
                ubuntu_ver="$(echo "$VERSION_ID" | cut -c -2)"
            fi
        elif [[ -e /etc/debian_version ]]; then
            debian_ver=$(cat /etc/debian_version)
            case $debian_ver in
                *"sid" | "kali"* ) debian_ver="sid";;
                * ) debian_ver="$(echo "$debian_ver" | cut -c -2)";;
            esac
        elif [[ $ID == "fedora" || $ID_LIKE == "fedora" || $ID == "nobara" ]]; then
            fedora_ver=$VERSION_ID
        fi

        platform_arch="$(uname -m)"
        if [[ $platform_arch == "arm64" ]]; then
            dir+="/arm64"
        fi

        # distro check
        if [[ $ID == "arch" || $ID_LIKE == "arch" || $ID == "artix" ]]; then
            distro="arch"
        elif (( ubuntu_ver >= 22 )) || (( debian_ver >= 12 )) || [[ $debian_ver == "sid" ]]; then
            distro="debian"
        elif (( fedora_ver >= 37 )); then
            distro="fedora"
            if [[ $(command -v rpm-ostree) ]]; then
                distro="fedora-atomic"
            fi
        elif [[ $ID == "opensuse-tumbleweed" ]]; then
            distro="opensuse"
        elif [[ $ID == "gentoo" || $ID_LIKE == "gentoo" || $ID == "pentoo" ]]; then
            distro="gentoo"
        elif [[ $ID == "void" ]]; then
            distro="void"
        elif [[ -n $ubuntu_ver || -n $debian_ver || -n $fedora_ver ]]; then
            error "Your distro version ($platform_ver - $platform_arch) is not supported. See the repo README for supported OS versions/distros"
        else
            echo "Your distro ($platform_ver - $platform_arch) is not detected/supported. See the repo README for supported OS versions/distros"
            echo "* You may still continue, but you will need to install required packages and libraries manually as needed."
            sleep 5
            pause
        fi

        # live cd/usb check
        if [[ $(id -u $USER) == 999 || $USER == "liveuser" ]]; then
            live_cdusb=1
            live_cdusb_str="Live session"
             "Linux Live session detected."
            if [[ $(pwd) == "/home"* ]]; then
                df . -h
                if [[ $(lsblk -o label | grep -c "casper-rw") == 1 || $(lsblk -o label | grep -c "persistence") == 1 ]]; then
                    echo "Detected iwannabrute running on persistent storage."
                    live_cdusb_str+=" - Persistent storage"
                else
                    echo "Detected iwannabrute running on temporary storage."
                    echo "* You may run out of space and get errors during the restore process."
                    echo "* Please move iwannabrute to a drive that is NOT used for the live USB."
                    echo "* This may mean using another external HDD/flash drive to store iwannabrute on."
                    echo "* To use one USB drive only, create the live USB using Rufus with Persistent Storage enabled."
                    sleep 5
                    pause
                    live_cdusb_str+=" - Temporary storage"
                fi
            fi
        fi

        # if "/media" is detected in pwd, echo user of possible permission issues
        if [[ $(pwd) == *"/media"* ]]; then
            echo "You might get permission errors like \"Permission denied\" on getting device info."
            echo "* If this is the case, try moving iwannabrute to the Desktop or Documents folder."
        fi

        if [[ -z $device_disable_sudoloop ]]; then
            device_sudoloop=1 # Run some tools as root for device detection if set to 1. (for Linux)
            trap "clean_sudo" EXIT
        fi
        if [[ $(uname -m) == "a"* || $device_sudoloop == 1 || $live_cdusb == 1 ]]; then
            if [[ $live_cdusb != 1 ]]; then
                echo "* Enter your user password when prompted"
            fi
            sudo -v
            (while true; do sudo -v; sleep 60; done) &
            sudoloop_pid=$!
            futurerestore="sudo "
            gaster="sudo "
            idevicerestore="sudo "
            ipwnder="sudo "
            irecovery="sudo "
            irecovery2="sudo "
            irecovery3="sudo "
            if [[ ! -d $dir && $(ls ../bin/Linux) ]]; then
                echo "Running on platform: $platform ($platform_ver - $platform_arch)"
                error "Failed to find bin directory for $platform_arch, found $(ls -x ../bin/Linux) instead." \
                "* Download the \"Linux_$platform_arch\" or \"complete\" version to continue (or do a git clone)"
            fi
            trap "clean_usbmuxd" EXIT
            if [[ $othertmp == 0 ]]; then
                if [[ $(command -v systemctl) ]]; then
                    sudo systemctl stop usbmuxd
                elif [[ $(command -v rc-service) ]]; then
                    sudo rc-service usbmuxd zap
                else
                    sudo killall -9 usbmuxd usbmuxd2 2>/dev/null
                fi
                #sudo killall usbmuxd 2>/dev/null
                #sleep 1
            elif [[ $othertmp != 0 ]]; then
                echo "Detected existing tmp folder(s), there might be other iwannabrute instance(s) running"
                echo "Not running usbmuxd"
            fi
        fi
        gaster+="$dir/gaster"

    elif [[ $(uname -m) == "iP"* ]]; then
        error "Running iwannabrute on iOS is not supported (yet)" "* Supported platforms: Linux, macOS"

    elif [[ $OSTYPE == "darwin"* ]]; then
        platform="macos"
        platform_ver="${1:-$(sw_vers -productVersion)}"
        dir="../bin/macos"



        # macos version check
        mac_majver="${platform_ver:0:2}"
        if [[ $mac_majver == 10 ]]; then
            mac_minver=${platform_ver:3}
            mac_minver=${mac_minver%.*}
            # go here if need to disable os x 10.11 support for now
            if (( mac_minver < 11 )); then
                echo "Your macOS version ($platform_ver - $platform_arch) is not supported. Expect features to not work properly."
                echo "* Supported macOS versions are 10.11 and newer. (10.12 and newer recommended)"
                pause
            fi
            if (( mac_minver <= 11 )); then
                mac_cocoa=1
                if [[ -z $(command -v cocoadialog) ]]; then
                    local error_msg="* You need to install cocoadialog from MacPorts."
                    error_msg+=$'\n* Please read the wiki and install the requirements needed in MacPorts: https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/How-to-Use'
                    error_msg+=$'\n* Also make sure that /opt/local/bin (or /usr/local/bin) is in your $PATH.'
                    error_msg+=$'\n* You may try running this command: export PATH="/opt/local/bin:$PATH"'
                    error "Cannot find cocoadialog, cannot continue." "$error_msg"
                fi
            fi
            if [[ $(command -v curl) == "/usr/bin/curl" ]] && (( mac_minver < 15 )); then
                local error_msg="* You need to install curl from MacPorts."
                error_msg+=$'\n* Please read the wiki and install the requirements needed in MacPorts: https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/How-to-Use'
                error_msg+=$'\n* Also make sure that /opt/local/bin (or /usr/local/bin) is in your $PATH.'
                error_msg+=$'\n* You may try running this command: export PATH="/opt/local/bin:$PATH"'
                error "Outdated curl detected, cannot continue." "$error_msg"
            fi
            case $mac_minver in
                11 ) mac_name="El Capitan";;
                12 ) mac_name="Sierra";;
                13 ) mac_name="High Sierra";;
                14 ) mac_name="Mojave";;
                15 ) mac_name="Catalina";;
            esac
        fi
        case $mac_majver in
            11 ) mac_name="Big Sur";;
            12 ) mac_name="Monterey";;
            13 ) mac_name="Ventura";;
            14 ) mac_name="Sonoma";;
            15 ) mac_name="Sequoia";;
        esac
        if [[ -n $mac_name ]]; then
            platform_ver="$mac_name $platform_ver"
        fi

        bspatch="$(command -v bspatch)"
        cocoadialog="$(command -v cocoadialog)"
        gaster+="../bin/macos/gaster"
        ipwnder32="$dir/ipwnder32"
        PlistBuddy="/usr/libexec/PlistBuddy"
        sha1sum="$(command -v shasum) -a 1"
        tsschecker="../bin/macos/tsschecker"
        zenity="../bin/macos/zenity"
        scp2="/usr/bin/scp"
        ssh2="/usr/bin/ssh"

        # kill macos daemons
        killall -STOP AMPDevicesAgent AMPDeviceDiscoveryAgent MobileDeviceUpdater

    else
        error "Your platform ($OSTYPE) is not supported." "* Supported platforms: Linux, macOS"
    fi
    echo "Running on platform: $platform ($platform_ver - $platform_arch)"
    if [[ ! -d $dir ]]; then
        error "Failed to find bin directory ($dir), cannot continue." \
        "* Re-download iwannabrute from releases (or do a git clone/reset)"
    fi
    if [[ $device_sudoloop == 1 ]]; then
        sudo chmod +x $dir/*
        if [[ $? != 0 ]]; then
            error "Failed to set up execute permissions of binaries, cannot continue. Try to move iwannabrute somewhere else."
        fi
    else
        chmod +x $dir/*
    fi

    futurerestore+="$dir/futurerestore"
    ideviceactivation+="$dir/ideviceactivation"
    idevicediagnostics+="$dir/idevicediagnostics"
    ideviceinfo="$dir/ideviceinfo"
    ideviceinstaller+="$dir/ideviceinstaller"
    idevicerestore+="$dir/idevicerestore"
    ifuse="$(command -v ifuse)"
    ipwnder+="$dir/ipwnder"
    irecovery+="$dir/irecovery"
    jq="$dir/jq"
}

check_ramdisk_cache(){
    ramdisk_path="ramdisks/bruteforce-$deviceid-$ios_version"

    if [ -d "$ramdisk_path" ]; then
        echo "Ramdisk exists, checking ramdisk integrity..."
        if [ -f "$ramdisk_path/iBSS" ] && [ -f "$ramdisk_path/iBEC" ] && [ -f "$ramdisk_path/pwnediBSS" ] && [ -f "$ramdisk_path/kernelcache" ] && [ -f "$ramdisk_path/ramdisk.dmg" ] && [ -f "$ramdisk_path/version" ] && [ -f "$ramdisk_path/pwnediBSS" ]; then
            echo "Ramdisk is alright, checking version..."
            local ramdisk_version=$(cat "$ramdisk_path/version")
            if [[ "$ramdisk_version" == "$script_version" ]]; then
                echo "Ramdisk is up to date. Continuing..."
            else
                echo "Ramdisk is outdated, creating new one."
                mk_bruteforce_ramdisk $deviceid $ios_version
            fi
        else
        echo "Ramdisk is broken, creating new one."
        mk_bruteforce_ramdisk $deviceid $ios_version
        fi
    else
        echo "Ramdisk does not exists. Creating new one..."
        mk_bruteforce_ramdisk $deviceid $ios_version
    fi
}

pwn_device() {
    if [ "$is_fake_device" = true ]; then
        echo "device is fake, exiting"
        exit
    fi
    # check if device in pwndfu already
    if (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null | $dir/irecovery -q 2> /dev/null | grep 'PWND' >> /dev/null); then
        echo "Device already in pwnDFU mode."
        ipwndfu send_ibss
    fi

    #pwndfu code
    case $pwnder in
    a5)
        echo ""
        echo ""
        echo "Detected A5 device."
        echo "You need to have an Arduino and USB Host Shield for checkm8-a5."
        echo "Use LukeZGD fork of checkm8-a5: https://github.com/LukeZGD/checkm8-a5"
        echo "You may also use checkm8-a5 for the Pi Pico: https://www.reddit.com/r/LegacyJailbreak/comments/1djuprf/working_checkm8a5_on_the_raspberry_pi_pico/"
        echo "Pwn device using checkm8-a5 and then connect it."
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null | $dir/irecovery -q 2> /dev/null | grep 'PWND' >> /dev/null); then
            echo "[*] Waiting for device in pwnDFU mode"
        fi
    
        while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null | $dir/irecovery -q 2> /dev/null | grep 'PWND' >> /dev/null ); do
            sleep 1
        done

        echo "Device in pwnDFU mode detected!"
        ipwndfu send_ibss
        ;;
    ipwndfu)
        echo "Using ipwndu for pwning..."
        ipwndfu pwn
        ;;
    ipwnder32)
        echo "Using ipwnder for pwning..."
        ipwnder
        ;;
    *)
        echo "pwnder value is empty. wtf"
        exit 1
        ;;
    esac
}

ipwndfu() {
    local tool_pwned=0
    local python2="$(command -v python2)"
    local pyenv="$(command -v pyenv)"
    local pyenv2="$HOME/.pyenv/versions/2.7.18/bin/python2"

    if [[ -z "$pyenv" && -e "$HOME/.pyenv/bin/pyenv" ]]; then
        pyenv="$HOME/.pyenv/bin/pyenv"
    fi
    if [[ $platform == "macos" ]] && (( mac_majver < 12 )); then
        python2="/usr/bin/python"
        echo "Using macOS system python2"
        echo "* You may also install python2 from pyenv if something is wrong with system python2"
        echo "* Install pyenv by running: curl https://pyenv.run | bash"
        echo "* Install python2 from pyenv by running: pyenv install 2.7.18"
    elif [[ -n "$python2" && $device_sudoloop == 1 ]]; then
        p2_sudo="sudo"
    elif [[ -z "$python2" && ! -e "$pyenv2" ]]; then
        echo "python2 is not installed. Attempting to install python2 before continuing"
        echo "* Install python2 from pyenv by running: pyenv install 2.7.18"
        if [[ -z "$pyenv" ]]; then
            echo "pyenv is not installed. Attempting to install pyenv before continuing"
            echo "* Install pyenv by running: curl https://pyenv.run | bash"
            echo "Installing pyenv"
            curl https://pyenv.run | bash
            pyenv="$HOME/.pyenv/bin/pyenv"
            if [[ ! -e "$pyenv" ]]; then
                echo "Cannot detect pyenv, its installation may have failed." \
                "* Try installing pyenv manually before retrying."
            fi
        fi
        echo "Installing python2 using pyenv"
        echo "* This may take a while, but should not take longer than a few minutes."
        "$pyenv" install 2.7.18
        if [[ ! -e "$pyenv2" ]]; then
            echo "Cannot detect python2 from pyenv, its installation may have failed."
            echo "* Try installing pyenv and/or python2 manually:"
            echo "    pyenv:   > curl https://pyenv.run | bash"
            echo "    python2: > \"$pyenv\" install 2.7.18"
            echo "Cannot detect python2 for ipwndfu, cannot continue."
        fi
    fi
    if [[ -e "$pyenv2" ]]; then
        echo "python2 from pyenv detected, this will be used"
        if [[ $device_sudoloop == 1 ]]; then
            p2_sudo="sudo"
        fi
        python2="$pyenv2"
    fi

    mkdir resources/ipwndfu 2>/dev/null

    local ipwndfu_comm="1d22fd01b0daf52bbcf1ce730022d4212d87f967"
    local ipwndfu_sha1="30f0802078ab6ff83d6b918e13f09a652a96d6dc"
    if [[ ! -s resources/ipwndfu || $(cat resources/ipwndfu/sha1check) != "$ipwndfu_sha1" ]]; then
        rm -rf resources/ipwndfu-*
        download_file https://github.com/LukeZGD/ipwndfu/archive/$ipwndfu_comm.zip ipwndfu.zip $ipwndfu_sha1
        unzip -q ipwndfu.zip -d resources
        rm -rf resources/ipwndfu
        mv resources/ipwndfu-* resources/ipwndfu
        echo "$ipwndfu_sha1" > resources/ipwndfu/sha1check
        rm -rf resources/ipwndfu-*
    fi
    # create a lib symlink in the home directory for macos, needed by ipwndfu/pyusb
    # no need to do this for homebrew x86_64 since /usr/local/lib is being checked along with ~/lib, but lets do the symlink anyway
    if [[ $platform == "macos" ]]; then
        if [[ -e "$HOME/lib" && -e "$HOME/lib.bak" ]]; then
            rm -rf "$HOME/lib"
        elif [[ -e "$HOME/lib" ]]; then
            mv "$HOME/lib" "$HOME/lib.bak"
        fi
        # prioritize macports here since it has longer support
        if [[ -e /opt/local/lib/libusb-1.0.dylib ]]; then
            echo "Detected libusb installed via MacPorts"
            ln -sf /opt/local/lib "$HOME/lib"
        elif [[ -e /opt/homebrew/lib/libusb-1.0.dylib ]]; then
            echo "Detected libusb installed via Homebrew (arm64)"
            ln -sf /opt/homebrew/lib "$HOME/lib"
        elif [[ -e /usr/local/lib/libusb-1.0.dylib ]]; then
            echo "Detected libusb installed via Homebrew (x86_64)"
            ln -sf /usr/local/lib "$HOME/lib"
        else
            echo "No libusb detected. ipwndfu might fail especially on arm64 (Apple Silicon) devices."
        fi
    fi

    pushd resources/ipwndfu >/dev/null

    case $1 in
        "send_ibss" )
            echo "Sending iBSS using ipwndfu..."
            rm pwnediBSS
            cd ../../
            cp ramdisks/bruteforce-$deviceid-$ios_version/pwnediBSS resources/ipwndfu/pwnediBSS
            cd resources/ipwndfu
            $p2_sudo "$python2" ipwndfu -l pwnediBSS
            cd ../../
        ;;

        "pwn" )
            tool_pwndfu="ipwndfu"
            echo "Placing device to pwnDFU Mode using ipwndfu"
            $p2_sudo "$python2" ipwndfu -p
            echo "Sending iBSS using ipwndfu..."
            rm pwnediBSS
            cd ../../
            cp ramdisks/bruteforce-$deviceid-$ios_version/pwnediBSS resources/ipwndfu/pwnediBSS
            cd resources/ipwndfu
            $p2_sudo "$python2" ipwndfu -l pwnediBSS
            cd ../../
        ;;

        "pwn_noibss" )
            tool_pwndfu="ipwndfu"
            echo "Placing device to pwnDFU Mode using ipwndfu"
            $p2_sudo "$python2" ipwndfu -p
        ;;
    esac

}


download_file() {
    # usage: download_file {link} {target location} {sha1}
    local filename="$(basename $2)"
    echo "Downloading $filename..."
    curl -L $1 -o $2
    if [[ ! -s $2 ]]; then
        echo "Downloading $2 failed. Please run the script again"
    fi
    if [[ -z $3 ]]; then
        return
    fi
    local sha1=$($sha1sum $2 | awk '{print $1}')
    if [[ $sha1 != "$3" ]]; then
        echo "Verifying $filename failed. The downloaded file may be corrupted or incomplete. Please run the script again" \
        "* SHA1sum mismatch. Expected $3, got $sha1"
    fi
}

get_device_info() {
    fake_deviceid=""
    for arg in "$@"; do
        case $arg in
            fake-device*)
                fake_deviceid="${arg#*=}"
                ;;
        esac
    done
    if [[ -n "$fake_deviceid" ]]; then
        echo "[*] Using fake device: $fake_deviceid"
        is_fake_device=true
        deviceid="$fake_deviceid"
    else
        if [ "$oscheck" = 'Darwin' ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
                echo "[*] Waiting for device in DFU mode"
            fi
            
            while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
                sleep 1
            done
        else
            if ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); then
                echo "[*] Waiting for device in DFU mode"
            fi
            
            while ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); do
                sleep 1
            done
        fi

        deviceid=$($dir/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
    fi
    case $deviceid in
        "iPhone3,1") device_name="iPhone 4 (GSM)" default_version="7.1.2" pwnder="ipwnder32" ;;
        "iPhone3,2") device_name="iPhone 4 (GSM, Rev A)" default_version="7.1.2" pwnder="ipwnder32" ;;
        "iPhone3,3") device_name="iPhone 4 (CDMA)" default_version="7.1.2" pwnder="ipwnder32";;
        "iPhone4,1") device_name="iPhone 4S" default_version="9.0.2" pwnder="a5";;
        "iPhone5,1") device_name="iPhone 5 (GSM)" default_version="9.0.2" pwnder="ipwndfu";;
        "iPhone5,2") device_name="iPhone 5 (Global)" default_version="9.0.2" pwnder="ipwndfu";;
        "iPhone5,3") device_name="iPhone 5C (GSM)" default_version="9.0.2" pwnder="ipwndfu";;
        "iPhone5,4") device_name="iPhone 5C (Global)" default_version="9.0.2" pwnder="ipwndfu";;
    #   Disabled due iOS 5.1.1 is last version for iPad 1(aes patch needs to be reworked)
    #   "iPad1,1") device_name="iPad 1" default_version="5.1.1" pwnder="ipwnder32";;
        "iPad1,1") echo "iPad 1st support is disabled"; exit;;
        "iPad2,1") device_name="iPad 2 (Wi-Fi)" default_version="9.0.2" pwnder="a5";;
        "iPad2,2") device_name="iPad 2 (GSM)" default_version="9.0.2" pwnder="a5";;
        "iPad2,3") device_name="iPad 2 (CDMA)" default_version="9.0.2" pwnder="a5";;
        "iPad2,4") device_name="iPad 2 (Wi-Fi, Rev A)" default_version="9.0.2" pwnder="a5";;
        "iPad2,5") device_name="iPad mini 1 (Wi-Fi)" default_version="9.0.2" pwnder="a5";;
        "iPad2,6") device_name="iPad mini 1 (GSM)" default_version="9.0.2" pwnder="a5";;
        "iPad2,7") device_name="iPad mini 1 (Global)" default_version="9.0.2" pwnder="a5";;
        "iPad3,1") device_name="iPad 3 (Wi-Fi)" default_version="9.0.2" pwnder="a5";;
        "iPad3,2") device_name="iPad 3 (CDMA)" default_version="9.0.2" pwnder="a5";;
        "iPad3,3") device_name="iPad 3 (GSM)" default_version="9.0.2" pwnder="a5";;
        "iPad3,4") device_name="iPad 4 (Wi-Fi)" default_version="9.0.2" pwnder="ipwndfu";;
        "iPad3,5") device_name="iPad 4 (GSM)" default_version="9.0.2" pwnder="ipwndfu";;
        "iPad3,6") device_name="iPad 4 (Global)" default_version="9.0.2" pwnder="ipwndfu";;
        "iPod4,1") device_name="iPod touch 4" default_version="6.1.6" pwnder="ipwnder32";;
        "iPod5,1") device_name="iPod touch 5" default_version="9.0.2" pwnder="a5";;
        *) device_name="Unsupported device" unsupported=true;;
    esac
    if [[ -z "${unsupported+x}" ]]; then
        echo "Detected $device_name ($deviceid)."
    else
        echo "$deviceid is unsupported, connect supported device and try again"
        exit
    fi
    
}

send_ramdisk() {
    echo "Booting ramdisk..."
    cd ramdisks/bruteforce-$deviceid-$ios_version
    sleep 3
    echo "Sending iBSS..."
    ../../$dir/irecovery -f iBSS

    sleep 1
    echo "Sending iBEC..."
    ../../$dir/irecovery -f iBEC

    sleep 3

    ../../$dir/irecovery -c "bgcolor 0 255 255"

    sleep 1

    echo "Sending device tree..."
    ../../$dir/irecovery -f devicetree
    ../../$dir/irecovery -c devicetree

    sleep 1

    echo "Sending ramdisk..."
    ../../$dir/irecovery -f ramdisk.dmg
    ../../$dir/irecovery -c ramdisk

    sleep 1

    echo "Sending kernelcache..."
    ../../$dir/irecovery -f kernelcache
    echo "Booting device now..."
    ../../$dir/irecovery -c bootx
    echo ""
    echo "Device should show text on screen now."
    echo "After passcode is found please reboot using home + power button."
}

version_check() {
    if [[ $no_version_check == 1 ]]; then
        echo "No version check flag detected, update check is disabled and no support will be provided."
        return
    fi
    pushd .. >/dev/null
    version_update_check
    if [[ -z $version_latest ]]; then
        echo "Failed to check for updates. GitHub may be down or blocked by your network."
    elif [[ $git_hash_latest != "$git_hash" ]]; then
        if [[ -z $version_current ]]; then
            echo "* Latest version:  $version_latest ($git_hash_latest)"
            echo "* Please download/pull the latest version before proceeding."
            version_update
        elif (( $(echo $version_current | cut -c 2- | sed -e 's/\.//g') >= $(echo $version_latest | cut -c 2- | sed -e 's/\.//g') )); then
            echo "Current version is newer/different than remote: $version_latest ($git_hash_latest)"
        else
            echo "* A newer version of iwannabrute is available."
            echo "* Current version: $version_current ($git_hash)"
            echo "* Latest version:  $version_latest ($git_hash_latest)"
            echo "* Please download/pull the latest version before proceeding."
            version_update
        fi
    fi
    popd >/dev/null
}

version_update_check() {
    pushd "$(dirname "$0")/tmp$$" >/dev/null
    if [[ $platform == "macos" && ! -e ./resources/firstrun ]]; then
        xattr -cr ./$dir/Darwin
    fi
    echo "Checking for updates..."
    github_api=$(curl https://api.github.com/repos/platinumstufff/iwannabrute/latest 2>/dev/null)
    version_latest=$(echo "$github_api" | $jq -r '.assets[] | select(.name|test("complete")) | .name' | cut -c 25- | cut -c -9)
    git_hash_latest=$(echo "$github_api" | $jq -r '.assets[] | select(.name|test("git-hash")) | .name' | cut -c 21- | cut -c -7)
    popd >/dev/null
}

version_update() {
    local url
    local req
    select_yesno "Do you want to update now?" 1
    if [[ $? != 1 ]]; then
        echo "User selected N, cannot continue. Exiting."
        exit
    fi
    if [[ -d .git ]]; then
        echo "Running git pull..."
        echo "* If this fails for some reason, run: git reset --hard"
        echo "* To clean more files if needed, run: git clean -df"
        git pull
        pushd "$(dirname "$0")/tmp$$" >/dev/null
        echo "Done! Please run the script again"
        exit
    elif (( $(ls bin | wc -l) > 1 )); then
        req=".assets[] | select (.name|test(\"complete\")) | .browser_download_url"
    elif [[ $platform == "Linux" ]]; then
        req=".assets[] | select (.name|test(\"${platform}_$platform_arch\")) | .browser_download_url"
    else
        req=".assets[] | select (.name|test(\"${platform}\")) | .browser_download_url"
    fi
    pushd "$(dirname "$0")/tmp$$" >/dev/null
    url="$(echo "$github_api" | $jq -r "$req")"
    echo "Downloading: $url"
    curl -L $url -o latest.zip
    if [[ ! -s latest.zip ]]; then
        error "Download failed. Please run the script again"
    fi
    popd >/dev/null
    echo "Updating..."
    cp resources/firstrun tmp$$ 2>/dev/null
    rm -r bin/ LICENSE README.md restore.sh
    if [[ $device_sudoloop == 1 ]]; then
        sudo rm -rf resources/
    fi
    rm -r resources/ saved/ipwndfu/ 2>/dev/null
    unzip -q tmp$$/latest.zip -d .
    cp tmp$$/firstrun resources 2>/dev/null
    pushd "$(dirname "$0")/tmp$$" >/dev/null
    echo "Done! Please run the script again"
    exit
}

select_yesno() {
    local msg="Do you want to continue?"
    if [[ -n $1 ]]; then
        msg="$1"
    fi
    if [[ $2 == 1 ]]; then
        msg+=" (Y/n): "
    else
        msg+=" (y/N): "
    fi
        local opt
        while true; do
            read -p "$(echo "$msg")" opt
            case $opt in
                [NnYy] ) break;;
                "" )
                    # select default if no y/n given
                    if [[ $2 == 1 ]]; then
                        opt='y'
                    else
                        opt='n'
                    fi
                    break
                ;;
            esac
        done
        if [[ $2 == 1 ]]; then # default is "yes" if $2 is set to 1
            [[ $opt == [Nn] ]] && return 0 || return 1
        else                   # default is "no" otherwise
            [[ $opt == [Yy] ]] && return 1 || return 0
        fi
}

main() {
clear

echo "  *****  iWannaBrute  *****  "
echo " - Script by platinumstuff - "
echo ""
echo "* Version: $script_version   "
echo ""
echo ""


if [[ $EUID == 0 && $run_as_root != 1 ]]; then
    echo "Running the script as root is not allowed."
    fi

if [[ ! -d "./resources" ]]; then
    echo "The resources folder cannot be found. Replace resources folder and try again." \
        "* If resources folder is present try removing spaces from path/folder name"
fi

set_tool_paths

if [[ $no_internet_check != 1 ]]; then
    echo "Checking Internet connection..."
    local try=("google.com" "www.apple.com" "208.67.222.222")
    local check
    for i in "${try[@]}"; do
        ping -c1 $i >/dev/null
           check=$?
        if [[ $check == 0 ]]; then
            break
        fi
    done
    if [[ $check != 0 ]]; then
        echo "Please check your Internet connection before proceeding."
    fi
fi


local checks=(curl git patch unzip xxd zip)
local check_fail
for check in "${checks[@]}"; do
    if [[ $debug_mode == 1 ]]; then
        echo "Checking for $check in PATH"
    fi
    if [[ ! $(command -v $check) ]]; then
        echo "$check not found in PATH"
        check_fail=1
    fi
done

if [[ ! -e "./resources/firstrun" || $(cat "./resources/firstrun") != "$platform_ver" || $check_fail == 1 ]]; then
    install_depends
fi

get_device_info "$@"
echo ""
echo "Enter ramdisk version ($default_version is default)"
echo ""
read -p "Version:" ios_version
major="${ios_version%%.*}"
if [ "$major" = "10" ]; then
    echo "For iOS 10.x devices use 9.0.2 ramdisk."
    exit
fi
ios_version="${ios_version:-$default_version}"

echo ""
echo "Checking is Ramdisk exists."
echo ""

check_ramdisk_cache

#mk_bruteforce_ramdisk $deviceid $ios_version

echo ""
echo ""

echo "Pwning and sending a ramdisk..."

pwn_device

send_ramdisk

}


othertmp=$(ls "$(dirname "$0")" | grep -c tmp)

pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

main "$@"
