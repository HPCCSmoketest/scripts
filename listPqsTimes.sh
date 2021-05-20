#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

#engine=''
#hthor_queries=''
debug=0

printf "engine,pq,queries,elaps,engine,pq,queries,elaps,engine,pq,queries,elaps,test,summary\n"
while read fn
do
    echo $fn
    while read line; 
    do 
        
    #    echo $line;
        
        if [[ "$line" =~ "Test" ]]
        then 
            testTime=$( echo "$line" |  sed 's/Test time\s*:\s*//g'  | awk '{print $1 }' );
            [[ "$debug" -ne 0 ]] && echo "test:$testTime"
            continue
        fi
        
        if [[ "$line" =~ "Summary" ]]
        then 
            summaryTime=$( echo "$line" |  sed 's/Summary\s*:\s*//g'  | awk '{print $1 }' );
            [[ "$debug" -ne 0 ]] && echo "summary:$summaryTime"
            continue
        fi
        
        if [[ "$line" =~ "-t hthor" ]]
        then 
            engine="hthor"
            hthor_pq=$( echo $line | sed -n 's/^\(.*\) --pq \(.*\)$/\2/p' )
            [[ "$debug" -ne 0 ]] && echo "engine: $engine, pq: $hthor_pq"
            continue
        fi
        
        if [[ "$line" =~ "-t thor" ]]
        then 
            engine="thor"
            thor_pq=$( echo $line | sed -n 's/^\(.*\) --pq \(.*\)$/\2/p' )
            [[ "$debug" -ne 0 ]] && echo "engine: $engine, pq: $thor_pq"
            continue
        fi
        
        if [[ "$line" =~ "-t roxie" ]]
        then 
            engine="roxie"
            roxie_pq=$( echo $line | sed -n 's/^\(.*\) --pq \(.*\)$/\2/p' )
            [[ "$debug" -ne 0 ]] && echo "engine: $engine, pq: $roxie_pq"        
            continue
        fi
        
        if [[ "$line" =~ "Queries" ]]
        then 
            varName="${engine}_queries"
            queries=$( echo "$line" |  awk -F ':' '{ print $2 }' )
            declare "$varName"=${queries// /}
            [[ "$debug" -ne 0 ]] && echo "queries:${!varName}"
            continue
        fi
        
        if [[ "$line" =~ "Elapsed" ]]
        then 
            elaps=$( echo "$line" |  sed 's/Elapsed time: //g' | awk '{print $1 }' );
            varName="${engine}_elaps"
            declare "${varName}"="$elaps"
            [[ "$debug" -ne 0 ]] && echo "elaps:${!varName}"
            continue
        fi
            
    done < <(egrep '^Cores|^Speed| Queries:|Elapsed|--pq|Test time|Summary' $fn | grep -zoP 'ecl-test run -t hthor(?![\s\S]*ecl-test run -t hthor )[\s\S]*\z' )

    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" "hthor" "$hthor_pq" "$hthor_queries" "$hthor_elaps" "thor" "$thor_pq" "$thor_queries" "$thor_elaps" "roxie" "$roxie_pq" "$roxie_queries" "$roxie_elaps"  "$testTime" "$summaryTime"
    
done < <(find PR-*/ -iname 'RelWithDebInfo_Build_*' -type f -print | sort )

echo "$ENV" |  egrep 'hthor|thor|roxie'
