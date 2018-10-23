#!/bin/bash

#
#  file: configure.sh
#  project: lulu (configure)
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2017 Objective-See. All rights reserved.
#

#where LuLu goes
INSTALL_DIRECTORY="/Library/Objective-See/LuLu"

#OS version check
# only support 10.12+
OSVers="$(sw_vers -productVersion)"
if [ "${OSVers:3:2}" -lt 12 ]; then
    echo "\nERROR: ${OSVers} is currently unsupported"
    echo "LuLu requires macOS 10.12+\n"
    exit -1
fi

#auth check
# gotta be root
if [ "${EUID}" -ne 0 ]; then
    echo "\nERROR: must be run as root\n"
    exit -1
fi

#install logic
if [ "${1}" == "-install" ]; then

    echo "installing"

    #change into dir
    cd "$(dirname "${0}")"

    #remove all xattrs
    xattr -rc ./*

    #create main LuLu directory
    mkdir -p $INSTALL_DIRECTORY

    #install kext
    chown -R root:wheel "LuLu.kext"
    cp -R -f "LuLu.kext" /Library/Extensions/

    echo "kext installed"

    #install launch daemon
    chown -R root:wheel "LuLu.bundle"
    chown -R root:wheel "com.objective-see.lulu.plist"

    cp -R -f "LuLu.bundle" $INSTALL_DIRECTORY
    cp "com.objective-see.lulu.plist" /Library/LaunchDaemons/

    echo "launch daemon installed"

    #install app(s)
    cp -R -f "LuLu.app" /Applications

    #enumerate installed apps
    # note: only do this on a fresh install
    if [ ! -f $INSTALL_DIRECTORY/installedApps.plist ]; then

        echo "enumerating (pre)installed applications"
        /usr/sbin/system_profiler SPApplicationsDataType -xml > $INSTALL_DIRECTORY/installedApps.xml &
    fi

    #rebuild cache, full path
    echo "rebuilding kernel cache"
    /usr/sbin/kextcache -invalidate / &

    echo "install complete"
    exit 0

#uninstall logic
elif [ "${1}" == "-uninstall" ]; then

    echo "uninstalling"

    #change into dir
    cd "$(dirname "${0}")"

    #kill main app
    # ...it might be open
    killall "LuLu" 2> /dev/null

    #unload launch daemon & remove its plist
    launchctl unload "/Library/LaunchDaemons/com.objective-see.lulu.plist"
    rm "/Library/LaunchDaemons/com.objective-see.lulu.plist"

    echo "unloaded launch daemon"

    #remove main app/helper app
    rm -rf "/Applications/LuLu.app"

    #full uninstall?
    # delete LuLu's folder w/ everything
    if [[ "${2}" -eq "1" ]]; then
        rm -rf $INSTALL_DIRECTORY

        #no other Objective-See tools?
        # then delete that directory too
        baseDir=$(dirname $INSTALL_DIRECTORY)

        if [ ! "$(ls -A $baseDir)" ]; then
            rm -rf $baseDir
        fi

    #partial
    # just delete daemon, leaving rules, etc
    else
        rm -rf "$INSTALL_DIRECTORY/LuLu.bundle"
    fi

    #kill
    killall LuLu 2> /dev/null
    killall com.objective-see.lulu.helper 2> /dev/null
    killall "LuLu Helper" 2> /dev/null

    #remove kext
    # note: will be unloaded on reboot
    rm -rf /Library/Extensions/LuLu.kext

    echo "kext removed"

    #rebuild cache, full path
    echo "rebuilding kernel cache"
    /usr/sbin/kextcache -invalidate / &

    echo "uninstall complete"
    exit 0
fi

#invalid args
echo "\nERROR: run w/ '-install' or '-uninstall'"
exit -1
