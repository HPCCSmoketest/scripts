
usage()
{
    echo "Tool to list execution time statistic of passed test case(s)."
    echo "Usage:"
    echo ""
    echo "runtimeOf.sh <testname> [<engine>] [-v] [-h]"
    echo ""
    echo "Where -v  Verbose, list log filename and log entry for the test"
    echo "      -h  This help"
    echo ""
}


if [[ -z $1 ]]
then
    usage
else
    if [[ "$1" == "-h" ]]
    then
        usage
        exit
    fi
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
            h) usage
                exit
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

