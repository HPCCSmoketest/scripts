#!/bin/bash


# Run in a console: 
#  while true; do clear; date "+%Y-%m-%d %H:%M:%S" ; ./showSchedulerStatus.sh ; sleep 15; done

logFile="prp-$(date +%Y-%m-%d ).log"
if [[ -n "$1" ]]
then
	logFIle=$1
fi

cd ~/smoketest; 
if [[ -f  $logFile ]]
then 
    last_entry_line=$(grep -n '^Start: ' $logFile | tail -1 | cut -d: -f1 ); 
    echo "last_entry_line:$last_entry_line"; 
    
    last_pr_line=$(grep -n '\-\-\- PR\-' $logFile | tail -1 | cut -d: -f1 ); 
    echo "last_pr_line:$last_pr_line"; 

    checkCount=5;

    while [[ ($last_pr_line -le $last_entry_line) && ( $checkCount -ne 0) ]]; 
    do 
        echo "wait 1 s"; 
        sleep 1; 
        export last_pr_line=$(grep -n '\-\-\- PR\-' $logFile | tail -1 | cut -d: -f1 ); 
        checkCount=$(( $checkCount - 1 ))
    done;  
    if [[ $checkCount -ne 0 ]]
    then
        cat $logFile | sed -n "${last_entry_line},/*/p" | egrep -v 'Build|Number|No |Add|^\n*$'
    fi
    #echo "${PIPESTATUS[*]}" 
else
    echo "No file"; 
fi
