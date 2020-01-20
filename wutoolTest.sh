#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

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
WUTOOLTEST_EXECUTION_LOG_FILE=${OBT_LOG_DIR}/wutoolTestExecution-$(date "+%Y-%m-%d_%H-%M-%S").log
WUTOOLTEST_RESULT_FILE=${OBT_LOG_DIR}/wutoolTests.$(date "+%Y-%m-%d_%H-%M-%S").log
WUTOOLTEST_LAST_RESULT_FILE=${OBT_LOG_DIR}/wutoolTests.log
WUTOOLTEST_SUMMARY_FILE=${OBT_LOG_DIR}/wutoolTests.summary
WUTOOLTEST_BIN=/opt/HPCCSystems/bin/wutool
#WUTOOLTEST_EXCLUSION='CcdFileTest'
WUTOOLTEST_EXCLUSION=
testTargets=( "Dali" "Cassandra" )
testParams=( "DALISERVER=." )
SUDO=
#
#-------------------------------
#
# Start wutoolTests
#

WriteLog "Start wutoolTests..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

#
#-------------------------------
#WUTOOLTEST_BIN
# Check dali
#

WriteLog "Check Dali..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

if [ -f hpcc/etc/init.d/hpcc-init ]
then
    HPCC_INIT_PATH="hpcc/etc/init.d"
    WUTOOLTEST_BIN=hpcc/opt/HPCCSystems/bin/wutool
else
    HPCC_INIT_PATH="/etc/init.d"
    SUDO=sudo
fi

WriteLog "HPCC_INIT_PATH: ${HPCC_INIT_PATH}" "$WUTOOLTEST_EXECUTION_LOG_FILE"

if [[ -f ${HPCC_INIT_PATH}/hpcc-init ]]
then
    DALI_STOPPED=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali status | grep -c '[s]topped' )
    if [[  ${DALI_STOPPED} -eq 1 ]]
    then

        WriteLog "Dali stopped, start it." "$WUTOOLTEST_EXECUTION_LOG_FILE"
        DALI_STARTED=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali start | grep -c '[O]K' )
        if [[ ${DALI_STARTED} -eq 1 ]]
        then
            WriteLog "Dali started." "$WUTOOLTEST_EXECUTION_LOG_FILE"
        else
            WriteLog "Dali won't start. Exit." "$WUTOOLTEST_EXECUTION_LOG_FILE"
            exit 1
        fi
    else
        WriteLog "Dali is up." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
else
    WriteLog "HPCC Systems not installed. Exit." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    exit 1
fi
#------------------------------------------------------------
# Check Cassandra
#

WriteLog "Check Cassandra..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

#sudo rm -rf /var/lib/cassandra/*

tryCount=4
testCassandra=0
CASSANDRA_STOPPED=0
DELAY_TO_CHECK=60
# Check if Cassandra installed
if type "cqlsh" &> /dev/null
then
    unset -v JAVA_HOME

    while [[ $tryCount -ne 0 ]]
    do
        WriteLog "Try count: $tryCount" "${WUTOOLTEST_EXECUTION_LOG_FILE}"
        cassandraState=$( cqlsh -e "show version;" -u cassandra -p cassandra  2>/dev/null | grep 'Cassandra')
        if [[ -z $cassandraState ]]
        then
            WriteLog "It doesn't respond to version query. Check if it is already running." "$WUTOOLTEST_EXECUTION_LOG_FILE"
            cassandraPID=$( ps ax  | grep '[c]assandra' | awk '{print $1}' )

            if [[ -n "$cassandraPID" ]]
            then
                WriteLog "It is running (pid: ${cassandraPID}), kill it. " "$WUTOOLTEST_EXECUTION_LOG_FILE"
                sudo kill -9 ${cassandraPID}
                sleep 10
                sudo rm -rf /var/lib/cassandra/*
                CASSANDRA_STOPPED=1
            fi
 
            WriteLog "Stoped! Start it!" "${WUTOOLTEST_EXECUTION_LOG_FILE}"
            sudo cassandra > /dev/null 2>&1

            sleep $DELAY_TO_CHECK
            tryCount=$(( $tryCount-1 ))
            continue
        else
            WriteLog "It is OK!" "${WUTOOLTEST_EXECUTION_LOG_FILE}"
            testCassandra=1
            # Wait for 10 sec to Cassandra wake up
            #sleep 10
            break
        fi
    done
    if [[ $testCassandra -eq 0 ]]
    then
        WriteLog "Cassandra won't start! Skip test on it. Send Email to Agyi!" "${WUTOOLTEST_EXECUTION_LOG_FILE}"
        # send email to Agyi
        echo "Cassandra won't start!" | mailx -s "Problem with Cassandra" -u root  "attila.vamos@gmail.com"
    else
        testParams=( "DALISERVER=." "DALISERVER=. cassandraserver=127.0.0.1 entire=1 repository=1" )
    fi
else
    WriteLog "Cassandra  not installed in this sysytem! Send Email to Agyi!" "${WUTOOLTEST_EXECUTION_LOG_FILE}"
    # send email to Agyi
    echo "Cassandra  not installed in this sysytem!" | mailx -s "Problem with Cassandra" -u root  "attila.vamos@gmail.com"

fi

#
#-------------------------------
#
# Check wutoolTest binary
#

WriteLog "Check wutoolTest binary..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

if [ -f ${WUTOOLTEST_BIN} ]
then 
    WriteLog "wutool exists." "$WUTOOLTEST_EXECUTION_LOG_FILE"
else
    WriteLog "wutool doesn't exist. Exit." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    exit 2
fi

#
#-------------------------------
#
# Start WatchDog to prevent smoketest hangs up
# It should be finished in 120 sec!
TIMEOUT=180
DELAY=10
WATCHDOG_LOG_FILE=${OBT_LOG_DIR}/WatchDog-$(date "+%Y-%m-%d_%H-%M-%S").log

WriteLog "Start WatchDog with $TIMEOUT sec timeout and $DELAY sec delay." "$WUTOOLTEST_EXECUTION_LOG_FILE"
# The process name must be longer than the sricpt or any related parameter name!!!
# The simple 'wutool' inst good, because can match to this script name 'wutoolTest.sh'
# and the parameter of build.sh/ In that case WatchDog can/will kill this or the build script.
sudo unbuffer ./WatchDog.py -p 'wutool -selftest' -t $TIMEOUT -d $DELAY >> ${WATCHDOG_LOG_FILE}  2>&1 &
echo $! > ./WatchDog.pid
WriteLog "WatchDog pid: $( cat ./WatchDog.pid )." "$WUTOOLTEST_EXECUTION_LOG_FILE"
#
#-------------------------------
#
# Execute wutoolTests
#
WriteLog "Excluded testcase(s): ${WUTOOLTEST_EXCLUSION}" "$WUTOOLTEST_EXECUTION_LOG_FILE"

WriteLog "Execute wutoolTests..." "$WUTOOLTEST_EXECUTION_LOG_FILE"
echo ${testParams[@]}
WriteLog "$wutoolTest" "$WUTOOLTEST_EXECUTION_LOG_FILE"

TIME_STAMP=$(date +%s)

for (( index = 0; index < ${#testParams[@]}; index++ ))
do
    SUB_TIME_STAMP=$(date +%s)
    echo "$index -> target: ${testTargets[$index]}, param: ${testParams[$index]}"
    WriteLog "$index -> target: ${testTargets[$index]}, param: ${testParams[$index]}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    cmd="sudo unbuffer ${WUTOOLTEST_BIN} -selftest ${testParams[$index]} "
    WriteLog "cmd:${cmd}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    echo "target:${testTargets[$index]}" >> $WUTOOLTEST_RESULT_FILE
    result=$( ${cmd} 2>&1 )
    IS_NOT_TIMEOUT=$( echo "$result" | egrep -ic "ok|run|timing|terminate")
    WriteLog "IS_NOT_TIMEOUT: ${IS_NOT_TIMEOUT}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    if [[ $IS_NOT_TIMEOUT -ge 1 ]]
    then
        echo "${result}" >> $WUTOOLTEST_RESULT_FILE
        WriteLog "${result}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    else
        echo "${result}" >> $WUTOOLTEST_RESULT_FILE
        echo "Run: 1 Failures: 0 Errors: 0 Timeout: 1" >> $WUTOOLTEST_RESULT_FILE
        echo "$wutoolTest run timeout" >> $WUTOOLTEST_RESULT_FILE
        WriteLog "${result} Run: 1 Failures: 0 Errors: 0 Timeout: 1" "$WUTOOLTEST_EXECUTION_LOG_FILE"
        WriteLog "$wutoolTest run timeout" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
    SUB_TEST_TIME=$(( $(date +%s) - ${SUB_TIME_STAMP} ))
    WriteLog "\nElaps: ${SUB_TEST_TIME} sec" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    echo "Elaps: ${SUB_TEST_TIME} sec" >> $WUTOOLTEST_RESULT_FILE
done


echo "TestResult:wutoolTest:total:${TOTAL} passed:${PASSED} failed:${FAILED}" 
WriteLog "wutoolTests finished." "$WUTOOLTEST_EXECUTION_LOG_FILE"

WriteLog "End." "$WUTOOLTEST_EXECUTION_LOG_FILE"

cp $WUTOOLTEST_RESULT_FILE $WUTOOLTEST_LAST_RESULT_FILE
#
#--------------------------------
#
# Proccess result
#

#For test the result processing
#WUTOOLTEST_RESULT_FILE=${OBT_LOG_DIR}/wutoolTest-result-2016-04-15_12-52-58.log

if [[ -f ${WUTOOLTEST_SUMMARY_FILE} ]]
then
    WriteLog "Remove ${WUTOOLTEST_SUMMARY_FILE}." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    rm -f ${WUTOOLTEST_SUMMARY_FILE}
fi

#set -x
TOTAL=0
PASSED=0
FAILED=0
ERRORS=0
TIMEOUT=0
summary_log=''
target=''
elaps=''
IFS=$'\n'
results=($( cat ${WUTOOLTEST_LAST_RESULT_FILE} | egrep  'OK|Run:|target:|test:|assertion|expression|Error|Elaps' ))
for res in ${results[@]}
#cat ${WUTOOLTEST_RESULT_FILE} | egrep -i 'ok|Run:' | while read res
do
    echo "Res: '${res}'"
    IS_TARGET=$( echo $res | grep -i -c 'target' )
    if [[ $IS_TARGET -eq 1 ]]
    then
        target=$( echo $res | sed -rn "s/^target\:([[:alpha:]].*)$/\1/p" )
        continue
    fi
    
    IS_ELAPS=$( echo $res | grep -i -c 'Elaps' )
    if [[ $IS_ELAPS -eq 1 ]]
    then
        elaps=$( echo $res | sed -rn "s/^Elaps\:[[:space:]]*(.*)$/\1/p" )
        echo "<<$elaps>>"
        WriteLog "TestResult:wutoolTest(${target}):total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT} elaps:${elaps}"  "$WUTOOLTEST_EXECUTION_LOG_FILE"    
        echo "TestResult:wutoolTest(${target}):total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT} elaps:${elaps}" >> $WUTOOLTEST_SUMMARY_FILE    
        continue
    fi
    
    IS_PASS=$( echo $res | grep -c 'OK (' )
    if [[ $IS_PASS -eq 1 ]]
    then
        RESULT=$(echo $res | grep 'OK (' )
        #WriteLog "Result: ${RESULT}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
        UNIT_TOTAL=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*OK[[:space:]]*(\([0-9]*\)\(.*\)$/\1/p" )
        UNIT_PASSED=$UNIT_TOTAL
        UNIT_FAILED=0
        UNIT_ERRORS=0
        UNIT_TIMEOUT=0
        TOTAL=$(( $TOTAL + $UNIT_TOTAL))
        PASSED=$(( $PASSED + $UNIT_PASSED))
        #FAILED=$(( $FAILED + $UNIT_FAILED))   
    else
        RESULT=$( echo $res | grep -i 'Run:' )
        if [[ "$RESULT" != "" ]]
        then
            if [[ "$RESULT" =~ "Timeout" ]]
            then
                UNIT_TOTAL=$(  echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
                UNIT_FAILED=$( echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\2/p")
                UNIT_ERRORS=$( echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\3/p")
                UNIT_TIMEOUT=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/\4/p")
            else
                UNIT_TOTAL=$( echo "${RESULT}" | sed -rn "s/^[[:space:]]*Run:[[:space:]]*([0-9]*)[[:space:]]*Failures:[[:space:]]*([0-9]*)[[:space:]]*Errors:[[:space:]]*([0-9]*)[[:space:]]*$/\1/p")
                UNIT_FAILED=$(echo "${RESULT}" | sed -rn "s/^[[:space:]]*Run:[[:space:]]*([0-9]*)[[:space:]]*Failures:[[:space:]]*([0-9]*)[[:space:]]*Errors:[[:space:]]*([0-9]*)[[:space:]]*$/\2/p")
                UNIT_ERRORS=$(echo "${RESULT}" | sed -rn "s/^[[:space:]]*Run:[[:space:]]*([0-9]*)[[:space:]]*Failures:[[:space:]]*([0-9]*)[[:space:]]*Errors:[[:space:]]*([0-9]*)[[:space:]]*$/\3/p")
                UNIT_TIMEOUT=0
            fi
            UNIT_PASSED="$(( $UNIT_TOTAL - $UNIT_FAILED - $UNIT_ERRORS - $UNIT_TIMEOUT))"
            #WriteLog "TestResult:unit:total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:{$UNIT_ERRORS} timeout:${UNIT_TIMEOUT}"  "$WUTOOLTEST_EXECUTION_LOG_FILE"
            #echo "TestResult:wutoolTest:total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:{$UNIT_ERRORS} timeout:${UNIT_TIMEOUT}" > $WUTOOLTEST_SUMMARY_FILE
            TOTAL=$(( $TOTAL + $UNIT_TOTAL))
            PASSED=$(( $PASSED + $UNIT_PASSED))
            FAILED=$(( $FAILED + $UNIT_FAILED))
            ERRORS=$(( $ERRORS + $UNIT_ERRORS))
            TIMEOUT=$(( $TIMEOUT + $UNIT_TIMEOUT))  
        else
            echo "Valami mas."
            summary_log=${summary_log}"${target}:$res\n"
            continue
        fi
    fi
    #WriteLog "TestResult:wutoolTest(${target}):total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT} elaps:${elaps}"  "$WUTOOLTEST_EXECUTION_LOG_FILE"    
    #echo "TestResult:wutoolTest(${target}):total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT} elaps:${elaps}" >> $WUTOOLTEST_SUMMARY_FILE    
done

TEST_TIME=$(( $(date +%s) - $TIME_STAMP ))

WriteLog "TestResult:wutoolTest:total:${TOTAL} passed:${PASSED} failed:${FAILED} errors:${ERRORS} timeout:${TIMEOUT} elaps:${TEST_TIME}"  "$WUTOOLTEST_EXECUTION_LOG_FILE"    
#echo "TestResult:wutoolTest:total:${TOTAL} passed:${PASSED} failed:${FAILED} errors:${ERRORS} timeout:${TIMEOUT}" > $WUTOOLTEST_SUMMARY_FILE
WriteLog "${summary_log}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
echo -e "${summary_log}" >> $WUTOOLTEST_SUMMARY_FILE
#set +x

if [[  ${DALI_STOPPED} -eq 1 ]]
then
    WriteLog "Dali was stopped. Stop it  to restore original state." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    DALI_STOP=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali stop | grep -c '[O]K' )
    if [[ ${DALI_STOP} -eq 1 ]]
    then
        WriteLog "Dali stopped." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    else
        WriteLog "Dali won't stop." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
fi

if [[ ($testCassandra -eq 1) && ($CASSANDRA_STOPPED -eq 1) ]]
then
    WriteLog "Cassandra was stopped. Stop it  to restore original state." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    CASSANDRA_PID=$( ps aux | grep '[c]assandra' | awk '{ print $2 }' )
    CASSANDRA_STOP=$( sudo kill ${CASSANDRA_PID}; sleep 10;  ps aux | grep '[c]assandra' | awk '{ print $2 }' | wc -l) 
    if [[ ${CASSANDRA_STOP} -eq 0 ]]
    then
        WriteLog "Cassandra stopped." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    else
        WriteLog "Cassandra won't stop." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
    WriteLog "Remove Cassandra leftovers." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    sudo rm -rf /var/lib/cassandra
    sudo rm -r /var/log/cassandra
    
fi


wdPid=$( cat ./WatchDog.pid )
WriteLog "Kill WatchDog (${wdPid})." "$WUTOOLTEST_EXECUTION_LOG_FILE"

sudo kill ${wdPid}

while (true)
do 
    sleep ${DELAY}
    stillRunning=$( ps aux | grep -c -i '[w]atchdog.py' )

    if [[ ${stillRunning} -eq 0 ]]
    then 
        WriteLog "WatchDog (${wdPid}) finished." "$WUTOOLTEST_EXECUTION_LOG_FILE"
        break
    fi
    WriteLog "WatchDog (${wdPid}) is still running. Wait ${DELAY} sec and try again." "$WUTOOLTEST_EXECUTION_LOG_FILE"

    [ -n "$(pgrep WatchDog)" ] && sudo pkill WatchDog.py

done

rm ./WatchDog.pid

WriteLog "End." "$WUTOOLTEST_EXECUTION_LOG_FILE"

