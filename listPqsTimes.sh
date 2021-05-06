while read line; do echo $line; done < <(egrep '^Cores|^Speed|Suite:| Queries:|Elapsed|--pq|Test time' PR-14901/RelWithDebInfo_Build_2021-04-30_11-48-00.log | egrep -v 'setup' )
