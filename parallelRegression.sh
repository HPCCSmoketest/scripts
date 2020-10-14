#!/bin/bash

echo "Start $0"

pushd HPCC-Platform/testing/regress

TIME_STAMP=$(date +%s)

echo "Start hthor regression ..."
exec ./ecl-test run -t hthor --ef pipefail.ecl -e=embedded,3rdparty,python2 --loglevel info --timeout -1 --pq 4 --generateStackTrace &

echo "Start thor regression..."
exec ./ecl-test run -t thor --ef pipefail.ecl -e=embedded,3rdparty,python2 --loglevel info --timeout -1 --pq 5 --generateStackTrace --timeout 900 -fthorConnectTimeout=36000 &

echo "Start roxie regression..."
exec ./ecl-test run -t roxie --ef pipefail.ecl -e=embedded,3rdparty,python2 --loglevel info --timeout -1 --pq 4 --generateStackTrace &

echo "Wait for processes finished."

wait 

echo "All processes are finished in $(( $(date +%s) - $TIME_STAMP )) sec"

popd

