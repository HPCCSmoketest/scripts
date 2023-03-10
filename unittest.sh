#!/bin/bash
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

UNITTEST_LIST_PARAMS="-l"
UNITTEST_EXEC_PARAMS="-e"
TIMEOUT=180 #90
#echo "param:'"$1"'
if [ "$1." != "." ]
then
    param=$1
    upperParam=${param^^}
    echo "Param: ${upperParam}"
    case $upperParam in
        -A|-ALL)    UNITTEST_LIST_PARAMS="-l -a "
                    UNITTEST_EXEC_PARAMS="-a -e"
                    TIMEOUT=9000
                    ;;
    esac
fi

#
#------------------------------
#
# Import settings
#
# WriteLog() function

. ./timestampLogger.sh

#
#-------------------------------
#
# Settings
#
OBT_LOG_DIR=$( pwd )
TEST_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
UNITTEST_LOG_FILE=${OBT_LOG_DIR}/unittest-$TEST_DATE.log
UNITTEST_RESULT_FILE=${OBT_LOG_DIR}/unittests.$TEST_DATE.log
UNITTEST_LAST_RESULT_FILE=${OBT_LOG_DIR}/unittests.log
UNITTEST_SUMMARY_FILE=${OBT_LOG_DIR}/unittests.summary

UNITTEST_BIN_PATH=/opt/HPCCSystems/bin
UNITTEST_LIB_PATH=/opt/HPCCSystems/lib
UNITTEST_BIN=unittests
#UNITTEST_EXCLUSION='CcdFileTest'
UNITTEST_EXCLUSION=" InplaceIndexTest "

HPCC_DATA_DIR=/var/lib/HPCCSystems/hpcc-data
HPCC_DATA_THOR_DIR=/var/lib/HPCCSystems/hpcc-data/thor

#
#-------------------------------
#
# Start unittests
#

WriteLog "Start unittests...($0)" "$UNITTEST_LOG_FILE"

#
#-------------------------------
#UNITTEST_BIN
# Check dali
#

WriteLog "Check Dali..." "$UNITTEST_LOG_FILE"
SUDO=
if [ -f hpcc/etc/init.d/hpcc-init ]
then
    HPCC_INIT_PATH="hpcc/etc/init.d"
    UNITTEST_BIN_PATH=hpcc/opt/HPCCSystems/bin
    HPCC_DATA_DIR=hpcc/var/lib/HPCCSystems/hpcc-data
    UNITTEST_LIB_PATH=hpcc/opt/HPCCSystems/lib
else
    HPCC_INIT_PATH="/etc/init.d"
    SUDO=sudo
fi

DALI_STOPPED=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali status | grep -c '[s]topped' )
if [[  ${DALI_STOPPED} -eq 1 ]]
then
    WriteLog "Dali stopped, start it." "$UNITTEST_LOG_FILE"
    DALI_STARTED=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali start | grep -c '[O]K' )
    if [[ ${DALI_STARTED} -eq 1 ]]
    then
        WriteLog "Dali started." "$UNITTEST_LOG_FILE"
    else
        WriteLog "Dali won't start. Exit." "$UNITTEST_LOG_FILE"
        exit 1
    fi
else
    WriteLog "Dali is up." "$UNITTEST_LOG_FILE"
fi


WriteLog "Start Dafilesrv." "$UNITTEST_LOG_FILE"
DAFILESRV_STOPPED=$( $SUDO ${HPCC_INIT_PATH}/dafilesrv status | grep -c '[s]topped' )
if [[ ${DAFILESRV_STOPPED} -eq 1 ]]
then
    DAFILESRV_START=$( $SUDO ${HPCC_INIT_PATH}/dafilesrv start  2>&1 )
    if [[ $? -eq 0 ]]
    then
        WriteLog "Dafilesrv started." "$UNITTEST_LOG_FILE"
    else
        WriteLog "Dafilesrv won't start.\nIt is posible some unittest will fail." "$UNITTEST_LOG_FILE"
    fi
else
    WriteLog "Dafilesrv is up." "$UNITTEST_LOG_FILE"
fi

#
#-------------------------------
#
# Check unittest binary
#

WriteLog "Check unittest binary... (${UNITTEST_BIN})" "$UNITTEST_LOG_FILE"

if [ -f ${UNITTEST_BIN_PATH}/${UNITTEST_BIN} ]
then 
    WriteLog "Unittest exists." "$UNITTEST_LOG_FILE"
else
    WriteLog "Unittest doesn't exist. Exit." "$UNITTEST_LOG_FILE"
    exit 2
fi

#
#-------------------------------
#
# Check Write/create permission of /var/lib/HPCCSystems/hpcc-data directory
#

WriteLog "Check write/create permission for ${HPCC_DATA_DIR}." "$UNITTEST_LOG_FILE"

if [ -d  ${HPCC_DATA_DIR} ]
then
    perm=$(stat -c '%a' ${HPCC_DATA_DIR})
    if [ "$perm" == "777" ]
    then
        WriteLog "It is ok." "$UNITTEST_LOG_FILE"
    else
        owner=$(stat -c '%U' ${HPCC_DATA_DIR})
        group=$(stat -c '%G' ${HPCC_DATA_DIR})
        WriteLog "I don't have (${perm} ${owner}:${group}), get it." "$UNITTEST_LOG_FILE"
        sudo chmod -R 0777 ${HPCC_DATA_DIR}
        sudo chown -R ${owner} ${group} ${HPCC_DATA_DIR}
        perm=$(stat -c '%a' ${HPCC_DATA_DIR})
        owner=$(stat -c '%U' ${HPCC_DATA_DIR})
        group=$(stat -c '%G' ${HPCC_DATA_DIR})
                
        WriteLog "Now I have: ${perm} ${owner}:${group} " "$UNITTEST_LOG_FILE"
    fi
else
    WriteLog "Not exists." "$UNITTEST_LOG_FILE"
fi


#
#-------------------------------
#
# Start WatchDog to prevent smoketest hangs up
# It should be finished in 120 sec!
DELAY=10
WATCHDOG_LOG_FILE=${OBT_LOG_DIR}/WatchDog-$(date "+%Y-%m-%d_%H-%M-%S").log

WriteLog "Start WatchDog with $TIMEOUT sec timeout and $DELAY sec delay." "$UNITTEST_LOG_FILE"
sudo unbuffer ./WatchDog.py -p unittests -t $TIMEOUT -d $DELAY >> ${WATCHDOG_LOG_FILE}  2>&1 &
echo $! > ./WatchDog.pid
WriteLog "WatchDog pid: $( cat ./WatchDog.pid )." "$UNITTEST_LOG_FILE"
#
#-------------------------------
#
# Execute unittests
#
WriteLog "Excluded testcase(s): ${UNITTEST_EXCLUSION}" "$UNITTEST_LOG_FILE"

#pushd ${UNITTEST_BIN_PATH}

TIME_STAMP=$(date +%s)

WriteLog "Execute unittests..." "$UNITTEST_LOG_FILE"

${UNITTEST_BIN_PATH}/${UNITTEST_BIN} ${UNITTEST_LIST_PARAMS} | sort | while read unittest
do 
    WriteLog "$unittest" "$UNITTEST_LOG_FILE"
    
    if [[ " ${UNITTEST_EXCLUSION[@]} " =~ " ${unittest} " ]]
    then
        WriteLog "Excluded from this session." "$UNITTEST_LOG_FILE"
        continue
    fi
    
    #result=$( sudo unbuffer ${UNITTEST_BIN} ${UNITTEST_EXEC_PARAMS} $unittest 2>&1 )
    result=$( ${UNITTEST_BIN_PATH}/${UNITTEST_BIN} ${UNITTEST_EXEC_PARAMS} $unittest 2>&1 )
    retCode=$( echo $?)
    signal=0
    if [[ $retCode > 128 ]] 
    then
        signal=$(( $retCode - 128 ))
        if [[ $signal == 11 ]]
        then
            result="Segmentation fault"
        fi
    fi
    echo "retcode:$retCode, result:$result"
    echo "retcode:$retCode" >> $UNITTEST_RESULT_FILE
    echo "retcode:$retCode" >> $UNITTEST_LOG_FILE

    IS_NOT_TIMEOUT=$( echo $result | egrep -ic "ok|run")
    if [[ $IS_NOT_TIMEOUT -eq 1 ]]
    then
        echo "${result}" >> $UNITTEST_RESULT_FILE
        WriteLog "${result}" "$UNITTEST_LOG_FILE"
    else
        case $signal in 
                                 
            11) echo "${result}" >> $UNITTEST_RESULT_FILE
                echo "Run: 1 Failures: 1 Errors: 0 Timeout: 0" >> $UNITTEST_RESULT_FILE
                echo "$unittest run segfault" >> $UNITTEST_RESULT_FILE
                WriteLog "${result} Run: 1 Failures: 1 Errors: 0 Timeout: 0" "$UNITTEST_LOG_FILE"
                WriteLog "$unittest run segfault" "$UNITTEST_LOG_FILE"
                ;;
                
            *)  echo "${result}" >> $UNITTEST_RESULT_FILE
                echo "Run: 1 Failures: 0 Errors: 0 Timeout: 1" >> $UNITTEST_RESULT_FILE
                echo "$unittest run timeout" >> $UNITTEST_RESULT_FILE
                WriteLog "${result} Run: 1 Failures: 0 Errors: 0 Timeout: 1" "$UNITTEST_LOG_FILE"
                WriteLog "$unittest run timeout" "$UNITTEST_LOG_FILE"
                ;;
        esac
    fi
done

WriteLog "Unittests finished." "$UNITTEST_LOG_FILE"

#popd

WriteLog "End." "$UNITTEST_LOG_FILE"

cp $UNITTEST_RESULT_FILE $UNITTEST_LAST_RESULT_FILE
#
#--------------------------------
#
# Proccess result
#

#For test the result processing
#UNITTEST_RESULT_FILE=${OBT_LOG_DIR}/unittest-result-2016-04-15_12-52-58.log

#set -x
TOTAL=0
PASSED=0
FAILED=0
ERRORS=0
TIMEOUT=0
summary_log=''
IFS=$'\n'
#results=($( cat ${UNITTEST_RESULT_FILE} | egrep -i '\<ok|run:|excep|[[:digit:]]+\)\stest|\-\s'  | egrep -v 'Digisign IException thrown' ))
results=("$( cat ${UNITTEST_RESULT_FILE} | egrep -i '\<ok|run:|excep|[[:digit:]]+\)\stest|\-\s|timeout'  | egrep -v 'Digisign IException thrown|iorate|RSA|ConfigMgr' ) ")

for res in ${results[@]}
#cat ${UNITTEST_RESULT_FILE} | egrep -i '^ok|Run:' | while read res
do
    echo "Res: '${res}'"
    IS_PASS=$( echo $res | grep -i -c 'ok (' )
    if [[ $IS_PASS -eq 1 ]]
    then
        RESULT=$(echo $res | grep -i 'ok (' )
        #WriteLog "Result: ${RESULT}" "$UNITTEST_LOG_FILE"
        UNIT_TOTAL=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*OK[[:space:]]*(\([0-9]*\)\(.*\)$/\1/p" )
        UNIT_PASSED=$UNIT_TOTAL
        UNIT_FAILED=0
        UNIT_ERRORS=0
        TOTAL=$(( $TOTAL + $UNIT_TOTAL))
        PASSED=$(( $PASSED + $UNIT_PASSED))
        #FAILED=$(( $FAILED + $UNIT_FAILED))   
    else
        RESULT=$( echo $res | grep -i 'Run:' )
        if [[ "$RESULT" != "" ]]
        then
            if [[ "$RESULT" =~ "Timeout" ]]
            then
                UNIT_TOTAL=$( echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
                UNIT_FAILED=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\2/p")
                UNIT_ERRORS=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\3/p")
                UNIT_TIMEOUT=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\4/p")
            else
                UNIT_TOTAL=$( echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
                UNIT_FAILED=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*$/\2/p")
                UNIT_ERRORS=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*$/\3/p")
                UNIT_TIMEOUT=0
                summary_log=${summary_log}"$res\n"
            fi
            UNIT_PASSED="$(( $UNIT_TOTAL - $UNIT_FAILED - $UNIT_ERRORS - $UNIT_TIMEOUT))"
            #WriteLog "TestResult:unit:total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT}"  "$UNITTEST_LOG_FILE"
            echo "TestResult:unittest:total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT}" > $UNITTEST_SUMMARY_FILE
            TOTAL=$(( $TOTAL + $UNIT_TOTAL))
            PASSED=$(( $PASSED + $UNIT_PASSED))
            FAILED=$(( $FAILED + $UNIT_FAILED))            
            ERRORS=$(( $ERRORS + $UNIT_ERRORS))
            TIMEOUT=$(( $TIMEOUT + $UNIT_TIMEOUT))
        else
            echo "Valami mas."
            summary_log=${summary_log}"$res\n"
        fi
    fi
done

TEST_TIME=$(( $(date +%s) - $TIME_STAMP ))

WriteLog "TestResult:unittest:total:${TOTAL} passed:${PASSED} failed:${FAILED} errors:${ERRORS} timeout:${TIMEOUT} elaps:${TEST_TIME} sec"  "$UNITTEST_LOG_FILE"
echo "TestResult:unittest:total:${TOTAL} passed:${PASSED} failed:${FAILED} errors:${ERRORS} timeout:${TIMEOUT} elaps:${TEST_TIME} sec" > $UNITTEST_SUMMARY_FILE
WriteLog "${summary_log}" "$UNITTEST_LOG_FILE"
echo -e "${summary_log}" >> $UNITTEST_SUMMARY_FILE

if [[  ${DALI_STOPPED} -eq 1 ]]
then
    WriteLog "Dali was stopped. Stop it  to restore original state." "$UNITTEST_LOG_FILE"
    DALI_STOP=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali stop | grep -c '[O]K' )
    if [[ ${DALI_STOP} -eq 1 ]]
    then
        WriteLog "Dali stopped." "$UNITTEST_LOG_FILE"
    else
        WriteLog "Dali won't stop." "$UNITTEST_LOG_FILE"
    fi
fi

if [[  ${DAFILESRV_STOPPED} -eq 1 ]]
then
    WriteLog "Stop Dafilesrv." "$UNITTEST_LOG_FILE"
    DAFILESRV_STOP=$( $SUDO ${HPCC_INIT_PATH}/dafilesrv stop | grep -c '[O]K' )
    if [[ ${DAFILESRV_STOP} -eq 1 ]]
    then
        WriteLog "Dafilesrv stopped." "$UNITTEST_LOG_FILE"
    else
         WriteLog "Dafilesrv won't stop." "$UNITTEST_LOG_FILE"
    fi
fi
wdPid=$( cat ./WatchDog.pid )
WriteLog "Kill WatchDog ((${wdPid}))." "$UNITTEST_LOG_FILE"

sudo kill ${wdPid}

while (true)
do 
    sleep ${DELAY}
    stillRunning=$( ps aux | grep -c -i '[w]atchdog.py' )

    if [[ ${stillRunning} -eq 0 ]]
    then 
        WriteLog "WatchDog (${wdPid}) finished." "$UNITTEST_LOG_FILE"
        break
    fi
    WriteLog "WatchDog (${wdPid}) is still running. Wait ${DELAY} sec and try again." "$UNITTEST_LOG_FILE"

    [ -n "$(pgrep WatchDog)" ] && sudo pkill WatchDog.py

done

rm ./WatchDog.pid

# Check if any core file generated. If yes, create stack trace with gdb

NUM_OF_UNITTEST_CORES=( $(find . -name 'core_unittests*' -type f -exec printf "%s\n" '{}' \; ) )
    
if [ ${#NUM_OF_UNITTEST_CORES[@]} -ne 0 ]
then
    WriteLog "${#NUM_OF_UNITTEST_CORES[@]} unittests core files found." "$UNITTEST_LOG_FILE"

    cp ${UNITTEST_BIN_PATH}/${UNITTEST_BIN} .

    for core in ${NUM_OF_UNITTEST_CORES[@]}
    do
        # To enable the core file will be downloadable for any user
        sudo chmod 0755 $core
        WriteLog "Generate backtrace for $core." "$UNITTEST_LOG_FILE"
        gdb --batch --quiet -ex "set interactive-mode off" -ex "thread apply all bt" -ex "quit" ${UNITTEST_BIN_PATH}/${UNITTEST_BIN} $core >> "$core.trace" 2>&1

        echo "Backtrace of $core" >> unittests.summary
        cat "$core.trace" >> unittests.summary
        echo "" >> unittests.summary

    done

    # Archive core files
    for c in ${NUM_OF_UNITTEST_CORES[@]}; do echo $c; echo $c.trace; done | zip -m "unittest-core-archive-$TEST_DATE" -@ >> "unittest-core-archive-$TEST_DATE.log"

    zip -u -m "unittest-core-archive-$TEST_DATE" ./unittests

else
    WriteLog "No core file generated." "$UNITTEST_LOG_FILE"
fi

sudo chmod -R 0777 ${HPCC_DATA_DIR}
sudo chown -R ${owner} ${group} ${HPCC_DATA_DIR}
perm=$(stat -c '%a' ${HPCC_DATA_DIR})
owner=$(stat -c '%U' ${HPCC_DATA_DIR})
group=$(stat -c '%G' ${HPCC_DATA_DIR})

WriteLog "Now I have: ${perm} ${owner}:${group} " "$UNITTEST_LOG_FILE"

WriteLog "End." "$UNITTEST_LOG_FILE"

