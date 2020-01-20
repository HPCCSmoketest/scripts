#!/bin/bash

WriteLog()
(
    #set -x
    IFS=$'\n'
    text=$1
    text="${text//\\n/ $'\n'}"
    text="${text//\\t/ $'\t'}"
    echo "$text" | while read i
    do
        TIMESTAMP=$( date "+%Y-%m-%d %H:%M:%S")
        printf "%s: %s\n" "${TIMESTAMP}" "$i"
        if [ "$2." == "." ]
        then
            echo ${TIMESTAMP}": ERROR: WriteLog() target log file name is empty!"
        else 
            echo -e "${TIMESTAMP}: $i" >> $2
        fi
    done
    unset IFS
    #set +x
)
