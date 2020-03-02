#!/bin/bash


LOG_DIR=$(pwd)
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
DISK_SPACE_LOG_FILE=${LOG_DIR}/diskspace-${LONG_DATE}.log
MEM_SPACE_LOG_FILE=${LOG_DIR}/memspace-${LONG_DATE}.log
HEADER_ON_EVERY_LINES=30
DELAY=1  #sec

#
#-----------------------------------------
#
# Functions

. ./timestampLogger.sh

ControlC()
# run if user hits control-c
{
  echo "\n*** KILL signal recived! Exiting ***\n"
  WriteLog "End." "${DISK_SPACE_LOG_FILE}"
  WriteLog "End." "${MEM_SPACE_LOG_FILE}"

  exit $?
}

WriteHeaders()
{
    # Print disk space header
    header1=$(df -h . | egrep "^(Filesystem)" | tr '\n' ' ')
    header2=$(df -hP . | egrep "^(Filesystem)" | tr '\n' ' ')
    header="${header1}    ${header2}"

    WriteLog "${header}" "${DISK_SPACE_LOG_FILE}"

    # Print memory space header
    header=$(free | egrep "^(\s)" | tr '\n' ' ')
    WriteLog "${header}" "${MEM_SPACE_LOG_FILE}"
}
#
#-----------------------------------------
#
# Main start

WriteLog "Disk space logger started." "${DISK_SPACE_LOG_FILE}"
WriteLog "Memory space logger started." "${MEM_SPACE_LOG_FILE}"

# trap keyboard interrupt (control-c)
trap ControlC SIGINT
trap ControlC SIGTERM
trap ControlC SIGKILL

WriteHeaders

#lineCount=0

while true
do 
    #if [[ ${lineCount} -eq 0 ]]
    #then
    #    WriteHeaders
    #fi

    #lineCount=$(( ${lineCount} + 1))
    #if [[ ${lineCount} -eq ${HEADER_ON_EVERY_LINES} ]]
    #then
    #    #lineCount=0
    #fi  

    myDs1=$(df -lh  . | egrep "^(/dev/)" | tr '\n' ' ')

    # On our testfarm /var/lib located on other partition/disk
    myDs2=$(df -Ph  /var/lib | egrep "^(/dev/)" | tr '\n' ' ')

    myDs="${myDs1}    ${myDs2}"

    WriteLog "${myDs}" "${DISK_SPACE_LOG_FILE}"
 
    myMem=$( free | egrep "^(Mem|Swap)" | tr '\n' ' ')
    WriteLog "${myMem}" "${MEM_SPACE_LOG_FILE}"

    sleep ${DELAY}
done

