#!/bin/bash

echo "Start $0"

pushd HPCC-Platform/testing/regress

TIME_STAMP=$(date +%s)

echo "Start hthor setup..."
exec ./ecl-test setup -t hthor --loglevel info --timeout 720 --pq 4 --generateStackTrace &

echo "Start thor setup..."
exec ./ecl-test setup -t thor --loglevel info --timeout 720 --pq 5 --generateStackTrace &

echo "Start roxie setup..."
exec ./ecl-test setup -t roxie --loglevel info --timeout 720 --pq 4 --generateStackTrace &

echo "Wait for processes finished."

wait 

echo "All processes are finished in $(( $(date +%s) - $TIME_STAMP )) sec"

popd

