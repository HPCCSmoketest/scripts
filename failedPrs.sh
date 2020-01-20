#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

usage()
{
    echo ""
    echo "Usage:"
    echo "$0 [ yest[erday] | -<days_before_today> ]"
    echo ""
    echo "Without parameter is shows PRs failed today."
    echo "With parameter it shows failed PRs on that day (yesterday or n days ago)."
    echo ""
    echo "End."
    exit
}

today=$( date "+%Y-%m-%d")

if [[ "$1." == "." ]]
then
    day=$today
else
    param=$1
    upperParam=${param^^}
    # echo "Param: ${upperParam}"
    case $upperParam in

	YEST*) day=$( date -I -d "$today - 1 day" )
		 ;;

	-[0-9]*)  day=$( date -I -d "$today - ${param//-/} day" )
		 ;;

	-[hH])   usage
                 ;;

        *)       usage
		 ;;

    esac
fi

logFileName="prp-${day}.log"

echo "Today is: ${today}"
echo ""

if [[ -f ${logFileName} ]]
then
    echo "Failed PRs on ${day}:"
    cat prp-${day}.log | egrep '^([0-9]*)/([0-9]*)\. Process|wait|^(\s*)sha|^(\s*)base|^(\s*)user|HPCC Star|^(\s*)start|^(\s*)end|^(\s*)pass|scheduled|done, exit' | egrep -i -B7 'pass : False' | egrep 'PR-' | sed -n 's/^\(.*\)\s\(PR-[0-9].*\),\(.*\)$/    \2/p' | sort -u
else
    echo "We have not log file for ${day}. Try it in the log achive."
fi

echo "End."
