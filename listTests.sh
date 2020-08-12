#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

clear

if [[ -n $1 ]]
then
    testDay=$1
else
    testDay=$( date "+%y-%m-%d")
fi

echo "Tests on $testDay :"; 

#if [[ -d ~/smoketest/ScheduleInfos ]]
#then
#    pushd ~/smoketest/ScheduleInfos; 
#    rsync -va ../PR-*/scheduler-*.test . ; 
#    rsync -va ../OldPrs/PR-*/scheduler-*.test . ; 
#
#    echo "-----------------------------------------"; 
#    echo "List of scheduled test:"; 
#    echo ""; 
#
#    find . -iname 'scheduler-'"$testDay"'*.test' -exec /usr/bin/bash -c "cat '{}' |  egrep -i 'Instance name|Commit Id|Instance Id' | cut -d' ' -f5 | tr -d \' | paste -d, -s - | cut -d',' -f1,2,3 --output ', ' | awk -F \",\" '{ print $3 }' " \; ;
#    popd > /dev/null
#    
#fi
find OldPrs/PR-*/ PR-*/ -iname 'scheduler*-'"$testDay"'*.test' -exec /usr/bin/bash -c "cat '{}' |  egrep -i 'Instance name|Commit Id|Instance Id' | cut -d' ' -f5 | tr -d \' | paste -d, -s - | cut -d',' -f1,2,3 --output ', ' | awk -F \",\" '{ print $3 }' " \;

echo "-----------------------------------------"


pushd ~/smoketest; 

echo "From closed PRs:"
echo "................"
find OldPrs/PR-*/ -iname 'result*-'"$testDay"'*.log' -type f -printf "\n" -print -exec /usr/bin/bash -c "egrep '\s+Process PR-|\s+sha\s+:|\s+Summary\s+:|\s+pass :' '{}' | tr -d '\t' | tr -s ' ' | paste -d, -s - " \;
echo ""

echo "From open PRs:"
echo ".............."
find PR-*/ -iname 'result*-'"$testDay"'*.log' -type f -printf "\n" -print -exec /usr/bin/bash -c "egrep '\s+Process PR-|\s+sha\s+:|\s+Summary\s+:|\s+pass :' '{}' | tr -d '\t' | tr -s ' ' | paste -d, -s - " \; ;

echo "-----------------------------------------"

popd
echo "End."



