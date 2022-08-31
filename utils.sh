#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

set -a
PREP_TIME=0
BUILD_TIME=0
PACKAGE_TIME=0
INSTALL_TIME=0
START_TIME=0
TEST_TIME=0
STOP_TIME=0

# To determine the number of CPUs/Cores to build and parallel execution

NUMBER_OF_CPUS=$(( $( grep 'core\|processor' /proc/cpuinfo | awk '{print $3}' | sort -nru | head -1 ) + 1 ))

SPEED_OF_CPUS=$( grep 'cpu MHz' /proc/cpuinfo | awk '{print $4}' | sort -nru | head -1 | cut -d. -f1 )
SPEED_OF_CPUS_UNIT='MHz'

BOGO_MIPS_OF_CPUS=$( grep 'bogomips' /proc/cpuinfo | awk '{printf "%5.0f\n", $3}' | sort -nru | head -1 )

#PARALLEL_QUERIES=$(( $NUMBER_OF_CPUS - 3 ))
PARALLEL_QUERIES=$NUMBER_OF_CPUS
PARALLEL_QUERIES_SETUP=$NUMBER_OF_CPUS


NUMBER_OF_BUILD_THREADS=$NUMBER_OF_CPUS

TOTAL_MEMORY_GB=$(( $(grep 'MemTotal' /proc/meminfo | awk '{print $2}' | sort -nru | head -1) / ( 1024 ** 2 ) ))
AVAILABLE_MEMORY_GB=$(( $(grep 'MemAvailable' /proc/meminfo | awk '{print $2}' | sort -nru | head -1) / ( 1024 ** 2 ) ))

MEMORY_GB=$(( $( free | grep -i "mem" | awk '{ print $2}' )/ ( 1024 ** 2 ) ))
MEMORY_MB=$(( $( free | grep -i "mem" | awk '{ print $2}' )/ 1024 ))
MEMORY=$MEMORY_GB

MEM_CORE_RATIO=$( echo "$MEMORY_GB $NUMBER_OF_CPUS" | awk '{printf "%.3f", $1 / $2 }' )
MEM_CORE_RATIO_UNIT='GB/core'

THOR_SLAVES=4

if [[ -d $TARGET_DIR ]]
then
    WritePlainLog "Remove $TARGET_DIR before build" "$logFile"
    rm -rf $TARGET_DIR
fi



# It would be nice to put some formula here to calculate timeouts based on
# the current environment like number of CPU/core, BOGO mips, mem core ration, disk speed, etc
SETUP_TIMEOUT=120
REGRESSION_TIMEOUT=720
REGRESSION_MAX_ATTEMPT_COUNT=2
THOR_CONNECT_TIMEOUT="-fthorConnectTimeout=36000"
if [[ ${BOGO_MIPS_OF_CPUS} -lt 4500 ]] 
then
    SETUP_TIMEOUT=720
    REGRESSION_TIMEOUT=1200
fi

# Individual timeouts 
#               "testname" "timeout sec"
TEST_1=( "schedule1.ecl" "90" )
TEST_2=( "workflow_9c.ecl" "90" )
TEST_3=( "workflow_contingency_8.ecl" "20" )
TEST_4=( "schedule2.ecl" "150" )
#TEST_5=( "teststdlibrary.ecl" "1500" )

TIMEOUTS=( 
    TEST_1[@] 
    TEST_2[@] 
    TEST_3[@] 
    TEST_4[@]
#    TEST_5[@] 
    )

TARGET=all
#TARGET=hthor

GLOBAL_EXCLUSION="-e 3rdparty"
GLOBAL_EXCLUSION="-e=embedded,3rdparty"
#GLOBAL_EXCLUSION="--ef pipefail.ecl,layouttrans_disabled.ecl -e=embedded,3rdparty"
GLOBAL_EXCLUSION="--ef pipefail.ecl -e=embedded,3rdparty,stress"
PYTHON_PLUGIN=''

# Patch/hack some CMakeLists.txt to enable parallel build for them
ENABLE_CMakeLists_HACK=1

#
#-----------------------------------------------------------
#
# Determine the package manager

IS_NOT_RPM=$( type "rpm" 2>&1 | grep -c "not found" )
PKG_EXT=
PKG_INST_CMD=
PKG_QRY_CMD=
PKG_REM_CMD=

if [[ "$IS_NOT_RPM" -eq 1 ]]
then
    PKG_EXT=".deb"
    PKG_INST_CMD="dpkg -i "
    PKG_QRY_CMD="dpkg -l "
    PKG_REM_CMD="dpkg -r "
else
    PKG_EXT=".rpm"
    PKG_INST_CMD="rpm -i --nodeps "
    PKG_QRY_CMD="rpm -qa "
    PKG_REM_CMD="rpm -e --nodeps "
fi

#
#----------------------------------------------------
#
# Get system info 
#

SYSTEM_ID=$( cat /etc/*-release | egrep -i "^PRETTY_NAME" | cut -d= -f2 | tr -d '"' )
if [[ "${SYSTEM_ID}" == "" ]]
then
    SYSTEM_ID=$( cat /etc/*-release | head -1 )
fi

SYSTEM_ID=${SYSTEM_ID// (*)/}
SYSTEM_ID=${SYSTEM_ID// /_}
SYSTEM_ID=${SYSTEM_ID//./_}

OBT_SYSTEM="Smoketest"
OBT_SYSTEM_ENV="Smoketest"



#
#-----------------------------------------------------------
#

WriteEnvInfo()
{
    logFile=$1
    
    PARENT_COMMAND=$(ps $PPID | tail -n 1 | awk "{print \$6}")
    echo "$PARENT_COMMAND"
    echo "Cores: $NUMBER_OF_CPUS"
    echo "Cores: $NUMBER_OF_CPUS" >> $logFile

    echo "CPU speed: $SPEED_OF_CPUS $SPEED_OF_CPUS_UNIT"
    echo "CPU speed: $SPEED_OF_CPUS $SPEED_OF_CPUS_UNIT" >> $logFile

    echo "CPU Bogo Mips: $BOGO_MIPS_OF_CPUS"
    echo "CPU Bogo Mips: $BOGO_MIPS_OF_CPUS" >> $logFile

    #NUMBER_OF_CPUS=$(( 2 * ${NUMBER_OF_CPUS} ))

    if [[ $NUMBER_OF_CPUS -ge 20 ]]
    then
        PARALLEL_QUERIES=$NUMBER_OF_CPUS #20 
    else
       PARALLEL_QUERIES=$(( $NUMBER_OF_CPUS * 2 / 3 ))
    fi
    
    echo "Parallel queries: $PARALLEL_QUERIES"
    echo "Parallel queries: $PARALLEL_QUERIES" >> $logFile

    if [[ $NUMBER_OF_CPUS -ge 20 ]]
    then
        # We have plenty of cores release the CMake do what it wants
        NUMBER_OF_BUILD_THREADS=
        echo "Build threads: unlimited"
        echo "Build threads: unlimited" >> $logFile
    else
        # Use 50% more threads than the number of CPUs you have
        #NUMBER_OF_BUILD_THREADS=$(( $NUMBER_OF_CPUS * 3 / 2 )) 
        # Use 100% more threads than the number of CPUs you have
        NUMBER_OF_BUILD_THREADS=$(( $NUMBER_OF_CPUS *  2 )) 
        echo "Build threads: $NUMBER_OF_BUILD_THREADS"
        echo "Build threads: $NUMBER_OF_BUILD_THREADS" >> $logFile
    fi

    echo "Total memory: $TOTAL_MEMORY_GB GB"
    echo "Total memory: $TOTAL_MEMORY_GB GB" >> $logFile

    echo "Available memory: $AVAILABLE_MEMORY_GB GB"
    echo "Available memory: $AVAILABLE_MEMORY_GB GB" >> $logFile

    echo "Memory core ratio: $MEM_CORE_RATIO $MEM_CORE_RATIO_UNIT"
    echo "Memory core ratio: $MEM_CORE_RATIO $MEM_CORE_RATIO_UNIT" >> $logFile
    
    echo "Setup timeout: $SETUP_TIMEOUT sec"
    echo "Setup timeout: $SETUP_TIMEOUT sec" >> $logFile

    echo "Regression timeout: $REGRESSION_TIMEOUT sec"
    echo "Regression timeout: $REGRESSION_TIMEOUT sec" >> $logFile

}

ProcessLog()
{
    path=$1
    target=$2
    logFile=$3
    
    # Get the latest file
    inFile=$( find ${path} -name ${target}'.*.log' -type f -print | sort -r | head -n 1 ) 
    if [ -n $inFile ]
    then
        WritePlainLog "inFile: $inFile" "$logFile"
        total=$(cat ${inFile} | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
        passed=$(cat ${inFile} | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
        failed=$(cat ${inFile} | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
        elaps=$(cat ${inFile} | sed -n "s/^Elapsed time: \([0-9].*\)[[:space:]]\(.*\)$/\1/p")
        
        WritePlainLog "PR_ROOT:${PR_ROOT}" "$logFile"
        grep -i passed ${PR_ROOT}/setup.summary 
        [ $? -eq 0 ] && echo -n "," >> ${PR_ROOT}/setup.summary
        echo -n "$2:total:${total} passed:${passed} failed:${failed} elaps:${elaps}" >> ${PR_ROOT}/setup.summary
        WritePlainLog "$2:total:${total} passed:${passed} failed:${failed} elaps:${elaps}" "$logFile"
    
        # Perhaps we need all faulted testcases name too
    else
        WritePlainLog "$target file not found." "$logFile"
    fi
}

CheckResult()
{
    logFile=$1
    #cmd=" egrep '\s[E|e]rror([s]*[\:\s]|\s[0-9]*[^a^o])|ValidationException:|undefined reference|No such file or directory|not found'"
    cmd=" egrep '\s[E|e]rror([s]*[\:\s]|\s[0-9]*[^a^o])|ValidationException:|undefined reference|No such file or directory|CMake Error|Cannot find module'"
    #numberOfError=$( grep '[E|e]rror[\:\s][0-9]*' -c $logFile ) 
    numberOfError=$( eval ${cmd} -c $logFile )
    WritePlainLog "Error(s): ${numberOfError}" "$logFile"
    echo "Error(s): ${numberOfError}" >> ../build.summary
    
    errors=$( eval ${cmd} $logFile )
    WritePlainLog "${errors}" "$logFile"
    echo "${errors}" >> ../build.summary
    #echo "" >> ../build.summary

    CheckCMakeResult "${logFile}"
}
    
CheckCMakeResult()
{
    logFile=$1
    # Check CMake errors
    cmd=" egrep 'Configuring incomplete|CMake Error'"
    numberOfCMakeError=$( eval ${cmd} -c $logFile )
    if [[ $numberOfCMakeError -gt 0 ]]
    then
        # copy CMakeOutput.log and CMakeError.log out of build dir
        if [ -f CMakeFiles/CMakeOutput.log ]
        then
            cp CMakeFiles/CMakeOutput.log ../CMakeOutput-$date.log && echo "CMakeFiles/CMakeOutput.log copied into ../CMakeOutput-$date.log" >> $logFile 2>&1
        fi
        
        if [ -f CMakeFiles/CMakeError.log ]
        then
            cp CMakeFiles/CMakeError.log ../CMakeError-$date.log  && echo "CMakeFiles/CMakeError.log copied into ../CMakeError-$date.log" >> $logFile 2>&1
        fi
    fi
    
    CMAKE_ERROR_START="CMake Error "
    CMAKE_ERROR_END="Installed"
    cmd2=' sed -n "/^$CMAKE_ERROR_START/,/$CMAKE_ERROR_END/ { /^$/d ; p }" '
    cMakeResult=$( eval ${cmd2} $logFile )
    echo "${cMakeResult}"
    echo "${cMakeResult}" >> ../build.summary
}

CheckEclWatchBuildResult()
{
    logFile=$1
    echo "Get ECLWatch build result"
    #cmd2=" egrep -A 7 '\-\- ECL Watch:(.*)Rebuilding'"
    ECLW_START="-- ECL Watch:  Rebuilding"
    ECLW_END="CPack: Create package"
    cmd2=' sed -n "/^$ECLW_START/,/$ECLW_END/ { /^$/d ; p }" '
    eclWatchResult=$( eval ${cmd2} $logFile )
    echo "${eclWatchResult}"
    #echo "${eclWatchResult}" >> $logFile 2>&1
    #echo "${eclWatchResult}" >> ../build.summary
}


SecToTimeStr()
{
    secs=$1
    hours=$(( $secs / 3600 ))
    secs=$(( $secs - $hours * 3600 ))
    mins=$(( $secs / 60 ))
    secs=$(( $secs - $mins * 60 ))
    printf "%02d:%02d:%02d" $hours $mins $secs
}

ReportTimes()
{
    logFile=$1
    actDate=$(date +%Y-%m-%d_%H-%M-%S);
    echo "Finish at: "$actDate >> $logFile
    echo "Finish at: "$actDate
    
    WritePlainLog "time logs started" "$logFile"
    printf "Prep time   : %5d sec (%s)\n" $PREP_TIME "$( SecToTimeStr "$PREP_TIME" )"
    printf "Prep time   : %5d sec (%s)\n" $PREP_TIME "$( SecToTimeStr "$PREP_TIME" )" >> $logFile
    printf "Build time  : %5d sec (%s)\n" $BUILD_TIME "$( SecToTimeStr "$BUILD_TIME" )"
    printf "Build time  : %5d sec (%s)\n" $BUILD_TIME "$( SecToTimeStr "$BUILD_TIME" )" >> $logFile
    printf "Package time: %5d sec (%s)\n" $PACKAGE_TIME "$( SecToTimeStr "$PACKAGE_TIME" )"
    printf "Package time: %5d sec (%s)\n" $PACKAGE_TIME "$( SecToTimeStr "$PACKAGE_TIME" )" >> $logFile
    printf "Install time: %5d sec (%s)\n" $INSTALL_TIME "$( SecToTimeStr "$INSTALL_TIME" )"
    printf "Install time: %5d sec (%s)\n" $INSTALL_TIME "$( SecToTimeStr "$INSTALL_TIME" )" >> $logFile
    printf "Start time  : %5d sec (%s)\n" $START_TIME "$( SecToTimeStr "$START_TIME" )"
    printf "Start time  : %5d sec (%s)\n" $START_TIME "$( SecToTimeStr "$START_TIME" )" >> $logFile
    printf "Test time   : %5d sec (%s)\n" $TEST_TIME "$( SecToTimeStr "$TEST_TIME" )"
    printf "Test time   : %5d sec (%s)\n" $TEST_TIME "$( SecToTimeStr "$TEST_TIME" )" >> $logFile
    printf "Stop time   : %5d sec (%s)\n" $STOP_TIME "$( SecToTimeStr "$STOP_TIME" )"
    printf "Stop time   : %5d sec (%s)\n" $STOP_TIME "$( SecToTimeStr "$STOP_TIME" )" >> $logFile
    
    SUMM_TIME=$(( $PREP_TIME  + $BUILD_TIME + $PACKAGE_TIME + $INSTALL_TIME + $START_TIME + $TEST_TIME + $STOP_TIME ))
    SUMM_TIME_STR="$( SecToTimeStr "$SUMM_TIME" )"
    
    printf "Summary     : %5d sec (%s)\n" $SUMM_TIME $SUMM_TIME_STR
    printf "Summary     : %5d sec (%s)\n" $SUMM_TIME $SUMM_TIME_STR  >> $logFile
    WritePlainLog "time logs end" "$logFile"
}

WritePlainLog()
(
    IFS=$'\n'
    for i in $1
    do
        echo -e "$i"
        if [ "$2." == "." ]
        then
            TIMESTAMP=$( date "+%Y-%m-%d %H:%M:%S")
            echo ${TIMESTAMP}": ERROR: WriteLog() target log file name is empty! ($0)"
        else 
            # Suppress all multiple spaces
            i="$( echo $i | tr -s ' ' )"
            # Replace '\n' with a new line
            i=${i//\\n/$'\n'}
            echo -e "$i" >> $2
        fi
    done
)

UninstallHpcc()
{
    logFile=$1
    
    #if [ $KEEP_FILES -eq 1 ]
    #then
    #    WritePlainLog "Keep files therefore skip HPCC Uninstall" "$logFile"
    #else
        WritePlainLog "We keep the source and build files only" "$logFile"
        WritePlainLog "so, uninstall HPCC..." "$logFile"
        if [ -f /opt/HPCCSystems/sbin/complete-uninstall.sh ]
        then
            # Check '-p' parameter
            purge=$( /opt/HPCCSystems/sbin/complete-uninstall.sh -h | while read l; do [[ "${l}" =~ "-p, " ]] && echo "-p"; done )
            sudo /opt/HPCCSystems/sbin/complete-uninstall.sh $purge 

            WritePlainLog "HPCC Uninstall: OK" "$logFile"
            if [ -f "/etc/HPCCSystems/environment.xml" ]
            then
                WritePlainLog "Remove environment.conf and .xml" "$logFile"
                sudo rm -f '/etc/HPCCSystems/environment.*'
                
                if [ -f "/etc/HPCCSystems/environment.xml" ]
                then
                    WritePlainLog "  Failed." "$logFile"
                else
                    WritePlainLog "  Success." "$logFile"
                fi
            fi
        else
            WritePlainLog "HPCC Uninstall: failed (Missing 'complete-uninstall.sh' file.)" "$logFile"
        fi
    #fi
    
    WritePlainLog "Remove Cassandra leftovers." "$logFile"
    sudo rm -rf /var/lib/cassandra/*
    sudo rm -r /var/log/cassandra
    WritePlainLog "    Done." "$logFile"
    
    WritePlainLog "Remove VCPKG leftovers." "$logFile"
    [ -d ~/.cache/vcpkg/archieves] && rm -rf ~/.cache/vcpkg/archieves
    WritePlainLog "    Done." "$logFile"
}

archiveOldLogs()
{
    logFile=$1
    timestamp=$2
    age=2 # minutes
    
    WritePlainLog "Archive previous test session logs and other files older than $age minutes." "$logFile"
    
    if [[ -z "$timestamp" ]] 
    then
        timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
    fi
    # Move all *.log, *test*.summary, *.diff, *.txt and *.old files into a zip archive.
    # TO-DO check if there any. e.g. for a new PR there is not any file to archive
    find . -maxdepth 1 -mmin +$age -type f -iname '*.log' -o -iname '*test*.summary' -o -iname '*.diff' -o -iname '*.txt' -o -iname '*.old' | egrep -v 'result-|RelWith' | zip -m -u old-logs-${timestamp} -@

}

cleanUpLeftovers()
{
    logFile=$1
    
    query="thor|roxie|d[af][fslu]|ecl[s|c|\s|a][g|c]|sase|esp|topo"
    WritePlainLog "Stop hpcc to remove leftover admin stuff" "$logFile"
    process=$(ps aux | egrep -v "[g]rep" | egrep "${query}" | head -n 1 )

    #WritePlainLog "Process: '${process}'" "$logFile"
    if [ "${process}" != "" ]
    then
        proc=$(echo $process | cut -d' ' -f12)  # Get the process full path
        path=${proc%hpcc*}                      # remove suffix starting with "hpcc"
        
        WritePlainLog "Path: ${path}" "$logFile"
        ${path}hpcc/etc/init.d/hpcc-init stop
        ${path}hpcc/etc/init.d/dafilesrv stop
        
        WritePlainLog "Remove any hpcc owned lock file left" "$logFile"
        find ${path}hpcc/var/lock/HPCCSystems/ -iname '*.lock' -type f -print -exec rm '{}' \;
    
    else
        WritePlainLog "HPCC doesn't run" "$logFile"
    fi
    
    WritePlainLog "Check if any hpcc owned orphan process is running" "$logFile"
    res=$(pgrep -l "${query}" 2>&1 )

    if [ -n "$res" ] 
    then
        WritePlainLog "res:${res}" "$logFile"
        sudo pkill -f -9 "${query}"

        # Give it some time
        sleep 10

        res=$(pgrep -l "${query}" 2>&1 )
        if [ -n "$res" ] 
        then
            WritePlainLog "After pkill res:${res}" "$logFile"
            sudo pkill -f -9 "${query}"
            sleep 10
        else
            WritePlainLog "There is no leftover process" "$logFile"
        fi
    else
        WritePlainLog "There is not leftover process" "$logFile"
    fi
    
    # Check if HPCC Systems is installed
    IS_INSTALLED=$( sudo ${PKG_QRY_CMD} hpccsystems-platform | egrep '[h]pcc' | tr -s ' ' | cut -d$' ' -f2 )
    if [[ "$IS_INSTALLED." != "." ]]
    then
        WritePlainLog "${IS_INSTALLED} is installed, remove" "$logFile"
        res=$( sudo ${PKG_REM_CMD} ${IS_INSTALLED}  >> "$logFile" 2>&1 )
        WritePlainLog "Remove package result:\n${res}" "$logFile"
    else
        WritePlainLog "There is not HPCC package isntalled" "$logFile"
    fi
    
    if [[ -d "/opt/HPCCSystems" ]]
    then
        WritePlainLog "Remove leftover '/opt/HPCCSystems' directory" "$logFile"
        sudo rm -rf /opt/HPCCSystems
    else
        WritePlainLog "There is not leftover /opt/HPCCSystems directory" "$logFile"
    fi

    if [ -d ~/.cache/vcpkg/archieves ]
    then
        WritePlainLog "Remove VCPKG leftovers." "$logFile"
        rm -rf ~/.cache/vcpkg/archieves
    else
        WritePlainLog "There are not VCPKG leftovers." "$logFile"
    fi
   
    WritePlainLog "Done." "$logFile"
}

WriteMilestone()
{
    if [[ $# -eq 2 ]]
    then
        WritePlainLog "Milestone:$1" "$2"
    fi
}


StartCheckDiskSpace()
{
    WritePlainLog "StartCheckDiskSpace()" "$1"
    ./checkDiskSpace.sh 1>&/dev/null &
}

KillCheckDiskSpace()
{
   WritePlainLog "KillCheckDiskSpace()" "$1"
   pids=$( ps ax | grep "[c]heckDiskSpace.sh" | awk '{print $1}' )

    for i in $pids
    do 
        WritePlainLog "kill checkdiskspace.sh with pid: ${i}" "$1"
        kill -9 $i
        sleep 1
    done;

    sleep 1
}

set +a
