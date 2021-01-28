if [[ -z $1 ]]
then
    echo "Tool to list passed test case(s) with execution time"
    echo "Usage:"
    echo "runtimeOf.sh <testname> [<engine>]"
else
    testName=$1
    shift
    verbose=0
    engine=''
    while [ $# -gt 0 ]
    do 
        param=$1
        param=${param//-/}
        case $param in
            v) verbose=1
            ;;
            *) engine=$param
            ;;
        esac
        shift
    done
        
    #echo "$testName"
    runCount=0
    runTimeMin=999999
    runTimeMax=0
    runTimeSum=0
  while read fn 
   do
        line=$(egrep "Pass "$testName ${fn})
        [[ $verbose -eq 1 ]] && printf "%s\n%s\n" "$fn" "$line"
        while read runTime
        do
            runCount=$(( $runCount + 1 ))
            runTimeSum=$(( $runTimeSum + $runTime))
            #[[ $verbose -eq 1 ]] && echo "$testName: $runTime sec"
            [[ $runTimeMin -gt $runTime ]] && runTimeMin=$runTime
            [[ $runTimeMax -le $runTime ]] && runTimeMax=$runTime
        done < <( echo "$line" |  sed -n 's/^\(.*\)\-\sW[0-9\-]*\s*(\(.*\) sec)*$/\2/p')
        
    done < <(find PR-*/ -maxdepth 1 -iname '*_Regress_'"$engine"'*' -type f -print)

    printf "\n%s:\ncount  :%4d \nmin    :%4d sec \nmax    :%4d sec \naverage:%4d sec\n" "$testName" "$runCount" "$runTimeMin" "$runTimeMax" "$(( $runTimeSum / $runCount ))"
fi
echo "End."

