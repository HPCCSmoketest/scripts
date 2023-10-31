#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

LOG_FILE=$1

echo "LOG_FILE: $LOG_FILE, pwd: $(pwd), $0 $*"
BASE_DIR=$(dirname $0)

if [ -f $BASE_DIR/timestampLogger.sh ]
then
    echo "Using WriteLog() from the existing timestampLogger.sh"
    . $BASE_DIR/timestampLogger.sh
else
    echo "Define a lightweight WriteLog() function"
    WriteLog()
    {
        msg=$1
        out=$2
        [ -z "$out" ] && out=/dev/null

        echo -e "$msg"
        echo -e "$msg" >> $out 2>&1
    }
fi


if [[ (! -d build) || ( -d build && (! -d build/vcpkg_downloads || ! -d build/vcpkg_installed)) ]]
then
    mkdir -p build
    BASE=$( cat baseBranch.dat )
    BASE_VERSION=${BASE#candidate-}
    BASE_VERSION=${BASE_VERSION%.*}
    [[ "$BASE_VERSION" != "master" ]] && BASE_VERSION=$BASE_VERSION.x
    VCPKG_ARCHIVE=~/vcpkg_downloads-${BASE_VERSION}.zip
    if [[ -f  $VCPKG_ARCHIVE ]]
    then
        WriteLog "extract $VCPKG_ARCHIVE into build directory." "$LOG_FILE"
        pushd build
    	res=$( unzip -u $VCPKG_ARCHIVE 2>&1 )
    	WriteLog "Res: $?" "$LOG_FILE"
    	popd
    else
        WriteLog "The $VCPKG_ARCHIVE not found." "$LOG_FILE"
    fi
    
else
    WriteLog "The VCPKG stuff is already handled." "$LOG_FILE"

fi

