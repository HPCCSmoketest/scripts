#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

echo ""
echo "Searching archived core files"


echo "In open issues:"
echo ""

MAX_AGE_IN_OPEN=2

echo -n "Check core files in open PRs in last $MAX_AGE_IN_OPEN days (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" 
then
    coresInOpen=($( find ./PR* -ctime -$MAX_AGE_IN_OPEN -iname '*-cores*.zip' -print ))

else
    coresInOpen=($( find ./PR* -iname '*-cores*.zip' -print ))
fi


if [ ${#coresInOpen[@]} -ne 0 ]
then
    echo "Number of cores:${#coresInOpen[@]}"
    echo ""
    for core in ${coresInOpen[@]}
    do
        #                   This a bit nasty thing same as the format string of AWK printf: "%'15d" 
        #                   where the single quote controll the thousand separation of the number
        #           but the shell processing the single quote and messing up
        #
        coreSize=$( ls -l $core | awk '{ printf "%'\''15d", $5 }' )

        echo "$core ( $coreSize bytes)"
    done
else
    echo "No core file generated in open PRs."
fi

echo ""
echo "----------------------------------------"


echo -n "Check closed PRs (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" 
then
    MAX_AGE=30
    echo "In closed issues in last $MAX_AGE days"
    echo ""

    coresInClosed=()
    dirs=$( find ./OldPrs/ -maxdepth 1 -ctime -$MAX_AGE -type d -iname 'PR*' -print )
    
    for p in ${dirs[@]}
    do

        coresInClosed+=($( find $p -iname '*-cores*.zip' -print ))

    done

    if [ ${#coresInClosed[@]} -ne 0 ]
    then
        echo "Number of cores:${#coresInClosed[@]}"
        echo ""
        for core in ${coresInClosed[@]}
        do
            coreSize=$( ls -l $core | awk '{ printf "%'\''15d", $5 }' )
            echo "$core ( $coreSize bytes)"
        done
    fi
    
    echo "----------------------------------------"

else
    echo "No."
fi

echo "End."
