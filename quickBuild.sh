#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

clear
pwd=$( pwd )
PR_ROOT=${pwd}
PR_ROOT_ESCAPED=${PR_ROOT//\//\\/}
SOURCE_ROOT=${PR_ROOT}/HPCC-Platform
BUILD_TYPE=RelWithDebInfo
#BUILD_TYPE=Debug
TEST_DIR=${SOURCE_ROOT}/testing/regress
ESP_TEST_DIR=${SOURCE_ROOT}/testing/esp/wudetails
TARGET_DIR=hpcc
RUNTIME_USER=$( whoami )
# For spray/despray 
# If '/' is issing at the end then it force (de)Sprays to fail
DROPZONE_PATH="dropzonePath=${PR_ROOT}/${TARGET_DIR}/var/lib/HPCCSystems/mydropzone/" 

# For external.ecl must remove trailing '/', replace all capital letter to escaped one (e.g.: 'P' -> '^p')
# and change all '/' to '::'
LOGICAL_PWD="${PR_ROOT:1}"
LOGICAL_PWD=${LOGICAL_PWD//\//::}
LOCALDIR_PATH="localdir=$LOGICAL_PWD::$TARGET_DIR::var::lib::^h^p^c^c^systems::mydropzone"
# Convert at Upper case to escaped one
LOCALDIR_PATH=$( echo "${LOCALDIR_PATH}" | sed -r 's/([A-Z])/^\L\1/g' )

STORED_PARAMS="-X ${DROPZONE_PATH},${LOCALDIR_PATH}"

date=$(date +%Y-%m-%d_%H-%M-%S);
logFile=$PR_ROOT/${BUILD_TYPE}"_Build_"$date".log";
resultFile=$PR_ROOT/${BUILD_TYPE}"_result_"$date".log";

HPCC_LOG_ARCHIVE=$PR_ROOT/HPCCSystems-logs-$date
HPCC_CORE_ARCHIVE=$PR_ROOT/HPCCSystems-cores-$date

#
#----------------------------------------------------
#

cp -f ../utils.sh .
. ./utils.sh

#
#----------------------------------------------------
#

# Archive previous session's logs.
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

BUILD_ROOT=build
if [ ! -d ${BUILD_ROOT} ]
then
    mkdir ${BUILD_ROOT}
fi
echo "BUILD_ROOT:$BUILD_ROOT"

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

WritePlainLog "Stored params: ${STORED_PARAMS}" "$logFile"

echo "$0 CLI params are: $@"
echo "$0 CLI params are: $@" >> $logFile

REGRESSION_TEST=''
DOCS_BUILD=0
ECLWATCH_BUILD_STRATEGY=SKIP
KEEP_FILES=0
ENABLE_SPARK=0
SUPPRESS_SPARK=1
MAKE_WSSQL=0
ENABLE_STACK_TRACE=''

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
# Update submodule
#cd $SOURCE_ROOT

#echo "Update Git submodules"
#echo "Update Git submodules" >> $logFile 2>&1

#git submodule update --init --recursive

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

WritePlainLog "Create makefiles $(date +%Y-%m-%d_%H-%M-%S)" "$logFile"
#cmake -G"Eclipse CDT4 - Unix Makefiles" -D CMAKE_BUILD_TYPE=Debug -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform >> $logFile 2>&1
#cmake  -G"Eclipse CDT4 - Unix Makefiles" -DINCLUDE_PLUGINS=ON -DTEST_PLUGINS=1 -DSUPPRESS_PY3EMBED=ON -DINCLUDE_PY3EMBED=OFF -DMAKE_DOCS=$DOCS_BUILD -DUSE_CPPUNIT=$UNIT_TESTS -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -D MAKE_CASSANDRAEMBED=1 -D CMAKE_BUILD_TYPE=$BUILD_TYPE -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform >> $logFile 2>&1
#CM_CMD="cmake -DRUNTIME_USER=$RUNTIME_USER -DDESTDIR=${PR_ROOT}/$TARGET_DIR -DINCLUDE_PLUGINS=ON -DTEST_PLUGINS=1 ${PYTHON_PLUGIN} -DMAKE_DOCS=$DOCS_BUILD -DUSE_CPPUNIT=$UNIT_TESTS -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -D MAKE_CASSANDRAEMBED=1 -D CMAKE_BUILD_TYPE=$BUILD_TYPE -DECLWATCH_BUILD_STRATEGY=$ECLWATCH_BUILD_STRATEGY -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform"

GENERATOR="Eclipse CDT4 - Unix Makefiles"
CMAKE_CMD=$'cmake -G "'${GENERATOR}$'"'
CMAKE_CMD+=$' -D RUNTIME_USER='$RUNTIME_USER
CMAKE_CMD+=$' -D DESTDIR='${PR_ROOT}/$TARGET_DIR
CMAKE_CMD+=$' -D CMAKE_BUILD_TYPE='$BUILD_TYPE
CMAKE_CMD+=$' -D INCLUDE_PLUGINS=ON -D TEST_PLUGINS=1 '${PYTHON_PLUGIN}
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
CMAKE_CMD+=$' -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 ../HPCC-Platform ln -s ../HPCC-Platform'
WritePlainLog "CMAKE_CMD:'${CMAKE_CMD}'\\n" "$logFile"

eval ${CMAKE_CMD} >> $logFile 2>&1

# -- Current release version is hpccsystems-platform_community-5.1.0-trunk0Debugquantal_amd64
# In quick build method we have not package

#hpccpackage="hpccsystems-platform_community-4.1.0-trunk1Debugquantal_amd64.deb"
#hpccpackage="hpccsystems-platform*"
#rm -f $hpccpackage
#if [ $? -ne 0 ]
#then
#    echo "To remove ${hpccpackage} is failed"
#    echo "To remove ${hpccpackage} is failed" >> $logFile 2>&1
#else
#    echo "To remove ${hpccpackage} success"
#    echo "To remove ${hpccpackage} success" >> $logFile 2>&1
#fi


#
# ------------------------------------------------
# ECLWatch build dependencies and Lint check
#

if [[ "$ECLWATCH_BUILD_STRATEGY" != "SKIP" ]]
then
    WritePlainLog "npm install start." "$logFile"
    WritePlainLog "Install ECLWatch build dependencies." "$logFile"
    pushd ${SOURCE_ROOT}/esp/src

    cmd="npm install"
    WritePlainLog "$cmd" "$logFile"

    res=$( ${cmd} 2>&1 )

    WritePlainLog "res:${res}" "$logFile"
    WritePlainLog "npm install end." "$logFile"

    cmd="npm test"
    WritePlainLog "$cmd" "$logFile"
    res=$( ${cmd} 2>&1 )

    WritePlainLog "res:${res}" "$logFile"
    WritePlainLog "npm test end" "$logFile"

    popd
else
    WritePlainLog "Install ECLWatch build dependencies skipped." "$logFile"
fi

PREP_TIME=$(( $(date +%s) - $TIME_STAMP ))
WritePlainLog "Makefiles created ($(date +%Y-%m-%d_%H-%M-%S) $PREP_TIME sec )" "$logFile"
#
#----------------------------------------------------
# Build HPCC
# 
WriteMilestone "Build it" "$logFile"
#WritePlainLog "Build it" "$logFile"

BUILD_SUCCESS=true
#make -j 16 -d package >> $logFile 2>&1
CMD="make -j ${NUMBER_OF_BUILD_THREADS}"


WritePlainLog "cmd: ${CMD}  ($(date +%Y-%m-%d_%H-%M-%S))" "$logFile"
TIME_STAMP=$(date +%s)
#${CMD} 2>&1 | tee -a $logFile
${CMD} >> $logFile 2>&1
 

if [ $? -ne 0 ]
then
    WritePlainLog "res: $res" "$logFile"
    #cat $logFile
    WritePlainLog "Build failed" > ../build.summary
    CheckResult "$logFile"
    exit 1
else
    WritePlainLog "Build: success" "$logFile"
fi

CheckEclWatchBuildResult "$logFile"

BUILD_TIME=$(( $(date +%s) - $TIME_STAMP ))
WritePlainLog "Build and Install finished ($( date +%Y-%m-%d_%H-%M-%S ) $BUILD_TIME sec)" "$logFile"

# # In quick build method we do not make package
#CMD="make -j ${NUMBER_OF_BUILD_THREADS} package"
#
#echo "cmd: ${CMD} $(date +%Y-%m-%d_%H-%M-%S)"
#echo "cmd: ${CMD} $(date +%Y-%m-%d_%H-%M-%S)" >> $logFile 2>&1
#
#${CMD} >> $logFile 2>&1
#
#
#echo "End $(date +%Y-%m-%d_%H-%M-%S)"
#echo "End $(date +%Y-%m-%d_%H-%M-%S)" >> $logFile 2>&1

#IS_NOT_RPM=$( type "rpm" 2>&1 | grep -c "not found" )
#echo "IS_NOT_RPM: $IS_NOT_RPM"
#PKG_EXT=
#INST_CMD=
#
#if [[ "$IS_NOT_RPM" -ne 0 ]]
#then
#    PKG_EXT=".deb"
#    INST_CMD="dpkg -i "
#else
#    PKG_EXT=".rpm"
#    INST_CMD="rpm -i --nodeps "
#fi
#echo "packageExt: '$PKG_EXT', installCMD: '$INST_CMD'."
#
##hpccpackage=$( grep 'Current release version' ${logFile} | cut -c 31- )".deb"
#hpccpackage=$( grep 'Current release version' ${logFile} | cut -c 31- )${PKG_EXT}
#
#echo "HPCC package: ${hpccpackage}"
#echo "HPCC package: ${hpccpackage}" >> $logFile 2>&1

WritePlainLog "Check the build result" "$logFile"
if [ ${BUILD_SUCCESS} ]
then
    echo "Build: success"
    #echo "Build: success" >> $logFile 2>&1
    echo "Build: success" > ../build.summary

    if [[ "$ECLWATCH_BUILD_STRATEGY" != "SKIP" ]]
    then
        CheckEclWatchBuildResult "$logFile"
    fi
    
    # In quick build method we do not make package, but install it
    WriteMilestone "Install HPCC Platform" "$logFile"
    echo "Install HPCC Platform" 
    CMD="make -j ${NUMBER_OF_BUILD_THREADS} install"
    TIME_STAMP=$(date +%s)
    ${CMD} >> $logFile 2>&1
    if [ $? -ne 0 ]
    then
        WritePlainLog "Install failed" > ../build.summary
        CheckResult "$logFile"
        CheckEclWatchBuildResult "$logFile"
        exit 1
    fi

    INSTALL_TIME=$(( $(date +%s) - $TIME_STAMP ))
    WritePlainLog "Installed ($(date +%Y-%m-%d_%H-%M-%S) $INSTALL_TIME sec )" "$logFile"

    CheckCMakeResult "$logFile"
    
    cd ${PR_ROOT}
    # TO-DO fix it
    echo "Patch $TARGET_DIR/etc/HPCCSystems/environment.xml to set $THOR_SLAVES slave Thor system"
    sudo cp $TARGET_DIR/etc/HPCCSystems/environment.xml $TARGET_DIR/etc/HPCCSystems/environment.xml.bak
    sed -e 's/slavesPerNode="\(.*\)"/slavesPerNode="'"$THOR_SLAVES"'"/g'                                    \
             -e 's/maxEclccProcesses="\(.*\)"/maxEclccProcesses="'"$PARALLEL_QUERIES"'"/g'                  \
             -e 's/name="maxCompileThreads" value="\(.*\)"/name="maxCompileThreads" value="'"$PARALLEL_QUERIES"'"/g'                  \
             "$TARGET_DIR/etc/HPCCSystems/environment.xml" > temp.xml && sudo mv -f temp.xml "$TARGET_DIR/etc/HPCCSystems/environment.xml"
    # We can have more than one Thor node and each has their onw slavesPerNode attribute
    WritePlainLog "Number of thor slaves (/thor node)  : $(sed -n 's/slavesPerNode="\(.*\)"/\1/p' $TARGET_DIR/etc/HPCCSystems/environment.xml | tr '\n' ',' | tr -d [:space:])" "$logFile"
    WritePlainLog "Maximum number of Eclcc processes is: $(sed -n 's/maxEclccProcesses="\(.*\)"/\1/p' $TARGET_DIR/etc/HPCCSystems/environment.xml | tr -d [:space:])" "$logFile"
    WritePlainLog "Maximum number of compile threads is: $(sed -n 's/<Option name=\"maxCompileThreads\" value=\"\(.*\)\"\/>/\1/p' $TARGET_DIR/etc/HPCCSystems/environment.xml | tr -d [:space:])" "$logFile"
 
    WritePlainLog "Start HPCC system" "$logFile"

    WritePlainLog "Check HPCC system status" "$logFile"

    # Ensure no componenets are running
    $TARGET_DIR/etc/init.d/hpcc-init status  >> $logFile 2>&1
    IS_THOR_ON_DEMAND=$( $TARGET_DIR/etc/init.d/hpcc-init status | egrep -i -c 'mythor \[OD\]' )
    WritePlainLog ""  "$logFile"

    hpccRunning=$( $TARGET_DIR/etc/init.d/hpcc-init status  | grep -c "running")
    if [[ "$hpccRunning" -ne 0 ]]
    then
        res=$($TARGET_DIR/etc/init.d/hpcc-init stop | grep -c 'still')
        # If the result is "Service dafilesrv, mydafilesrv is still running."
        if [[ $res -ne 0 ]]
        then
            #echo $res
            WritePlainLog "res: $res" "$logFile"
            $TARGET_DIR/etc/init.d/dafilesrv stop >> $logFile 2>&1
        fi
    fi

    # Let's start
    TIME_STAMP=$(date +%s)
    HPCC_STARTED=1
    [ -z $NUMBER_OF_HPCC_COMPONENTS ] && NUMBER_OF_HPCC_COMPONENTS=$( $TARGET_DIR/opt/HPCCSystems/sbin/configgen -env $TARGET_DIR/etc/HPCCSystems/environment.xml -list | egrep -i -v 'eclagent' | wc -l )
    
    if [[ $IS_THOR_ON_DEMAND -ne 0 ]]
    then
        WritePlainLog "We have $IS_THOR_ON_DEMAND Thor on demand server(s)." "$logFile"
        WritePlainLog "Adjust the number of starting components from $NUMBER_OF_HPCC_COMPONENTS" "$logFile"
        NUMBER_OF_HPCC_COMPONENTS=$(( $NUMBER_OF_HPCC_COMPONENTS  - $IS_THOR_ON_DEMAND ))
        WritePlainLog "to $NUMBER_OF_HPCC_COMPONENTS." "$logFile"
    fi
    
    WriteMilestone "Start HPCC system with $NUMBER_OF_HPCC_COMPONENTS components" "$logFile"
    #WritePlainLog "Let's start HPCC system" "$logFile"
    hpccStart=$( $TARGET_DIR/etc/init.d/hpcc-init start 2>&1 )
    hpccStatus=$( $TARGET_DIR/etc/init.d/hpcc-init status 2>&1 )
    hpccRunning=$( $TARGET_DIR/etc/init.d/hpcc-init status | grep -c "running" )

    WritePlainLog "$hpccRunning HPCC component started." "$logFile"
    if [[ "$hpccRunning" -ge "$NUMBER_OF_HPCC_COMPONENTS" ]]
    then        
        WritePlainLog "HPCC Start: OK" "$logFile"
        
        WritePlainLog "pushd ${PR_ROOT}" "$logFile"
        pushd ${PR_ROOT}
        # Always copy the timestampLogger.sh and WatchDog.py to ensure using the latest one
        WritePlainLog "Copy latest version of timestampLogger.sh" "$logFile"
        cp -f ../timestampLogger.sh .
        
        WritePlainLog "Copy latest version of WatchDog.py" "$logFile"
        cp -f ../WatchDog.py .
        
        WritePlainLog "cwd: $( popd )" "$logFile"
        
    else
        HPCC_STARTED=0
        WritePlainLog "HPCC Start: Fail" "$logFile"

        WritePlainLog "HPCC start:" "$logFile"

        WritePlainLog "${hpccStart}" "$logFile"

        WritePlainLog " " "$logFile"
        WritePlainLog "HPCC status:" "$logFile"

        WritePlainLog "${hpccStatus}" "$logFile"

        res=$( $TARGET_DIR/etc/init.d/hpcc-init status | grep  "stopped" ) 
        WritePlainLog "res: ${res}" "$logFile"
    fi
    START_TIME=$(( $(date +%s) - $TIME_STAMP ))
    
    if [[ HPCC_STARTED -eq 1 ]]
    then
        TIME_STAMP=$(date +%s)
        if [[ $UNIT_TESTS -eq 1 ]]
        then
            WritePlainLog "pushd ${PR_ROOT}" "$logFile"
            pushd ${PR_ROOT}
            
            cp -f ../unittest.sh .

            cmd="./unittest.sh"
            WriteMilestone "Unittests" "$logFile"
            WritePlainLog "cmd: ${cmd}" "$logFile"
            #${cmd} 2>&1 | tee -a $logFile
            ${cmd} >> $logFile 2>&1
            
            popd
        fi
        
        if [[ $WUTOOL_TESTS -eq 1 ]]
        then
            WritePlainLog "pushd ${PR_ROOT}" "$logFile"
            pushd ${PR_ROOT}
            cp -f ../wutoolTest.sh .
            
            cmd="./wutoolTest.sh"
            WriteMilestone "WUTooltest" "$logFile"
            WritePlainLog "cmd: ${cmd}" "$logFile"
            #${cmd} 2>&1  | tee -a $logFile
            ${cmd} >> $logFile 2>&1
            
            popd
        fi
        
        if [ -n "$REGRESSION_TEST" ]
        then
        
            PATH=$PATH:$PR_ROOT/$TARGET_DIR/opt/HPCCSystems/bin:$PR_ROOT/$TARGET_DIR/opt/HPCCSystems/sbin
            
            WritePlainLog "pushd ${PR_ROOT}" "$logFile"
            pushd ${TEST_DIR}
            #pwd2=$(PR_ROOT )
            #echo "pwd:${pwd2}"
            #echo "pwd:${pwd2}" >> $logFile 2>&1

            # Patch ecl-test.json to put log inside the smoketest-xxxx directory
            # TO-DO same with donload directory
            # file::127.0.0.1::opt::^H^P^C^C^Systems::testing::regress::download::0drvb10.txt
            # change timeout to 150 sec and maxAttemptCount to 1
            mv ecl-test.json ecl-test_json.bak
            sed -e 's/~\/HPCCSystems\-regression/\.\.\/\.\.\/\.\.\/HPCCSystems\-regression/'        \
                -e 's/\/opt\//'"${PR_ROOT_ESCAPED}"'\/'"${TARGET_DIR}"'\/opt\//'                    \
                -e 's/"timeout":"\(.*\)"/"timeout":"'"${REGRESSION_TIMEOUT}"'"/' \
                -e 's/"maxAttemptCount":"\(.*\)"/"maxAttemptCount":"1"/'   ./ecl-test_json.bak > ./ecl-test.json
        
            WritePlainLog "Regression path in ecl-test.json:\n$(sed -n 's/\(HPCCSystems\-regression\)/\1/p' ./ecl-test.json)" "$logFile"
            WritePlainLog "OPT path in ecl-test.json       :\n$(sed -n 's/\(\/opt\/\)/\1/p' ./ecl-test.json)" "$logFile"
            
            # Setup should run first
            cmd="./ecl-test setup -t all --loglevel ${LOGLEVEL} --timeout ${SETUP_TIMEOUT} --pq ${PARALLEL_QUERIES} ${ENABLE_STACK_TRACE}"
            WriteMilestone "Regression setup" "$logFile"
            WritePlainLog "${cmd}" "$logFile"
            
            #${cmd} 2>&1  | tee -a $logFile
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
                    if [[ ${REGRESSION_TEST} == "*" ]]
                    then
                        # Run whole Regression Suite
                        cmd="./ecl-test run -t ${TARGET} ${GLOBAL_EXCLUSION} --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} --pq ${PARALLEL_QUERIES} ${STORED_PARAMS} ${ENABLE_STACK_TRACE}"
                    else
                        # Query the selected tests or whole suite if '*' in REGRESSION_TEST
                        cmd="./ecl-test query -t ${TARGET} ${GLOBAL_EXCLUSION} --loglevel ${LOGLEVEL} --timeout ${REGRESSION_TIMEOUT} --pq ${PARALLEL_QUERIES} ${STORED_PARAMS} ${ENABLE_STACK_TRACE} $REGRESSION_TEST"
                    fi
                
                    WritePlainLog "cmd: ${cmd}" "$logFile"
                    #${cmd} 2>&1  | tee -a $logFile
                    ${cmd} >> $logFile 2>&1 
                    retVal=$?
                    
                    hasError=$( cat $logFile | grep -c '\[Error\]' )
                    if [[ $retVal == 0  && $hasError == 0 && setupPassed == 1 ]]
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
        
        res=$( $TARGET_DIR/etc/init.d/hpcc-init stop |grep -c 'still')
        # If the result is "Service dafilesrv, mydafilesrv is still running."
        if [[ $res -ne 0 ]]
        then
            WritePlainLog "res: ${res}" "$logFile"
            sudo $TARGET_DIR/etc/init.d/dafilesrv stop >> $logFile 2>&1
        fi
        hpccRunning=$( $TARGET_DIR/etc/init.d/hpcc-init status | grep -c "running")
        WritePlainLog $hpccRunning" HPCC component running." "$logFile"
        if [[ $hpccRunning -ne 0 ]]
        then
            WritePlainLog "HPCC Stop: Fail $hpccRunning components are still up!" "$logFile"
            hpccRunning=$( $TARGET_DIR/etc/init.d/hpcc-init status | grep "running")
            WritePlainLog "Running componenets:\n${hpccRunning}" "$logFile"
            exit -1
        else
            WritePlainLog "HPCC Stop: OK" "$logFile"
        fi
        STOP_TIME=$(( $(date +%s) - $TIME_STAMP ))
    fi
    
    WriteMilestone "End game" "$logFile"
    WritePlainLog "Archive HPCC logs into ${HPCC_LOG_ARCHIVE}." "$logFile"
    
    zip ${HPCC_LOG_ARCHIVE} -r ${PR_ROOT}/${TARGET_DIR}/var/log/HPCCSystems/* >> $logFile 2>&1

    WritePlainLog "Check core files in $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/." "$logFile"

    #cores=($(find $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/ -name 'core*' -type f))
    cores=( $(find $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/ -name 'core*' -type f -exec printf "%s\n" '{}' \; ) )
    
    if [ ${#cores[@]} -ne 0 ]
    then
        numberOfCoresTobeArchive=${#cores[@]}
        WritePlainLog "Number of core file(s): $numberOfCoresTobeArchive" "$logFile"
        if [[ $numberOfCoresTobeArchive -gt 20 ]]
        then
            numberOfCoresTobeArchive=20
        fi
        
        WritePlainLog "Archive $numberOfCoresTobeArchive/${#cores[*]} core file(s) from $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/" "$logFile" 

        echo "Archive $numberOfCoresTobeArchive/${#cores[*]} core file(s) from $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/" >> ${HPCC_CORE_ARCHIVE}.log
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
            compnamepart=$( find hpcc/opt/HPCCSystems/bin/ -iname "$comp*" -type f -print); 
            compname=${compnamepart##*/}
            WritePlainLog "corename: ${corename}, comp: ${comp}, compnamepart: ${compnamepart}, component name: ${compname}" "$logFile"
            components+=compname
            gdb --batch --quiet -ex "set interactive-mode off" -ex "echo \nBacktrace for all threads\n==========================" -ex "thread apply all bt" -ex "echo \n Registers:\n==========================\n" -ex "info reg" -ex "echo \n Disas:\n==========================\n" -ex "disas" -ex "quit" "$PR_ROOT/$TARGET_DIR/opt/HPCCSystems/bin/${compname}" $core > $core.trace 2>&1

            #sudo zip ${HPCC_CORE_ARCHIVE} $c >> ${HPCC_CORE_ARCHIVE}.log
        done

        # Add core files to ZIP
        for core in ${cores[@]:0:$numberOfCoresTobeArchive}; do echo $core; done | zip ${HPCC_CORE_ARCHIVE} -@ >> ${HPCC_CORE_ARCHIVE}.log
        
        # Addd binaries
        for comp in ${componenets[@]}; do echo "$PR_ROOT/$TARGET_DIR/opt/HPCCSystems/bin/${comp}"; done | zip ${HPCC_CORE_ARCHIVE} -@ >> ${HPCC_CORE_ARCHIVE}.log
        
        # Add trace files to ZIP
        find $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/ -iname '*.trace' -type f -print | zip ${HPCC_CORE_ARCHIVE} -@ >> ${HPCC_CORE_ARCHIVE}.log
        
        find $PR_ROOT/$TARGET_DIR/var/lib/HPCCSystems/ -iname '*.trace' -type f -print -exec cp '{}' $PR_ROOT/. \;

        echo 'Done.' >> ${HPCC_CORE_ARCHIVE}.log
        WritePlainLog "Done." "$logFile"

    else
        WritePlainLog "There is no core file in /var/lib/HPCCSystems/" "$logFile"

        #echo "There is no core file in /var/lib/HPCCSystems/" >> ${HPCC_CORE_ARCHIVE}.log
        #echo "-----------------------------------------------------------" >> ${HPCC_CORE_ARCHIVE}.log
        #echo " " >>${HPCC_CORE_ARCHIVE}.log
    fi

    WritePlainLog "Store trace file(s) from ${TEST_LOG_DIR} into the relatted ZAP file " "$logFile"
    pushd ${PR_ROOT}/HPCCSystems-regression/log 

    res=$( find . -iname 'W20*.trace' -type f -print | tr -d './' | tr '-' ' ' | awk {'print $1"-"$2'} | while read myid; do  find ../zap/ -iname 'ZAPReport_'"$myid"'_*.zip' -type f -print  | while read zap; do echo "id:${myid}, zap:$zap"; zip -u $zap $myid*.trace; done ; done; )
    WritePlainLog "res: ${res}" "$logFile"

    res=$( find . -iname 'W20*.trace' -type f -print | tr -d './' | tr '-' ' ' | awk {'print $1"-"$2"-"$3'} | while read myid; do  find ../zap/ -iname 'ZAPReport_'"$myid"'_*.zip' -type f -print  | while read zap; do echo "id:${myid}, zap:$zap"; zip -u $zap $myid*.trace; done ; done; )
    WritePlainLog "res: ${res}" "$logFile"

    popd
    WritePlainLog "Done." "$logFile"
    
    # Only for debug purpose
    #zip ${HPCC_LOG_ARCHIVE} -r ${PR_ROOT}/${TARGET_DIR}/var/lib/HPCCSystems/myeclagent/temp/* >> $logFile 2>&1

    zip ${HPCC_LOG_ARCHIVE} ${PR_ROOT}/build/esp/src/eclwatch_build_*.txt >> $logFile 2>&1
    zip ${HPCC_LOG_ARCHIVE} -r ${PR_ROOT}/build/esp/src/build/*.txt >> $logFile 2>&1

    # We are not install packageso don't need to uninstall
#    if [ -f $TARGET_DIR/opt/HPCCSystems/sbin/complete-uninstall.sh ]
#    then
#        sudo /opt/HPCCSystems/sbin/complete-uninstall.sh 
#        echo "HPCC Uninstall: OK"
#        echo "HPCC Uninstall: OK" >> $logFile 2>&1
#        if [ -f "/etc/HPCCSystems/environment.xml" ]
#        then
#            echo "Remove environment.conf and .xml"
#            echo "Remove environment.conf and .xml" >> $logFile 2>&1
#            sudo rm -f '/etc/HPCCSystems/environment.*'
#            
#            if [ -f "/etc/HPCCSystems/environment.xml" ]
#            then
#                echo "  Failed."
#                echo "  Failed." >> $logFile 2>&1
#            else
#                echo "  Success."
#                echo "  Success." >> $logFile 2>&1
#            fi
#        fi
#    else
#        echo "HPCC Uninstall: failed"
#        echo "HPCC Uninstall: failed" >> $logFile 2>&1
#    fi
    # However we need to stop HPCC
    hpccRunning=$( $TARGET_DIR/etc/init.d/hpcc-init status | grep -c "running")
    WritePlainLog "Local $hpccRunning running components" "$logFile"
    if [[ $hpccRunning -ne 0 ]]
    then
        #~/hpcc/etc/init.d/hpcc-init status | cut -s -d' '  -f1
        WritePlainLog "Stop local HPCC System..." "$logFile"
        res=$( $TARGET_DIR/etc/init.d/hpcc-init stop |grep 'still')

        # If the result is "Service dafilesrv, mydafilesrv is still running."
        if [[ -n $res ]]
        then
            WritePlainLog "res: $res" "$logFile"
            $TARGET_DIR/etc/init.d/dafilesrv stop
        fi
        # give it some time
        #sleep 5

        hpccRunning=$( $TARGET_DIR/etc/init.d/hpcc-init status | grep -c "running")
        if [[ $hpccRunning -ne 0 ]]
        then
            WritePlainLog "$hpccRunning local components are still up!" "$logFile"
            exit -1
        else
            WritePlainLog "All local components are down!" "$logFile"
        fi
    else
        WritePlainLog "Local HPCC System already stopped." "$logFile"
    fi

    WritePlainLog "Remove Cassandra leftovers." "$logFile"
    sudo rm -rf /var/lib/cassandra/*
    sudo rm -r /var/log/cassandra
    WritePlainLog "Done." "$logFile"
 
else
    WritePlainLog "Build: failed!" "$logFile"
    echo "Build: failed" > ../build.summary
    
    CheckResult "$logFile"
    CheckEclWatchBuildResult "$logFile"
    ReportTimes "$logFile"

    exit 1
fi

WritePlainLog "ReportTimes." "$logFile"
ReportTimes "$logFile"

WritePlainLog "All done." "$logFile"
