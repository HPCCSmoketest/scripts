#!/bin/bash
SHORT_DATE=$( date "+%Y-%m-%d")
while ( true ); do echo $(date); if [[ -f ./prp-${SHORT_DATE}.log ]]; then break; fi; sleep 10; done; tail -f -n 700 prp-${SHORT_DATE}.log
