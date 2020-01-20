#!/bin/bash

#Config git:
git config --global user.name "HPCCSmoketest"
git config --global user.email "hpccsmoketest@gmail.com"
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=3600'

# update 


#  env | grep SSH_AUTH_SOCK > .ssh_auth_sock.var


# Add crontab entries
( crontab -l; cat << CRONTAB_ENTRIES) | crontab
#  m h  dom mon dow   command
# Regular schedule of bokeh showStatus for Smoketest
0 0 * * *  cd ~/smoketest; ./startBokeh.sh

#One-off for (re)start  bokeh showStatus for Smoketest
38 18 31 05 *  cd ~/smoketest; ./startBokeh.sh


# m h  dom mon dow   command
0 0 * * * cd ~/smoketest; scl enable devtoolset-2 ./smoketest.sh

# One-off for testing
# addGitComment=0 prevent commenting
30 15 21 10 * cd ~/smoketest; export addGitComment=1; scl enable devtoolset-2 ./smoketest.sh

CRONTAB_ENTRIES
