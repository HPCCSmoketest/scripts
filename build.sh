#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

clear
pwd=$( pwd )
PR_ROOT=${pwd}
SOURCE_ROOT=${PR_ROOT}/HPCC-Platform
BUILD_TYPE=RelWithDebInfo
#BUILD_TYPE=Debug
COMMON_RTE_DIR=$( dirname $PR_ROOT)/rte
RTE_DIR=$PR_ROOT/rte
RESULT_DIR=${PR_ROOT}/HPCCSystems-regression
TEST_DIR=${SOURCE_ROOT}/testing/regress
ESP_TEST_DIR=${SOURCE_ROOT}/testing/esp/wudetails
TARGET_DIR=""

date=$(date +%Y-%m-%d_%H-%M-%S);
logFile=$PR_ROOT/${BUILD_TYPE}"_Build_"$date".log";

PARALLEL_REGRESSION_TEST=1
hthorTestLogFile=$PR_ROOT/${BUILD_TYPE}"_Regress_Hthor_"$date".log";
HTHOR_PQ=5
unset HTHOR_PID

thorTestLogFile=$PR_ROOT/${BUILD_TYPE}"_Regress_Thor_"$date".log";
THOR_PQ=12
unset THOR_PID

roxieTestLogFile=$PR_ROOT/${BUILD_TYPE}"_Regress_Roxie_"$date".log";
ROXIE_PQ=5
unset ROXIE_PID
resultFile=$PR_ROOT/${BUILD_TYPE}"_result_"$date".log";

HPCC_LOG_ARCHIVE=$PR_ROOT/HPCCSystems-logs-$date
HPCC_CORE_ARCHIVE=$PR_ROOT/HPCCSystems-cores-$date

#
#----------------------------------------------------
#

cp -vf ../utils.sh .
. ./utils.sh

cp -vf ../checkDiskSpace.sh .

#
#----------------------------------------------------
#

# Check it we have enough CPU/Cores to parallel engine execution
# NUMBER_OF_CPUS > (HTHOR_PQ + THOR_PQ + HTHOR_PQ)
# if not then PARALLEL_REGRESSION_TEST=0


# Archive previous session's logs.

WritePlainLog "Sytem ID: ${SYSTEM_ID}" "$logFile"
archiveOldLogs "$logFile" "$date"

cleanUpLeftovers "$logFile" 

#res=$(  exec >> ${logFile} 2>&1 )
#exec > ${logFile} 2>&1
#echo "Res:${res}"
#echo "Res:${res}" >> $logFile 2>&1
#echo "logFile:$logFile"

gcc --version >> $logFile 2>&1


MyEcho ()
{
    param=$1
    WritePlainLog "${param}" "$resultFile"
}

MyExit ()
{
    exitCode=$1
    CheckResult "$logFile"
    CheckEclWatchBuildResult "$logFile"
    WritePlainLog "ReportTimes." "$logFile"
    ReportTimes "$logFile"
    
    exit $exitCode
    
}

WaitThenKillProcess()
{
    WritePlainLog "WaitThenKillProcess() Process name: '$1', timeout: '$2'." "$logFile"
    [[ -z "$1" ]] && return || PROCESS_NAME=$1
    [[ -z "$2" ]] && TIMEOUT=30 || TIMEOUT=$2
    [[ -z "$3" ]] && LOOPCOUNT=1 || LOOPCOUNT=$3
    WritePlainLog "WaitThenKillProcess() timeout: '${TIMEOUT}', loop count : ${LOOPCOUNT}." "$logFile"
    
    while true
    do
        LOOPCOUNT=$((  ${LOOPCOUNT} - 1 ))
        pids=$( pgrep  -f ${PROCESS_NAME} )
        
        if [[ -n "${pids}" ]]
        then
            WritePlainLog "Kill '${pids}'." "$logFile"
            sudo kill -KILL $pids
        else
            WritePlainLog "${PROCESS_NAME} not found in running processes." "$logFile"
        fi
        
        [[ ${LOOPCOUNT} -eq 0 ]] &&  break
        
        WritePlainLog "Wait ${TIMEOUT} sec for '${PROCESS_NAME}' in ${LOOPCOUNT} attempt." "$logFile"
        sleep ${TIMEOUT}
    done
    
    WritePlainLog "WaitThenKillProcess() done." "$logFile"
}

KillProcessThenWait()
{
    NAME=$1
    PID=$2
    [[ -z "$3" ]] && TIMEOUT=30 || TIMEOUT=$3
    if [[ -n "${PID}" && -n "$(ps -p ${PID} -o pid= )" ]]
    then
        WritePlainLog "Send INT signal to $NAME ($PID)." "$logFile"
        res=$(sudo  kill -INT  "${PID}" 2>&1)
        WritePlainLog "Res:${res}" "$logFile"
        WritePlainLog "Wait until $NAME process finish..." "$logFile"
        sleep ${TIMEOUT}
        WaitThenKillProcess "gdb" "$TIMEOUT"
        WritePlainLog "Done." "$logFile"
    else
        WritePlainLog "No pid and/or process not alive." "$logFile"
    fi
}

HandleSignal()
{
    WritePlainLog "Signal captured. Process it..." "$logFile"
    
    TIME_FOR_ENGINE_TO_STOP=60
    KillProcessThenWait  "Hthor" "${HTHOR_PID}" "${TIME_FOR_ENGINE_TO_STOP}"
    
    KillProcessThenWait  "Thor" "${THOR_PID}" "${TIME_FOR_ENGINE_TO_STOP}"
    
    KillProcessThenWait  "Roxie" "${ROXIE_PID}" "${TIME_FOR_ENGINE_TO_STOP}"
    
    WaitThenKillProcess "gdb" "$TIMEOUT" "5"
    
    wait ${HTHOR_PID} ${THOR_PID} ${ROXIE_PID}
    WritePlainLog "All done." "$logFile"
    
    TEST_TIME=$(( $(date +%s) - $TIME_STAMP ))
    
    MyExit -5
}

trap "HandleSignal" TERM
trap "HandleSignal" INT

BUILD_ROOT=build
if [ ! -d ${BUILD_ROOT} ]
then
    mkdir ${BUILD_ROOT}
    # Experimental to use RAMDisk tas build directory
    #res=$( free; sudo -S sync; echo 3 | sudo tee /proc/sys/vm/drop_caches; free )
    #WritePlainLog "res:${res}" "$resultFile"
    #sudo mount -t tmpfs -o noatime,size=6G tmpfs $(pwd)/${BUILD_ROOT}
    #WritePlainLog " $( mount | egrep '/home/ati/Smoketest' )" "$resultFile"
fi
WritePlainLog "BUILD_ROOT:$BUILD_ROOT" "$resultFile"

HAVE_PKG=$( find $PR_ROOT/ -maxdepth 1 -iname '*'"$PKG_EXT" -type f -print | wc -l)
#CAN NOT BE USED in real Smoketest envireonment! Set it and export into the environment
#SKIP_BUILD=1
[[ -z $SKIP_BUILD ]] && SKIP_BUILD=0
WritePlainLog "HAVE_PKG: $HAVE_PKG\nSKIP_BUILD:$SKIP_BUILD" "$logFile"

#
#----------------------------------------------------
#
# To determine the number of CPUs/Cores to build and parallel execution

WriteEnvInfo "$logFile"

# In the build race fixed version there should be two directory exitance tests.
BUILD_RACE_FIXED=$( grep -c "if (\!checkDirExists(dir))" HPCC-Platform/tools/hidl/hidl_utils.cpp )

if [[ "${BUILD_RACE_FIXED}" -eq 1 ]]
then
    # Not in this PR, restrict the build job count
    NUMBER_OF_CPUS=8
    WritePlainLog "Build race didn't fixed in this PR, restrict the build job count to ${NUMBER_OF_CPUS}" "$logFile"
fi

rm -f ${BUILD_ROOT}/CMakeCache.txt

WritePlainLog "Start..." "$logFile"
WritePlainLog "PR_ROOT:$PR_ROOT" "$logFile"
WritePlainLog "Build type: ${BUILD_TYPE}" "$logFile"

echo $@

echo "$0 CLI params are: $@"
echo "$0 CLI params are: $@" >> $logFile

REGRESSION_TEST=''
DOCS_BUILD=0
ECLWATCH_BUILD_STRATEGY=SKIP
NEW_ECLWATCH_BUILD_MODE=1
KEEP_FILES=0
ENABLE_SPARK=0
SUPPRESS_SPARK=1
MAKE_WSSQL=0
ENABLE_STACK_TRACE=''
RTE_CHANGED=0

while [ $# -gt 0 ]
do
    param=$1
    param=${param//-/}
    echo "Param: ${param}"
    case $param in
    
        test*)  REGRESSION_TEST=${param//tests=/}
                REGRESSION_TEST=${REGRESSION_TEST//\"/}
                WritePlainLog "Regression Suite test case(s): '${REGRESSION_TEST}'" "$logFile"
                ;;
                
        docs*)  DOCS_BUILD=${param//docs=True/1}
                DOCS_BUILD=${DOCS_BUILD//docs=False/0}
                WritePlainLog "Build docs: '${DOCS_BUILD}'" "$logFile"
                ;;
                
        unit*)  UNIT_TESTS=${param//unittest=True/1}
                UNIT_TESTS=${UNIT_TESTS//unittest=False/0}
                WritePlainLog "Run unittests: '${UNIT_TESTS}'" "$logFile"
                ;;
                
        wutte*) WUTOOL_TESTS=${param//wuttest=True/1}
                WUTOOL_TESTS=${WUTOOL_TESTS//wuttest=False/0}
                WritePlainLog "Run wutool -selftest: '${WUTOOL_TESTS}'" "$logFile"
                ;;
        
        build*) ECLWATCH_BUILD_STRATEGY=${param//buildEclWatch=True/IF_MISSING}
                ECLWATCH_BUILD_STRATEGY=${ECLWATCH_BUILD_STRATEGY//buildEclWatch=False/SKIP}
                ECLWATCH_BUILD_STRATEGY=IF_MISSING
                WritePlainLog "Build ECLWatch: '${ECLWATCH_BUILD_STRATEGY}'" "$logFile"
                if [[ "$ECLWATCH_BUILD_STRATEGY" == "IF_MISSING" ]]
                then
                    MAKE_WSSQL=1
                    WritePlainLog "Build wsSQL: '${MAKE_WSSQL}'" "$logFile"
                fi
                ;;
                
        keepF*) KEEP_FILES=${param//keepFiles=True/1}
                KEEP_FILES=${KEEP_FILES//keepFiles=False/0}
                WritePlainLog "Keep files: '${KEEP_FILES}'" "$logFile"
                ;;
                
        enableStackT*)
                STACK_TRACE=${param//enableStackTrace=True/1}
                STACK_TRACE=${STACK_TRACE//enableStackTrace=False/0}
                if [[ "$STACK_TRACE" == "1" ]]
                then
                    ENABLE_STACK_TRACE="--generateStackTrace"
                fi
                WritePlainLog "Stack trace: '${STACK_TRACE}', ENABLE_STACK_TRACE: ${ENABLE_STACK_TRACE}" "$logFile"
                ;;
                
        newEclWatchBuildMode*)
                NEW_ECLWATCH_BUILD_MODE=${param//newEclWatchBuildMode=True/1}
                NEW_ECLWATCH_BUILD_MODE=${NEW_ECLWATCH_BUILD_MODE//newEclWatchBuildMode=False/0}
                WritePlainLog "New ECLWatch build mode:${NEW_ECLWATCH_BUILD_MODE}" "$logFile"
                ;;
                
        rteChanged*)
                RTE_CHANGED=${param//rteChanged=True/1}
                RTE_CHANGED=${RTE_CHANGED//rteChanged=False/0}
                WritePlainLog "RTE Changed: ${RTE_CHANGED}" "$logFile"
                ;;
            
    esac
    shift
done

LOGLEVEL=info
WritePlainLog "Loglevel: ${LOGLEVEL}" "$logFile"

#--------------------------------------
# Check plugins (especially Pythons) and apply exclusion if it is need

additionalPlugins=($( cat $SOURCE_ROOT/initfiles/etc/DIR_NAME/environment.conf.in | egrep '^additionalPlugins'| cut -d= -f2 ))
for plugin in ${additionalPlugins[*]}
do 
    upperPlugin=${plugin^^} 
    #echo $upperPlugin
    case $upperPlugin in
        
        PYTHON2*)   if [[ -z $GLOBAL_EXCLUSION  ]]
                    then
                        GLOBAL_EXCLUSION="-e python3" 
                    else
                        GLOBAL_EXCLUSION=$GLOBAL_EXCLUSION",python3"
                    fi
                    if [[ "${REGRESSION_TEST}" =~ "py" ]]
                    then
                        REGRESSION_TEST=${REGRESSION_TEST}" *py*"
                    fi
                    PYTHON_PLUGIN="-DSUPPRESS_PY3EMBED=ON -DINCLUDE_PY3EMBED=OFF"
                    ;;
                    
        PYTHON3*)   if [[ -z $GLOBAL_EXCLUSION  ]]
                    then
                        GLOBAL_EXCLUSION="-e python2" 
                    else
                        GLOBAL_EXCLUSION=$GLOBAL_EXCLUSION",python2"
                    fi
                    if [[ "${REGRESSION_TEST}" =~ "py" ]]
                    then
                        REGRESSION_TEST=${REGRESSION_TEST}" *py*"
                    fi
                    
                    WritePlainLog "line in suite: $( egrep '\(not included \) and excluded' $SOURCE_ROOT/testing/regress/hpcc/regression/suite.py )'." "$logFile"
                    excludeInclude=$( egrep -c '\(not included \) and excluded' $SOURCE_ROOT/testing/regress/hpcc/regression/suite.py )
                    WritePlainLog "excludeInclude: ${excludeInclude} (path: $SOURCE_ROOT/testing/regress/hpcc/regression/suite.py)" "$logFile"

                    [[ $excludeInclude -eq 1 ]] && GLOBAL_EXCLUSION="$GLOBAL_EXCLUSION -r=python3"
                    
                    PYTHON_PLUGIN="-DSUPPRESS_PY2EMBED=ON -DINCLUDE_PY2EMBED=OFF"
                    ;;
                    
        *)          # Do nothing yet
                    ;;
    esac
done    

WritePlainLog "Regression Suite test case(s): '${REGRESSION_TEST}'" "$logFile"
WritePlainLog "Global exclusion: ${GLOBAL_EXCLUSION}" "$logFile"

#
#-------------------------------------------------------
#
cd $SOURCE_ROOT

currentBranch=$( git branch | grep '*' | cut -d ' ' -f 2)
WritePlainLog "Current branch: ${currentBranch}" "$logFile"

cd ${PR_ROOT}

#-------------------------------------------------
#
# Clone OBT 

OBT_DIR="${PR_ROOT}/OBT"
[ -d $OBT_DIR ] && rm -rf $OBT_DIR

WritePlainLog "Cloning OBT into $OBT_DIR..." "$logFile"
pushd ${PR_ROOT}
git clone https://github.com/AttilaVamos/OBT.git >> ${logFile} 2>&1
popd
WritePlainLog "Done." "$logFile"


#echo "Update Git submodules"
#echo "Update Git submodules" >> $logFile 2>&1

#git submodule update --init --recursive

#-------------------------------------------------
#
# Set core file generation and be named core_[program].[pid]
#
WritePlainLog "Forceing standard core to be generated in same directory" "$logFile"
res=$(echo 'core_%e.%p' | sudo tee /proc/sys/kernel/core_pattern)
WritePlainLog "res:${res}" "$logFile"
WritePlainLog "Current core generation is: $(cat /proc/sys/kernel/core_pattern)" "$logFile"
#-------------------------------------------------
#
# Patch system/jlib/jthread.hpp to build in c++11 
#
echo 'Patch system/jlib/jthread.hpp to build in c++11 '

sed 's/%8"I64F"X %6"I64F"d/%8" I64F "X %6" I64F "d/g' "../HPCC-Platform/system/jlib/jthread.hpp" > temp.xml && mv -f temp.xml "../HPCC-Platform/system/jlib/jthread.hpp"

#-------------------------------------------------
#
# Build
#
actDate=$(date +%Y-%m-%d_%H-%M-%S);
TIME_STAMP=$(date +%s)
WriteMilestone "Makefile generation" "$logFile"
WritePlainLog "${BUILD_TYPE} build start at: $actDate" "$logFile"
cd $PR_ROOT

cd ${BUILD_ROOT}

if [[ ( "${SYSTEM_ID}" =~ "Ubuntu_16_04" ) ]]
then
    if [[ ! -f ${BUILD_ROOT}/downloads/boost_1_71_0.tar.gz ]]
    then
        WritePlainLog "There is not '${BUILD_ROOT}/downloads/boost_1_71_0.tar.gz' file." "$logFile"
        #mkdir -p ${BUILD_ROOT}/downloads/
        #wget -v  -O ${BUILD_ROOT}/downloads/boost_1_71_0.tar.gz  https://dl.bintray.com/boostorg/release/1.71.0/source/boost_1_71_0.tar.gz
        #WritePlainLog "$( ls -l ${BUILD_ROOT}/downloads/*.gz )" "$logFile"
        
        MAKE_FILE="../HPCC-Platform/cmake_modules/buildBOOST_REGEX.cmake"
        sed -e 's/TIMEOUT \(.*\)/TIMEOUT 60/g' ${MAKE_FILE} >temp.cmake && sudo mv -f temp.cmake ${MAKE_FILE}
        WritePlainLog "There is $( egrep 'TIMEOUT' ${MAKE_FILE} )" "$logFile"
    fi
else
    WritePlainLog "This system is not PRP VM." "$logFile"
fi    


WritePlainLog "Create makefiles $(date +%Y-%m-%d_%H-%M-%S)" "$logFile"
#cmake -G"Eclipse CDT4 - Unix Makefiles" -D CMAKE_BUILD_TYPE=Debug -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform >> $logFile 2>&1
#cmake  -G"Eclipse CDT4 - Unix Makefiles" -DINCLUDE_PLUGINS=ON -DTEST_PLUGINS=1 -DSUPPRESS_PY3EMBED=ON -DINCLUDE_PY3EMBED=OFF -DMAKE_DOCS=$DOCS_BUILD -DUSE_CPPUNIT=$UNIT_TESTS -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -D MAKE_CASSANDRAEMBED=1 -D CMAKE_BUILD_TYPE=$BUILD_TYPE -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform >> $logFile 2>&1
#cmake  -G"Eclipse CDT4 - Unix Makefiles" -DINCLUDE_PLUGINS=ON -DTEST_PLUGINS=1 ${PYTHON_PLUGIN} -DMAKE_DOCS=$DOCS_BUILD -DUSE_CPPUNIT=$UNIT_TESTS -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -D MAKE_CASSANDRAEMBED=1 -D CMAKE_BUILD_TYPE=$BUILD_TYPE -DECLWATCH_BUILD_STRATEGY=$ECLWATCH_BUILD_STRATEGY -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform >> $logFile 2>&1
GENERATOR="Eclipse CDT4 - Unix Makefiles"
CMAKE_CMD=$'cmake -G "'${GENERATOR}$'"'
CMAKE_CMD+=$' -D CMAKE_BUILD_TYPE='$BUILD_TYPE

if [[ ( "${SYSTEM_ID}" =~ "Ubuntu_16_04" ) ]]
then
      # On Ubuntu 16.04 RPR VM I have not proper Python 3.6 so avoid to build plugins and Python stuff
      CMAKE_CMD+=$' -D INCLUDE_PLUGINS=OFF -D TEST_PLUGINS=OFF -DSUPPRESS_PY3EMBED=ON -DINCLUDE_PY3EMBED=OFF -DSUPPRESS_PY2EMBED=ON -DINCLUDE_PY2EMBED=OFF -D USE_PYTHON3=OFF'
else
      CMAKE_CMD+=$' -D INCLUDE_PLUGINS=ON -D TEST_PLUGINS=1 '${PYTHON_PLUGIN}
fi
CMAKE_CMD+=$' -D MAKE_DOCS='$DOCS_BUILD
CMAKE_CMD+=$' -D USE_CPPUNIT='$UNIT_TESTS
CMAKE_CMD+=$' -D INCLUDE_SPARK='${ENABLE_SPARK}' -DSUPPRESS_SPARK='${SUPPRESS_SPARK}' -DSPARK='${ENABLE_SPARK}
CMAKE_CMD+=$' -D ECLWATCH_BUILD_STRATEGY='$ECLWATCH_BUILD_STRATEGY
CMAKE_CMD+=$' -D WSSQL_SERVICE='${MAKE_WSSQL}
CMAKE_CMD+=$' -D CMAKE_EXPORT_COMPILE_COMMANDS=ON -D USE_LIBXSLT=ON -D XALAN_LIBRARIES= -D MAKE_CASSANDRAEMBED=1'
if [ -f "/usr/local/lib/libssl.so" ]
then
    CMAKE_CMD+=$' -D OPENSSL_LIBRARIES=/usr/local/lib/libssl.so -D OPENSSL_SSL_LIBRARY=/usr/local/lib/libssl.so'
fi
CMAKE_CMD+=$' -DCENTOS_6_BOOST=ON'
CMAKE_CMD+=$' -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform'
WritePlainLog "CMAKE_CMD:'${CMAKE_CMD}'\\n" "$logFile"

if [[ ($HAVE_PKG -eq 0) || ($SKIP_BUILD = 0) ]]
then
    eval ${CMAKE_CMD} >> $logFile 2>&1
else
    WritePlainLog "We have and use install package so keep makefile generation." "$logFile"
fi

# -- Current release version is hpccsystems-platform_community-5.1.0-trunk0Debugquantal_amd64

UninstallHpcc "$logFile"

hpccpackage="hpccsystems-platform_community-4.1.0-trunk1Debugquantal_amd64.deb"
hpccpackage="hpccsystems-platform*"
rm -f $hpccpackage
if [ $? -ne 0 ]
then
    WritePlainLog "To remove ${hpccpackage} is failed" "$logFile"
else
    WritePlainLog "To remove ${hpccpackage} success" "$logFile"
fi

PREP_TIME=$(( $(date +%s) - $TIME_STAMP ))
WritePlainLog "Makefiles created ($(date +%Y-%m-%d_%H-%M-%S) $PREP_TIME sec )" "$logFile"

#
# ------------------------------------------------
# ECLWatch build dependencies and Lint check
#
if [[ ($HAVE_PKG -eq 0) || ($SKIP_BUILD = 0) ]]
then
    WritePlainLog "Keep ECLWatch build as is." "$logFile"
else
    ECLWATCH_BUILD_STRATEGY=SKIP
    WritePlainLog "Skip ECLWatch build with ECLWATCH_BUILD_STRATEGY = $ECLWATCH_BUILD_STRATEGY." "$logFile"
fi

if [[ ${NEW_ECLWATCH_BUILD_MODE} -eq 0 ]]
then
    if [[ "$ECLWATCH_BUILD_STRATEGY" != "SKIP" ]]
    then
        pushd ${SOURCE_ROOT}/esp/src
        WritePlainLog "npm install start." "$logFile"
        
        WritePlainLog "Install ECLWatch build dependencies." "$logFile"

        cmd="npm install"
        WritePlainLog "$cmd" "$logFile"

        res=$( ${cmd} 2>&1 )

        WritePlainLog "res:${res}" "$logFile"
        WritePlainLog "npm install end." "$logFile"

        cmd="npm run test"
        WritePlainLog "$cmd" "$logFile"
        res=$( ${cmd} 2>&1 )

        WritePlainLog "res:${res}" "$logFile"
        WritePlainLog "npm test end" "$logFile"

        popd
    else
        WritePlainLog "Install ECLWatch build dependencies skipped." "$logFile"
    fi

    CheckEclWatchBuildResult "$logFile"
fi

#
#----------------------------------------------------
# Build HPCC
# 
WriteMilestone "Build it" "$logFile"
#WritePlainLog "Build it" "$logFile"

BUILD_SUCCESS=true
#make -j 16 -d package >> $logFile 2>&1
CMD="make -j ${NUMBER_OF_BUILD_THREADS}"

TIME_STAMP=$(date +%s)
#${CMD} 2>&1 | tee -a $logFile
if [[ ($HAVE_PKG -eq 0) || ($SKIP_BUILD = 0) ]]
then
    WritePlainLog "cmd: ${CMD}  ($(date +%Y-%m-%d_%H-%M-%S))" "$logFile"
    ${CMD} >> $logFile 2>&1
else
    WritePlainLog "We have a package and want to skip build -> not build use existing one" "$logFile"
    WritePlainLog "!!!! This feature only for testing Smoketest engine and CAN NOT BE USED in real Smoketest envireonment !!!!" "$logFile"
fi
 

if [ $? -ne 0 ]
then
    WritePlainLog "res: $res" "$logFile"
    #cat $logFile
    WritePlainLog "Build failed" > ../build.summary
    BUILD_TIME=$(( $(date +%s) - $TIME_STAMP ))
#    CheckResult "$logFile"
#    
#    WritePlainLog "ReportTimes." "$logFile"
#    ReportTimes "$logFile"
#    exit 1
    MyExit "-1"
else
    WritePlainLog "Build: success" "$logFile"
fi

#
# ------------------------------------------------
# ECLWatch build dependencies and Lint check
#

if [[ ${NEW_ECLWATCH_BUILD_MODE} -eq 1 ]]
then
    if [[ "$ECLWATCH_BUILD_STRATEGY" != "SKIP" ]]
    then
        pushd ${SOURCE_ROOT}/esp/src
        
        WritePlainLog "npm install start." "$logFile"
        WritePlainLog "npm ci." "$logFile"

        cmd="npm ci"
        WritePlainLog "$cmd" "$logFile"

        res=$( ${cmd} 2>&1 )

        WritePlainLog "res:${res}" "$logFile"
        
        WritePlainLog "Install ECLWatch build dependencies." "$logFile"
        
        cmd="npm run build"
        WritePlainLog "$cmd" "$logFile"

        res=$( ${cmd} 2>&1 )

        WritePlainLog "res:${res}" "$logFile"
        WritePlainLog "npm install end." "$logFile"

        cmd="npm run test"
        WritePlainLog "$cmd" "$logFile"
        res=$( ${cmd} 2>&1 )

        WritePlainLog "res:${res}" "$logFile"
        WritePlainLog "npm test end" "$logFile"

        popd
    else
        WritePlainLog "Install ECLWatch build dependencies skipped." "$logFile"
    fi

    CheckEclWatchBuildResult "$logFile"
fi

BUILD_TIME=$(( $(date +%s) - $TIME_STAMP ))
WritePlainLog "Build end ($(date +%Y-%m-%d_%H-%M-%S) $BUILD_TIME sec )" "$logFile"
TIME_STAMP=$(date +%s)

WriteMilestone "Package generation" "$logFile"
WritePlainLog "HAVE_PKG: $HAVE_PKG\nSKIP_BUILD:$SKIP_BUILD" "$logFile"
if [[ ($HAVE_PKG -eq 0) || ($SKIP_BUILD = 0) ]]
then
    CMD="make -j ${NUMBER_OF_BUILD_THREADS} package"
    WritePlainLog "cmd: ${CMD}" "$logFile"
    ${CMD} >> $logFile 2>&1
else
    WritePlainLog "Skip package generation and use existing one" "$logFile"
     cp -v ../*${PKG_EXT} .
fi

PACKAGE_TIME=$(( $(date +%s) - $TIME_STAMP ))
WritePlainLog "Package end ($(date +%Y-%m-%d_%H-%M-%S)  $PACKAGE_TIME sec )" "$logFile"
TIME_STAMP=$(date +%s)

WritePlainLog "packageExt: '$PKG_EXT', installCMD: '$PKG_INST_CMD'." "$logFile"

#hpccpackage=$( grep 'Current release version' ${logFile} | cut -c 31- )".deb"
hpccpackage=$( grep 'Current release version' ${logFile} | cut -c 31- )${PKG_EXT}
if [[ ! -f $hpccpackage ]]
then 
    echo "nincs ( $( pwd))"
    hpccpackage=$( find . -maxdepth 1 -iname '*'"${PKG_EXT}" -type f -print | sort -r | head -n 1)
    echo "hpccpackage:$hpccpackage"
fi
WritePlainLog "HPCC package: ${hpccpackage}" "$logFile"

WritePlainLog "Check the build result" "$logFile"
if [ -f "$hpccpackage" ]
then
    
    #echo "Build: success"
    #echo "Build: success" >> $logFile 2>&1
    echo "Build: success" > ../build.summary

    if [[ "$ECLWATCH_BUILD_STRATEGY" != "SKIP" ]]
    then
        CheckEclWatchBuildResult "$logFile"
    fi
    
    WriteMilestone "Install $hpccpackage" "$logFile"
    #sudo dpkg -i $hpccpackage >> $logFile 2>&1
    CMD="sudo ${PKG_INST_CMD} $hpccpackage"
    WritePlainLog "$CMD" "$logFile"
    TIME_STAMP=$(date +%s)
    ${CMD} >> $logFile 2>&1
    res=$?
    if [ $res -ne 0 ]
    then
        if [[ $res -eq 1 ]]
        then
            # Uninstall and try to install again
            UninstallHpcc "$logFile"
            ${CMD} >> $logFile 2>&1
            res=$?
        fi
        if [ $res -ne 0 ]
        then
            WritePlainLog "Install failed: ${res}" > ../build.summary
#            CheckResult "$logFile"
#            CheckEclWatchBuildResult "$logFile"
#            exit 1
            MyExit "-1"
        fi
    fi

    INSTALL_TIME=$(( $(date +%s) - $TIME_STAMP ))
    WritePlainLog "Installed ($(date +%Y-%m-%d_%H-%M-%S) $INSTALL_TIME sec )" "$logFile"
     
    CheckCMakeResult "$logFile"
    
    cd ${PR_ROOT}
    if [[ -f environment.xml ]]
    then
        echo "Copy and use preconfigured environment.xml"
        sudo cp environment.xml $TARGET_DIR/etc/HPCCSystems/environment.xml
        echo "Rename it to prevent further use"
        mv environment.xml environment.xml-preconf
    
    else
        # TO-DO fix it
        echo "Patch $TARGET_DIR/etc/HPCCSystems/environment.xml to set $THOR_SLAVES slave Thor system"
        sudo cp $TARGET_DIR/etc/HPCCSystems/environment.xml $TARGET_DIR/etc/HPCCSystems/environment.xml.bak
        sed -e 's/slavesPerNode="\(.*\)"/slavesPerNode="'"$THOR_SLAVES"'"/g'                                    \
                 -e 's/maxEclccProcesses="\(.*\)"/maxEclccProcesses="'"$PARALLEL_QUERIES"'"/g'                  \
                 -e 's/name="maxCompileThreads" value="\(.*\)"/name="maxCompileThreads" value="'"$PARALLEL_QUERIES"'"/g'                  \
                 "$TARGET_DIR/etc/HPCCSystems/environment.xml" > temp.xml && sudo mv -f temp.xml "$TARGET_DIR/etc/HPCCSystems/environment.xml"
    fi
    
    cp $TARGET_DIR/etc/HPCCSystems/environment.xml environment.xml-used
    
    if [[ -d "$TARGET_DIR/opt/HPCCSystems/lib64" ]]
    then
        WritePlainLog "There is an unwanted lib64 directory, copy its contents into lib" "$logFile"
        sudo cp -v $TARGET_DIR/opt/HPCCSystems/lib64/* $TARGET_DIR/opt/HPCCSystems/lib/
    fi
    
    
    # We can have more than one Thor node and each has their onw slavesPerNode attribute
    WritePlainLog "Number of thor slaves (/thor node)  : $(sed -n 's/slavesPerNode="\(.*\)"/\1/p' $TARGET_DIR/etc/HPCCSystems/environment.xml | tr '\n' ',' | tr -d [:space:])" "$logFile"
    WritePlainLog "Maximum number of Eclcc processes is: $(sed -n 's/maxEclccProcesses="\(.*\)"/\1/p' $TARGET_DIR/etc/HPCCSystems/environment.xml | tr -d [:space:])" "$logFile"
    WritePlainLog "Maximum number of compile threads is: $(sed -n 's/<Option name=\"maxCompileThreads\" value=\"\(.*\)\"\/>/\1/p' $TARGET_DIR/etc/HPCCSystems/environment.xml | tr -d [:space:])" "$logFile"

    WritePlainLog "Start HPCC system" "$logFile"

    WritePlainLog "Check HPCC system status" "$logFile"

    # Ensure no componenets are running
    sudo /etc/init.d/hpcc-init status >> $logFile 2>&1
    IS_THOR_ON_DEMAND=$( sudo /etc/init.d/hpcc-init status | egrep -i -c 'mythor \[OD\]' )
    WritePlainLog ""  "$logFile"

    hpccRunning=$( sudo /etc/init.d/hpcc-init status | grep -c "running")
    if [[ "$hpccRunning" -ne 0 ]]
    then
        res=$(sudo /etc/init.d/hpcc-init stop |grep -c 'still')
        # If the result is "Service dafilesrv, mydafilesrv is still running."
        if [[ $res -ne 0 ]]
        then
            #echo $res
            WritePlainLog "res: $res" "$logFile"
            sudo /etc/init.d/dafilesrv stop >> $logFile 2>&1
        fi
    fi

    # Let's start
    TIME_STAMP=$(date +%s)
    HPCC_STARTED=1
    [ -z $NUMBER_OF_HPCC_COMPONENTS ] && NUMBER_OF_HPCC_COMPONENTS=$( sudo /opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -list | egrep -i -v 'eclagent' | wc -l )
    
    if [[ $IS_THOR_ON_DEMAND -ne 0 ]]
    then
        WritePlainLog "We have $IS_THOR_ON_DEMAND Thor on demand server(s)." "$logFile"
        WritePlainLog "Adjust the number of starting components from $NUMBER_OF_HPCC_COMPONENTS" "$logFile"
        NUMBER_OF_HPCC_COMPONENTS=$(( $NUMBER_OF_HPCC_COMPONENTS  - $IS_THOR_ON_DEMAND ))
        WritePlainLog "to $NUMBER_OF_HPCC_COMPONENTS." "$logFile"
    fi

    WriteMilestone "Start HPCC system with $NUMBER_OF_HPCC_COMPONENTS components" "$logFile"
    #WritePlainLog "Let's start HPCC system" "$logFile"

    hpccStart=$( sudo /etc/init.d/hpcc-init start 2>&1 )
    hpccStatus=$( sudo /etc/init.d/hpcc-init status 2>&1 )
    hpccRunning=$( sudo /etc/init.d/hpcc-init status | grep -c "running")
    
    WritePlainLog $hpccRunning" HPCC component started." "$logFile"
    if [[ "$hpccRunning" -eq "$NUMBER_OF_HPCC_COMPONENTS" ]]
    then        
        WritePlainLog "HPCC Start: OK" "$logFile"
        
        WritePlainLog "pushd ${PR_ROOT}" "$logFile"
        pushd ${PR_ROOT}
        # Always copy the timestampLogger.sh and WatchDog.py to ensure using the latest one
        WritePlainLog "Copy latest version of timestampLogger.sh" "$logFile"
        cp -vf ../timestampLogger.sh .
        
        WritePlainLog "Copy latest version of WatchDog.py" "$logFile"
        cp -vf ../WatchDog.py .
        
        WritePlainLog "cwd: $( popd )" "$logFile"
        
    else
        HPCC_STARTED=0
        WritePlainLog "HPCC Start: Fail" "$logFile"

        WritePlainLog "HPCC start:" "$logFile"

        WritePlainLog "${hpccStart}" "$logFile"

        WritePlainLog " " "$logFile"
        WritePlainLog "HPCC status:" "$logFile"

        WritePlainLog "${hpccStatus}" "$logFile"

        res=$( sudo /etc/init.d/hpcc-init status | grep  "stopped" ) 
        WritePlainLog "${res}" "$logFile"
    fi
    START_TIME=$(( $(date +%s) - $TIME_STAMP ))
    
    if [[ HPCC_STARTED -eq 1 ]]
    then
        TIME_STAMP=$(date +%s)
        if [[ $UNIT_TESTS -eq 1 ]]
        then
            WritePlainLog "pushd ${PR_ROOT}" "$logFile"
            pushd ${PR_ROOT}
            
            cp -vf ../unittest.sh .

            cmd="./unittest.sh"
            WriteMilestone "Unittests" "$logFile"
            WritePlainLog "$(ls -ld /var/lib/HPCCSystems/hpcc-data/*)" "$logFile"
            
            WritePlainLog "cmd: ${cmd}" "$logFile"
            #${cmd} 2>&1 | tee -a $logFile
            ${cmd} >> $logFile 2>&1
            
            popd
        fi
        
        if [[ $WUTOOL_TESTS -eq 1 ]]
        then
            WritePlainLog "pushd ${PR_ROOT}" "$logFile"
            pushd ${PR_ROOT}
            cp -vf ../wutoolTest.sh .
            
            cmd="./wutoolTest.sh"
            WriteMilestone "WUTooltest" "$logFile"
            WritePlainLog "$(ls -ld /var/lib/HPCCSystems/hpcc-data/*)" "$logFile"
            WritePlainLog "cmd: ${cmd}" "$logFile"
            #${cmd} 2>&1  | tee -a $logFile
            ${cmd} >> $logFile 2>&1
            
            popd
        fi
        
        if [ -n "$REGRESSION_TEST" ]
        then
            #WritePlainLog "pushd ${TEST_DIR}" "$logFile"
            #pushd ${TEST_DIR}
            
            # Clean -up rte dir if exists
            [[ -d $RTE_DIR ]] && rm -rf $RTE_DIR
                
            if [[ $RTE_CHANGED == 0 ]]
            then
                # Get the official version
                # If we haven't  local RTE dir?
                if [[ ! -d $RTE_DIR ]]
                then 
                    WritePlainLog "Get the official version from GitHub" "$logFile"
                    #mkdir -p $RTE_DIR
                    #res=$( cp -rv $COMMON_RTE_DIR/* $RTE_DIR/ 2>&1)
                    res=$( git clone  https://github.com/AttilaVamos/RTE.git $RTE_DIR )
                    WritePlainLog "res: ${res}" "$logFile"
                fi
            else
                WritePlainLog "RTE changed (in this PR) get it from local source tree" "$logFile"
                if [[ ! -d $RTE_DIR ]]
                then 
                    mkdir -p $RTE_DIR
                    res=$( cp -v $TEST_DIR/ecl-test* $RTE_DIR/ 2>&1)
                    WritePlainLog "res: ${res}" "$logFile"
                    res=$( cp -rv $TEST_DIR/hpcc $RTE_DIR/hpcc 2>&1)
                    WritePlainLog "res: ${res}" "$logFile"
                fi
                
            fi
            
            # We should update the config in RTE dir
            WritePlainLog "pushd ${RTE_DIR}" "$logFile"
            pushd ${RTE_DIR}
            #pwd2=$(PR_ROOT )
            #echo "pwd:${pwd2}"
            #echo "pwd:${pwd2}" >> $logFile 2>&1

            # Patch ecl-test.json to put log inside the smoketest-xxxx directory
            mv ecl-test.json ecl-test_json.bak
            RESULT_DIR_ESC=${RESULT_DIR//\//\\\/}  #Replace '/' to '\/'
            sed sed -e 's/"regressionDir"\w*: "\(.*\)"/"regressionDir" : "'"${RESULT_DIR_ESC}"'"/'   \
                -e 's/"logDir"\w*: "\(.*\)"/"logDir" : "'"${RESULT_DIR_ESC}"'\/log"/'  \
                -e 's/"timeout":"\(.*\)"/"timeout":"'"${REGRESSION_TIMEOUT}"'"/' \
                -e 's/"maxAttemptCount":"\(.*\)"/"maxAttemptCount":"'"${REGRESSION_MAX_ATTEMPT_COUNT}"'"/'   ./ecl-test_json.bak > ./ecl-test.json
        
            WritePlainLog "Regression path in ecl-test.json:\n$(sed -n 's/\(regressionDir\)/\1/p' ./ecl-test.json)" "$logFile"
            WritePlainLog "Regression log path             :\n$(sed -n 's/\(logDir\)/\1/p' ./ecl-test.json)" "$logFile"
            WritePlainLog "OPT path in ecl-test.json       :\n$(sed -n 's/\(\/opt\/\)/\1/p' ./ecl-test.json)" "$logFile"
            WritePlainLog "$(ls -ld /var/lib/HPCCSystems/hpcc-data/*)" "$logFile"
            
            #
            #-----------------------------------------------------
            # Patch regression suite tests if it needed to prevent extra long execuion tme
            # See utlis.sh "Individual timeouts" section
            if [[ -n $TIMEOUTS ]]
            then
                COUNT=${#TIMEOUTS[@]}
                WritePlainLog "There is $COUNT test case need individual timeout setting" "$logFile"
                for((testIndex=0; testIndex<$COUNT; testIndex++))
                do
                    TEST=(${!TIMEOUTS[$testIndex]})
                    WritePlainLog "\tPatch ${TEST[0]} with ${TEST[1]} sec timeout" "$logFile"
                    file="$TEST_DIR/ecl/${TEST[0]}"
                    timeout=${TEST[1]}
                    # Check if test already has '//timeout' tag
                    if [[ $( egrep -c '\/\/timeout' $file ) -eq 0 ]]
                    then
                        # it has not, add one at the beginning of the file
                        mv -fv $file $file-back
                        echo "// Patched by the Smoketest on $( date '+%Y.%m.%d %H:%M:%S')" > $file
                        echo "//timeout $timeout" >> $file
                        cat $file-back >> $file
                        
                    else
                        # yes it has, change it
                        cp -fv $file $file-back
                        sed -e 's/^\/\/timeout \(.*\).*$/\/\/ Patched by the Smoketest on '"$( date '+%Y.%m.%d %H:%M:%S')"'\n\/\/timeout '"$timeout"'/g' $file > $file-patched && mv -f $file-patched $file
                    fi
                done
            fi
            
            #popd
            #WritePlainLog "pushd ${RTE_DIR}" "$logFile"
            #pushd ${RTE_DIR}
            # Setup should run first
            #cmd="./ecl-test setup -t all --suiteDir $TEST_DIR --config $TEST_DIR/ecl-test.json --loglevel ${LOGLEVEL} --timeout ${SETUP_TIMEOUT} --pq ${PARALLEL_QUERIES} ${ENABLE_STACK_TRACE}"
            cmd="./ecl-test setup -t all --suiteDir $TEST_DIR --loglevel ${LOGLEVEL} --timeout ${SETUP_TIMEOUT} --pq ${PARALLEL_QUERIES} ${ENABLE_STACK_TRACE}"
            WriteMilestone "Regression setup" "$logFile"
            WritePlainLog "${cmd}" "$logFile"
            
            ${cmd} >> $logFile 2>&1
            
            [[ -f ${PR_ROOT}/setup.summary ]] && rm ${PR_ROOT}/setup.summary
            
            ProcessLog "${PR_ROOT}/HPCCSystems-regression/log/" "setup_hthor" "$logFile"
            ProcessLog "${PR_ROOT}/HPCCSystems-regression/log/" "setup_thor" "$logFile"
            ProcessLog "${PR_ROOT}/HPCCSystems-regression/log/" "setup_roxie" "$logFile"

            setupPassed=1
            # Check if there is no error in Setup phase
            if [[ -f ${PR_ROOT}/setup.summary ]]
            then
                numberOfNotFailedEngines=$( cat ${PR_ROOT}/setup.summary | egrep -o '\<failed:0\>' | wc -l )
                if [[ $numberOfNotFailedEngines -ne 3 ]]
                then
                    setupPassed=0
                    WritePlainLog "Setup failed on $(( 3 - $numberOfNotFailedEngines )) engines." "$logFile"
                    inSuiteErrorLog=$( cat $logFile | sed -n "/\[Error\]/,/Suite destructor./p" )
                    WritePlainLog "${inSuiteErrorLog}" "$logFile"
                else            
                    retVal=0
                    WriteMilestone "Regression test" "$logFile"
                    WritePlainLog "Regression Suite test case(s): '${REGRESSION_TEST}'" "$logFile"
                    
                    WritePlainLog "Parallel regression test: '${PARALLEL_REGRESSION_TEST}'" "$logFile"
                    if [[ ${PARALLEL_REGRESSION_TEST} -eq 0 ]]
                    then
                        if [[ ${REGRESSION_TEST} == "*" ]]
                        then
                            # Run whole Regression Suite
                            #cmd="./ecl-test run -t ${TARGET} ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --config $TEST_DIR/ecl-test.json --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} --pq ${PARALLEL_QUERIES} ${STORED_PARAMS} ${ENABLE_STACK_TRACE}"
                            cmd="./ecl-test run -t ${TARGET} ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} ${THOR_CONNECT_TIMEOUT} --pq ${PARALLEL_QUERIES} ${STORED_PARAMS} ${ENABLE_STACK_TRACE}"
                        else
                            # Query the selected tests or whole suite if '*' in REGRESSION_TEST
                            #cmd="./ecl-test query -t ${TARGET} ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --config $TEST_DIR/ecl-test.json --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} --pq ${PARALLEL_QUERIES} ${STORED_PARAMS} ${ENABLE_STACK_TRACE} $REGRESSION_TEST"
                            cmd="./ecl-test query -t ${TARGET} ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} ${THOR_CONNECT_TIMEOUT} --pq ${PARALLEL_QUERIES} ${STORED_PARAMS} ${ENABLE_STACK_TRACE} $REGRESSION_TEST"
                        fi
                    
                        WritePlainLog "cmd: ${cmd}" "$logFile"
                        #${cmd} 2>&1  | tee -a $logFile
                        ${cmd} >> $logFile 2>&1 
                        retVal=$?
                    else
                        WritePlainLog "Parallel regression test started..." "$logFile"
                        WritePlainLog  "Start hthor regression ..." "$logFile"
                        hthorCmd="./ecl-test run -t hthor ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} ${THOR_CONNECT_TIMEOUT} ${STORED_PARAMS} --generateStackTrace --pq $HTHOR_PQ"
                        exec   ${hthorCmd} > $hthorTestLogFile 2>&1 &
                        HTHOR_PID=$!
                        WritePlainLog  "Hthor pid: $HTHOR_PID." "$logFile"

                        WritePlainLog "Start thor regression..." "$logFile"
                        thorCmd="./ecl-test run -t thor ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} ${THOR_CONNECT_TIMEOUT} ${STORED_PARAMS} --generateStackTrace --pq $THOR_PQ"
                        exec ${thorCmd}  > $thorTestLogFile 2>&1 &
                        THOR_PID=$!
                        WritePlainLog  "Thor pid: $THOR_PID." "$logFile"
                        
                        WritePlainLog "Start roxie regression..." "$logFile"
                        roxieCmd="./ecl-test run -t roxie ${GLOBAL_EXCLUSION} --suiteDir $TEST_DIR --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} ${THOR_CONNECT_TIMEOUT} ${STORED_PARAMS} --generateStackTrace --pq $ROXIE_PQ"
                        exec ${roxieCmd} > $roxieTestLogFile 2>&1 &
                        ROXIE_PID=$!
                        WritePlainLog  "Roxie pid: $ROXIE_PID." "$logFile"
                        
                        WritePlainLog "Wait for processes finished." "$logFile"

                        wait 
                        retVal=$?
                        
                        echo "${hthorCmd}" >> $logFile
                        cat $hthorTestLogFile  >> $logFile
                        
                        echo "${thorCmd}" >> $logFile
                        cat $thorTestLogFile  >> $logFile
                        
                        echo "${roxieCmd}" >> $logFile
                        cat $roxieTestLogFile >> $logFile
                        
                    fi    
                    hasError=$( cat $logFile | grep -c '\[Error\]' )
                    WritePlainLog "retVal: ${retVal}, hasError:${hasError}, setupPassed: ${setupPassed}" "$logFile"
                    if [[ $retVal == 0  && $hasError == 0 && $setupPassed == 1 ]]
                    then
                        # Collect results
                        ProcessLog "${PR_ROOT}/HPCCSystems-regression/log/" "hthor" "$logFile"
                        ProcessLog "${PR_ROOT}/HPCCSystems-regression/log/" "thor" "$logFile"
                        ProcessLog "${PR_ROOT}/HPCCSystems-regression/log/" "roxie" "$logFile"
                    else
                        WritePlainLog "Command failed : ${retVal}" "$logFile"
                        inSuiteErrorLog=$( cat $logFile | sed -n "/\[Error\]/,/Suite destructor./p" )
                        WritePlainLog "${inSuiteErrorLog}" "$logFile"
                    fi
                fi
            fi
            # Get tests stat
            if [[ -f $OBT_DIR/QueryStat2.py ]]
            then
                WritePlainLog "Get tests stat..." "$logFile"
                CMD="$OBT_DIR/QueryStat2.py -p $PR_ROOT/ -d '' -a --timestamp "
                WritePlainLog "  CMD: '$CMD'" "$logFile"
                ${CMD} >> ${logFile} 2>&1
                retCode=$( echo $? )
                WritePlainLog "  RetCode: $retCode" "$logFile"
                WritePlainLog "  Files: $( ls -l perfstat* )" "$logFile"
                WritePlainLog "Done." "$logFile"
            else
                WritePlainLog "$OBT_DIR/QueryStat2.py not found. Skip perfromance result collection " "$logFile"
            fi
            
            #setupPassed=0
            #WritePlainLog "Setup failed." "$logFile"
            inSuiteErrorLog=$( cat $logFile | sed -n "/\[Error\]/,/Suite destructor./p" )
            if [ -n "${inSuiteErrorLog}" ]
            then
                WritePlainLog "${inSuiteErrorLog}" "$logFile"
            else
                WritePlainLog "There isn't Suite Error" "$logFile"
            fi
            popd
#            set +x
        fi
        
#        set -x
        if [[ -n "$REGRESSION_TEST" && -f ${ESP_TEST_DIR}/wutest.py ]]
        then
            WritePlainLog "pushd ${ESP_TEST_DIR}" "$logFile"
            pushd ${ESP_TEST_DIR}
            
            date=$(date +%Y-%m-%d_%H-%M-%S);
            wutestLogFile="wutest-"$(date +%Y-%m-%d_%H-%M-%S)".log";
            
            cmd='./wutest.py'
            WriteMilestone "WUtest" "$logFile"
            WritePlainLog "${cmd}" "$logFile"
            ${cmd}  > ${wutestLogFile} 2>&1
            res=$?
            WritePlainLog "res: ${res}" "$logFile"
            
            cp ${wutestLogFile} ${PR_ROOT}/.
            
            popd
        fi
        
#        set +x
        
        TEST_TIME=$(( $(date +%s) - $TIME_STAMP ))

        TIME_STAMP=$(date +%s)
        WriteMilestone "Stop HPCC" "$logFile"
        
        res=$(sudo /etc/init.d/hpcc-init stop |grep -c 'still')
        # If the result is "Service dafilesrv, mydafilesrv is still running."
        if [[ $res -ne 0 ]]
        then
            WritePlainLog "res: ${res}" "$logFile"
            sudo /etc/init.d/dafilesrv stop >> $logFile 2>&1
        fi
        hpccRunning=$( sudo /etc/init.d/hpcc-init status | grep -c "running")
        #echo $hpccRunning" HPCC component running."
        WritePlainLog $hpccRunning" HPCC component running." "$logFile"
        if [[ $hpccRunning -ne 0 ]]
        then
            WritePlainLog "HPCC Stop: Fail $hpccRunning components are still up!" "$logFile"
            hpccRunning=$( sudo /etc/init.d/hpcc-init status | grep "running")
            WritePlainLog "Running componenets:\n${hpccRunning}" "$logFile"
            exit -1
        else
            WritePlainLog "HPCC Stop: OK" "$logFile"
        fi
        STOP_TIME=$(( $(date +%s) - $TIME_STAMP ))
    fi
    
    WriteMilestone "End game" "$logFile"
    WritePlainLog "Archive HPCC logs into ${HPCC_LOG_ARCHIVE}." "$logFile"
    
    zip ${HPCC_LOG_ARCHIVE} -r /var/log/HPCCSystems/* > ${HPCC_LOG_ARCHIVE}.log 2>&1

    WritePlainLog "Check core files." "$logFile"

    #cores=($(find /var/lib/HPCCSystems/ -name 'core*' -type f))
    cores=( $(find /var/lib/HPCCSystems/ -name 'core*' -type f -exec printf "%s\n" '{}' \; ) )
    
    if [ ${#cores[@]} -ne 0 ]
    then
        numberOfCoresTobeArchive=${#cores[@]}
        WritePlainLog "Number of core file(s): $numberOfCoresTobeArchive" "$logFile"
        if [[ $numberOfCoresTobeArchive -gt 20 ]]
        then
            numberOfCoresTobeArchive=20
        fi
        
        WritePlainLog "Archive $numberOfCoresTobeArchive/${#cores[*]} core file(s) from /var/lib/HPCCSystems/" "$logFile" 

        echo "Archive $numberOfCoresTobeArchive/${#cores[*]} core file(s) from /var/lib/HPCCSystems/" >> ${HPCC_CORE_ARCHIVE}.log
        echo "----------------------------------------------------------------" >> ${HPCC_CORE_ARCHIVE}.log
        echo "" >> ${HPCC_CORE_ARCHIVE}.log
     
        components=()
        for core in ${cores[@]:0:$numberOfCoresTobeArchive}
        do 
            coreSize=$( ls -l $core | awk '{ print $5}' )
            WritePlainLog "Add $core (${coreSize} bytes) to archive" "$logFile"

            WritePlainLog "Generate backtrace for $core." "$logFile"
            #base=$( dirname $core )
            #lastSubdir=${base##*/}
            #comp=${lastSubdir##my}
            corename=${core##*/}; 
            comp=$( echo $corename | tr '_.' ' ' | awk '{print $2 }' ); 
            compnamepart=$( find /opt/HPCCSystems/bin/ -iname "$comp*" -type f -print); 
            compname=${compnamepart##*/}
            WritePlainLog "corename: ${corename}, comp: ${comp}, compnamepart: ${compnamepart}, component name: ${compname}" "$logFile"
            components+=compname
            WritePlainLog "componenet:/opt/HPCCSystems/bin/${compname} core: $core" "$logFile"
            res=$( sudo gdb --batch --quiet -ex "set interactive-mode off" -ex "echo \nBacktrace for all threads\n==========================" -ex "thread apply all bt" -ex "echo \n Registers:\n==========================\n" -ex "info reg" -ex "echo \n Disas:\n==========================\n" -ex "disas" -ex "quit" "/opt/HPCCSystems/bin/${compname}" $core | sudo tee $core.trace 2>&1 )
            sudo chmode 0777 $core*
            WritePlainLog "Trace: $core.trace  generated" "$logFile"
            #WritePlainLog "Files: $( sudo ls -l $core* ) " "$logFile"
            #sudo zip ${HPCC_CORE_ARCHIVE} $c >> ${HPCC_CORE_ARCHIVE}.log
        done

        # Add core files to ZIP
        for core in ${cores[@]:0:$numberOfCoresTobeArchive}; do echo $core; done | sudo zip ${HPCC_CORE_ARCHIVE} -@ >> ${HPCC_CORE_ARCHIVE}.log
        
        # Addd binaries
        for comp in ${componenets[@]}; do echo "/opt/HPCCSystems/bin/${comp}"; done | sudo zip ${HPCC_CORE_ARCHIVE} -@ >> ${HPCC_CORE_ARCHIVE}.log
        
        # Add trace files to ZIP
        WritePlainLog "List trace files" "$logFile"
        res=$( sudo find /var/lib/HPCCSystems/ -iname '*.trace' -type f -print 2>&1 )
        WritePlainLog "res: ${res}" "$logFile"
        
        sudo find /var/lib/HPCCSystems/ -iname '*.trace' -type f -print -exec sudo cp -v '{}' $PR_ROOT/. \;

        sudo find /var/lib/HPCCSystems/ -iname '*.trace' -type f -print | sudo zip ${HPCC_CORE_ARCHIVE} -@ >> ${HPCC_CORE_ARCHIVE}.log

        echo 'Done.' >> ${HPCC_CORE_ARCHIVE}.log
        WritePlainLog "Done." "$logFile"
        
        WritePlainLog "Store trace file(s) from ${PR_ROOT} into the related ZAP file " "$logFile"
        pushd ${PR_ROOT}
       
        find . -iname '*.trace' -type f -print | while read trc
        do 
            WritePlainLog "Core trace file: $trc" "$logFile"

            wuid=$( cat $trc | egrep 'was generated' | sed -e 's/.*\(W2[0-9].*\)\s.*/\1/')
            WritePlainLog "wuid:$wuid" "$logFile"

            zap=$(find HPCCSystems-regression/zap/ -iname '*'"$wuid"'*' -type f -print)
            if [[ -n "$zap" ]]
            then
                WritePlainLog "ZAP file: $zap" "$logFile"
                res=$( zip -v -u $zap $trc 2>&1)
                WritePlainLog "res: ${res}" "$logFile"
            else
                WritePlainLog "ZAP file not found." "$logFile"
            fi
        done

        popd
        WritePlainLog "Done." "$logFile"

    else
        WritePlainLog "There is no core file in /var/lib/HPCCSystems/" "$logFile"

        #echo "There is no core file in /var/lib/HPCCSystems/" >> ${HPCC_CORE_ARCHIVE}.log
        #echo "-----------------------------------------------------------" >> ${HPCC_CORE_ARCHIVE}.log
        #echo " " >>${HPCC_CORE_ARCHIVE}.log
    fi

    # Only for debug purpose
    #zip ${HPCC_LOG_ARCHIVE} -r /var/lib/HPCCSystems/myeclagent/temp/* >> ${HPCC_LOG_ARCHIVE}.log 2>&1

    zip ${HPCC_LOG_ARCHIVE} ${PR_ROOT}/build/esp/src/eclwatch_build_*.txt >> ${HPCC_LOG_ARCHIVE}.log 2>&1
    zip ${HPCC_LOG_ARCHIVE} -r ${PR_ROOT}/build/esp/src/build/*.txt >> ${HPCC_LOG_ARCHIVE}.log 2>&1

    # Archive ECLCC cache
    zip ${HPCC_LOG_ARCHIVE} -r ${PR_ROOT}/HPCC-Platform/testing/regress/.eclcc/* >> ${HPCC_LOG_ARCHIVE}.log 2>&1

    UninstallHpcc "$logFile"
    WritePlainLog "Remove Cassandra leftovers." "$logFile"
    sudo rm -rf /var/lib/cassandra/*
    sudo rm -r /var/log/cassandra
    WritePlainLog "Done." "$logFile"
 
else
    WritePlainLog "Build: failed!" "$logFile"
    echo "Build: failed" > ../build.summary
    
#    CheckResult "$logFile"
#    CheckEclWatchBuildResult "$logFile"
#    WritePlainLog "ReportTimes." "$logFile"
#    ReportTimes "$logFile"
#
#    exit 1
    MyExit "-1"
fi

WritePlainLog "ReportTimes." "$logFile"
ReportTimes "$logFile"

WritePlainLog "All done." "$logFile"
