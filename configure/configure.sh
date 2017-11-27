#!/bin/bash

#
#  file: configure.sh
#  project: lulu (configure)
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2017 Objective-See. All rights reserved.
#

#for now, gotta be macOS 10.12+
OSVers="$(sw_vers -productVersion)"
if [ "${OSVers:3:2}" -lt 12 ]; then
    echo "\nERROR: ${OSVers} is currently unsupported"
    echo "LuLu requires macOS 10.12+\n"
    exit -1
fi

#gotta be root
if [ "${EUID}" -ne 0 ]; then
    echo "\nERROR: must be run as root\n"
    exit -1
fi


if [ "${1}" == "-install" ]
then
    echo "installing"

    #move to unzipped directory
    cd "$(dirname "${0}")" || exit -2

    #remove all xattrs
    /usr/bin/xattr -rc ./*

    #main LuLu directory
    mkdir -p /Library/Objective-See/LuLu

    #rules
    chown root:wheel rules.plist
    chmod 700 rules.plist
    mv rules.plist /Library/Objective-See/LuLu/

    #install & load kext
    chown -R root:wheel LuLu.kext
    mv LuLu.kext /Library/Extensions/
    kextload /Library/Extensions/LuLu.kext

    echo "kext installed and loaded"

    #install & load launch daemon
    chown -R root:wheel LuLuDaemon
    chown -R root:wheel com.objective-see.lulu.plist

    mv LuLuDaemon /Library/Objective-See/LuLu/
    mv com.objective-see.lulu.plist /Library/LaunchDaemons/
    launchctl load /Library/LaunchDaemons/com.objective-see.lulu.plist

    echo "launch daemon installed and loaded"

    #install & load main app/helper app
    mv LuLu.app /Applications
    /Applications/LuLu.app/Contents/MacOS/LuLu "-install"

    echo "install complete"

    exit 0

elif [ "${1}" == "-uninstall" ]
then
    echo "uninstalling"

    #unload launch daemon & remove plist
    launchctl unload /Library/LaunchDaemons/com.objective-see.lulu.plist
    rm /Library/LaunchDaemons/com.objective-see.lulu.plist

    echo "unloaded launch daemon"

    #uninstall & remove main app/helper app
    /Applications/LuLu.app/Contents/MacOS/LuLu "-uninstall"
    rm -rf /Applications/LuLu.app

    #delete LuLu's folder
    # contains launch daemon, rules, etc
    rm -rf /Library/Objective-See/LuLu/

    #kill
    killall LuLu 2> /dev/null
    killall com.objective-see.luluHelper 2> /dev/null
    killall "LuLu Helper" 2> /dev/null

    #unload & remove kext
    kextunload -b com.objective-see.lulu
    rm -rf /Library/Extensions/LuLu.kext

    echo "kext unloaded and removed"
    echo "uninstall complete"

    exit 0
fi

#invalid args
echo "\nERROR: run w/ '-install' or '-uninstall'\n"
exit -1
