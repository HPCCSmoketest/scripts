#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

usage ()
{
    echo "Tool to list Executed Smoketest session(s) on a current or give date"
    echo "Usage:"
    echo ""
    echo "./listTests/sh [yy-mm-dd] [-rte] [-v] [-h]"
    echo ""
    echo "Where [yy-mm-dd]  The date for list tests"
    echo "      -v          Verbose, list log filename and log entry for the test"
    echo "      -h          This help"
    echo "      -rte        List changes in RTE."
    echo ""
}

testDay=$( date "+%y-%m-%d")
verbose=0
rte=0
while [ $# -gt 0 ]
do 
    param=$1
    #param=${param//-/}
    param=${param#-}
    case $param in
        v) verbose=1
        ;;
        h) usage
            exit
            ;;
        [0-9][0-9]-[[0-9][0-9]-[0-9][0-9]) testDay=$param
            ;;
        rte) rte=1
            ;;
        *)
            ;;
    esac
    shift
done

[[ ! -d ~/smoketest/ScheduleInfos ]] && mkdir -p ~/smoketest/ScheduleInfos

if [[ -d ~/smoketest/ScheduleInfos ]]
then
    find OldPrs/PR-*/ PR-*/ -mtime -1 -iname 'scheduler-*.test' -o -iname 'result*.log' | zip -u ScheduleInfos/Smoketest-logs.zip -@

#    pushd ~/smoketest/ScheduleInfos; 
#    rsync -va ../PR-*/scheduler-*.test ../PR-*/result*.log . ; 
#    rsync -va ../OldPrs/PR-*/scheduler-*.test ../OldPrs/PR-*/result*.log . ; 
#
#    echo "-----------------------------------------"; 
#    echo "List of scheduled test:"; 
#    echo ""; 
#
#    find . -iname 'scheduler-'"$testDay"'*.test' -exec /usr/bin/bash -c "cat '{}' |  egrep -i 'Instance name|Commit Id|Instance Id' | cut -d' ' -f5 | tr -d \' | paste -d, -s - | cut -d',' -f1,2,3 --output ', ' | awk -F \",\" '{ print $3 }' " \; ;
#    popd > /dev/null
fi

clear

echo "Tests on $(date -d ${testDay} +%A), $testDay:"; 
echo "-----------------------------------------"; 
echo ""

echo "List of Skipped tests:"; 
echo "======================"

dayInSec=$(( 3600 * 24 ))
testDayOffset=$(( ( $(date "+%s") / $dayInSec ) - ( $(date --date "$testDay 12:30" "+%s" ) / $dayInSec ) ))
[[ $verbose -eq 1 ]] && (echo "testDayOffset: $testDayOffset"; echo "")

res=$( find OldPrs/PR-*/ PR-*/ -daystart -mtime $testDayOffset -iname 'build.summary' -exec egrep -H -i 'skipped' {} \; | sed -e 's/OldPrs\/P\(.*\)$/P\1\/(closed)/'   -e 's/draft\(.*\)/\/(draft)/'  | awk -F '/' '{print $1 $3 }' | sort )

if [[ -n "$res" ]]
then
    echo "$res"
else
    echo "None"
fi
echo "-----------------------------------------"; 
echo ""
echo "List of scheduled test:"; 
echo "======================="

declare -a PRs
#PRs=("test")
#res=$( find OldPrs/PR-*/ PR-*/ -iname 'scheduler*-'"$testDay"'*.test' -exec bash -c "cat '{}' |  egrep -i 'Instance name|Commit Id|Instance Id|An error' | cut -d' ' -f5 | tr -d \' | paste -d, -s - | cut -d',' -f1,2,3 --output ', ' | awk -F \",\" '{ print $3 }' " \; )
cnt=0
#find OldPrs/PR-*/ PR-*/ -iname 'scheduler-'"$testDay"'*.test' -print | while read fn

while read fn
do  
    cnt=$(( $cnt + 1 ))
    #echo "$fn"
    #set -x
    version=1
    item=$(cat $fn | egrep -i 'Instance name|Commit Id|Instance Id' | cut -d' ' -f5 | tr -d \' | paste -d, -s - | cut -d',' -f1,2,3 --output ',' )
    #item=$(cat $fn | egrep -i 'Param: (Instancename|CommitId)|Instance Id' | cut -d' ' -f4,5 | tr -d \' | tr '=' ' ' | cut -d' ' -f 2 | paste -d, -s - | cut -d',' -f1,2,3 --output ',' )

    [[ -z "$item" ]] && ( item=$( cat $fn | egrep -i 'Instancename: |CommitId: |:Instance Id|An error' | cut -d' ' -f4,6 | tr -d \' | sed 's/commitId=//' | paste -d, -s - | cut -d',' -f1,2,3 --output ', ' ); version=2 )
    [[ -z "$item" ]] && ( item=$( cat $fn | egrep -i 'Schedule |sha ' | cut -d ' ' -f1,2,3,4,5 | tr -d \' | tr -d ':' | tr -s ' \t' | paste -d, -s -  ); version=2 )
    
    #timestamp=$( cat $fn | egrep 'Start:' | tr -d '\t' )
    timestamp=$( head -n 1 $fn |  cut -d: -f1,2,3 )
    #echo "$cnt, $item ($timestamp)"
    
    IFS=',' read -ra arr <<< "$item"
    #echo "${arr[@]}"
    unset -v IFS # restore IFS to default

    if [[ $version -eq 1 ]]
    then
        [[ -z "${arr[1]}" ]] && arr[1]=$(dirname $fn)

        printf "%s, %s, %s, %s" "$cnt" "${arr[1]}" "${arr[2]}" "${arr[0]}"

        a=("${arr[0]}" "${arr[1]}" "${arr[2]}")
	
    else
        [[ -z "${arr[1]}" ]] && arr[1]=$(dirname $fn)

        printf "%s, %s, %s, %s" "$cnt" "${arr[1]}" "${arr[2]}" "${arr[0]}"

        a=( "${arr[1]}" "${arr[2]}" "${arr[0]}" )

    fi

    [[ "$fn" =~ "OldPrs" ]] && printf ", (Closed)" || ( running=$(  egrep -i -c 'Terminate:' $fn ); [[ $running -eq 0 ]] && printf ", (Running)" || printf ", (Finished)")

    [[ $verbose -eq 1 ]] && printf ", %s, ( %s )" "$timestamp" "$version"
    printf "\n"
    PRs+=( a[@] )

    set +x
#done < <(find OldPrs/PR-*/ PR-*/ -iname 'scheduler-'"$testDay"'*.test' -print | sort )
done < <(find OldPrs/PR-*/ PR-*/ -iname 'instance-*-*-'"$testDay"'_*.info' -print | sort  --field-separator='-' --key=1,1 --key=4,4 --key=8.4n,8 )

#[[ $cnt -eq 0 ]] && echo "None"
#[[ -n "$res" ]] && echo "$res" || echo "None"

echo "-----------------------------------------"
echo ""
echo "List of results:"; 
echo "================"
echo ""
echo "From closed PRs:"
echo "................"

#res=$( find OldPrs/PR-*/ -iname 'result-'"$testDay"'*.log' -type f -printf "\n" -print -exec bash -c "egrep '\s+Process PR-|\s+sha\s+:|\s+Summary\s+:|\s+pass :' '{}' | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed 's/ : /: /g' | sed -e 's/ : /: /' -e 's/,\(\s*\)/, /g' " \; )
#[[ -n "$res" ]] && echo "$res" || echo "None"
cnt=0
fns=( $( find OldPrs/PR-*/ -iname 'result-'"$testDay"'*.log' -type f  -print  | sort ) )
for fn in ${fns[@]}
do
    cnt=$(( $cnt + 1 ))
    #                                                                                                            remove tabs, multi spaces   put all in one    remove leading spaces                  remove second PR num and label            truncate commit id to 8 chars and reassemble the  record
    item=$(egrep '\s+Process PR-|\s+sha\s+:|\s+Summary\s+:|\s+pass :|In PR-' $fn | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed -e 's/ : /: /' -e 's/,\(\s*\)/, /g' -e 's/In PR-[0-9]* , label: [a-zA-Z0-9]* : //g' -e 's/^[0-9]*\/[0-9]*\.\s//g' | sed -r 's/(.*) ((sha: \w{8,8})([a-zA-Z0-9]+)), (.*)/\1 \3, \5/' )

    timestamp=$( egrep 'Finished:' $fn | tr -d '\t' | cut -d ' ' -f 1,2,3 | tr -d ',' )
    [[ -z "$item" ]] && echo -e "$fn\n\tNONE" ||  printf "%s, %s" "$cnt" "$item";  [[ $verbose -eq 1 ]] && printf " ( %s) " "$timestamp";  printf "\n"
done
[[ ${#fns[@]} -eq 0 ]] && echo "None"
    
echo ""

echo "From open PRs:"
echo ".............."
#res=$( find PR-*/ -iname 'result-'"$testDay"'*.log' -type f -printf "\n" -print -exec bash -c "egrep '\s+Process PR-|\s+sha\s+:|\s+Summary\s+:|\s+pass :' '{}' | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed 's/ : /: /g' | sed -e 's/ : /: /' -e 's/,\(\s*\)/, /g' " \; )
#[[ -n "$res" ]] && echo "$res" || echo "None"
cnt=0
fns=( $( find PR-*/ -iname 'result-'"$testDay"'*.log' -type f  -print | sort ) )
for fn in ${fns[@]}
do
    cnt=$(( $cnt + 1 ))
    
    item=$(egrep '\s+Process PR-|\s+sha\s+:|\s+Summary\s+:|\s+pass :|In PR-' $fn | tr -d '\t' | tr -s ' ' | paste -d, -s - | sed -e 's/ : /: /' -e 's/,\(\s*\)/, /g' -e 's/In PR-[0-9]* , label: [a-zA-Z0-9]* : //g' -e 's/^[0-9]*\/[0-9]*\.\s//g' | sed -r 's/(.*) ((sha: \w{8,8})([a-zA-Z0-9]+)), (.*)/\1 \3, \5/' )

    timestamp=$( egrep 'Finished:' $fn | tr -d '\t' | cut -d ' ' -f 1,2,3 | tr -d ',' | tr -d '\n' )
    [[ -z "$item" ]] && echo -e "$fn\n\tNONE" ||  printf "%s, %s" "$cnt" "$item";  [[ $verbose -eq 1 ]] && printf " ( %s) " "$timestamp";  printf "\n"
done

[[ ${#fns[@]} -eq 0 ]] && echo "None"

echo "-----------------------------------------"

if [[ $rte -ne 0 ]]
then
    echo ""
    echo "List of RTE changes:"; 
    echo "===================="
    echo ""
    echo "From closed PRs:"
    echo "................"
    #find OldPrs/PR-* -iname 'RelWithDebInfo_Build*' -type f -exec egrep -H 'RTE changed' '{}' \;
    find OldPrs/PR-* -iname 'prp-*' -type f -exec egrep -H ' testing/regress/(ecl-|hpcc/)' '{}' \;

    echo ""
    echo "From open PRs:"
    echo "................"
    #find PR-*/ -iname 'RelWithDebInfo_Build*' -type f -exec egrep -H 'RTE changed' '{}' \;
    find PR-*/ -iname 'prp-*' -type f -exec egrep -H ' testing/regress/(ecl-|hpcc/)' '{}' \;
    echo "................"
fi
echo ""
echo "End."

# To create one line digest with all information what we need
#unset -v IFS # restore IFS to default
#
#echo "PRs:"
#max=${#PRs[@]}
#for ((i=0; i <$max; i++))
#do
#    pr=${!PRs[$i]}
#    echo "$i -> ${pr}"
#done



