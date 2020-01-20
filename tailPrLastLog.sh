#!/bin/bash

if [[ "$1" == "" ]]
then
    echo "Missing PR"

else
    param=$1
    PR=${param^^}

    regex1='^[Pp][Rr]-[1-9][0-9]*$'
    regex2='^[1-9][0-9]*$'

    # If full PR id like PR-99999
    if [[ $PR =~ $regex1 ]]
    then 
        echo "$PR is ok"
    else 
        # if only the PR's ID like 99999
        if [[ $PR =~ $regex2 ]]
        then 
            #echo "$PR is ok"
            PR='PR-'$PR
        fi
    fi

    # Is it exists?
    if [[ -d ${PR} ]]
    then
        tryDelay=10  # sec
        tryCount=$(( 180 / $tryDelay )) # Try it for 180 sec 
        # Get the latest one
        LAST_LOG_NAME=$( ls -1t ${PR}/Rel* | head -n 1 )
        while [[ "${LAST_LOG_NAME}" == ""  && tryCount -gt 0 ]]
        do
            tryCount=$(( $tryCount - 1 ))
            sleep ${tryDelay}
            LAST_LOG_NAME=$( ls -1t ${PR}/Rel* | head -n 1 )
        done
        
        if [[ "${LAST_LOG_NAME}" == "" ]]
            then
                echo "${PR} build log not found!"
                
            else
                tail -f -n 200 ${LAST_LOG_NAME}
            fi
    else
        echo "${PR} not found!"
    fi
fi

