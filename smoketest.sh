#!/bin/bash

#
#------------------------------
#

INSTANCE_ID=$( sudo ls -l /var/lib/cloud/instance | cut -d' '  -f11 | cut -d '/' -f6 )
PUBLIC_IP=$( curl http://checkip.amazonaws.com )

#
#------------------------------
#

SignalHandler()
{
    # run if user hits control-c or process receives SIGTERM signal
    echo "User break (Ctrl-c) or KILL!"
    
    pids=$( ps aux | grep '[p]ython ./ProcessPullRequests.py' | awk '{print $2}' )
    echo "Pids: ${pids}" 
    
    sudo kill ${pids}
}

CheckIfNoSessionIsRunning()
{
    checkCount=0
    delayToFinish=5 # minutes
    
    echo "Check if no session is running"
    pids=$( ps aux | grep '[p]ython ./ProcessPullRequests.py' | awk '{print $2}' )
    echo "ProcessPullRequests pid(s): ${pids}"
        
    # Wait it for stop
    while [ -n "${pids}" ]
    do  
        [ ! -f ./smoketest.stop ] && touch ./smoketest.stop   # Attempt to stop it gracefully
        
        echo "$(date "+%H:%M:%S") Wait for the current session is finished."
        if [[ $(( $checkCount % 12 )) -eq 0 ]]
        then
            echo "At $(date "+%Y.%m.%d %H:%M:%S") the previous ProcessPullRequests session is still running on ${PUBLIC_IP} with ${INSTANCE_ID}!" | mailx -s "Overlapped ProcessPullRequests sessions on $(PUBLIC_IP)" attila.vamos@gmail.com
        fi
        
        checkCount=$(( $checkCount + 1 ))
        # Give it some time to finish
        sleep 5m
        pids=$( ps aux | grep '[p]ython ./ProcessPullRequests.py' | awk '{print $2}' )
    done

    if [[ $checkCount -ne 0 ]]
    then
        echo "At $(date "+%Y.%m.%d %H:%M:%S") the previous ProcessPullRequests session finished  after $checkCount checks on ${PUBLIC_IP} with ${INSTANCE_ID}." | mailx -s "Overlapped ProcessPullRequests sessions on ${PUBLIC_IP}" attila.vamos@gmail.com
    fi
    
    echo "ProcessPullRequests is finished after $checkCount checks."
    echo "---------------------------------------------------------"
    echo ""
}


#
# -----------------------------
#
# Main 

logfile=prp-$(date +%Y-%m-%d).log 
exec >> ${logfile} 2>&1

echo "At $(date "+%Y.%m.%d %H:%M:%S") a new ProcessPullRequests session starts on ${PUBLIC_IP} with ${INSTANCE_ID} for ${testPrNo}." | mailx -s "New ProcessPullRequests sessions on ${PUBLIC_IP}" attila.vamos@gmail.com

echo "I am "$( whoami )
export PATH=$PATH:/usr/local/bin:/bin:/usr/local/sbin:/sbin:/usr/sbin:
echo "path: $PATH"

echo "Trap SIGINT, SIGTERM and SIGKILL signals"
# trap keyboard interrupt (control-c) and SIGTERM signals
trap SignalHandler SIGINT
trap SignalHandler SIGTERM
trap SignalHandler SIGKILL

#export addGitComment=0
#export runOnce=0
#export keepFiles=0
#export enableShallowClone=0
#export removeMasterAtExit=0
#export testOnlyOnePR=0
#export AVERAGE_SESSION_TIME=0.5 # hours


#echo "pwd:$( pwd )"

echo "At $(date "+%Y-%m-%d %H:%M:%S") " >> ${logfile} 2>&1

# To avoid overlapping if a session is stil running 
# and cron kicked off a new one.

CheckIfNoSessionIsRunning 

echo "Start it."
echo "Set core file name format to : core_%e.%p, where %e the name of executable and %p is its PID"
echo 'core_%e.%p' | sudo tee /proc/sys/kernel/core_pattern

echo "Enable core generation."
ulimit -c unlimited

ulimit -a

# Using GitHub token the agent magic doesn't necessary 
# Update agent pid
# get the latest ssh-* directory name
#agentdir=$( sudo ls -td1 /tmp/ssh-* | head -n 1 );

# position independet way to get agent.xxxxx value
#agentPid=$( ls -l ${agentdir} | grep 'agent' | sed -n "s/^.*\(agent.[0-9].*\)/\1/p" )

#printf "export SSH_AUTH_SOCK=%s/%s\n" ${agentdir} $agentPid > .ssh_auth_sock.var
#cat .ssh_auth_sock.var
#. ./.ssh_auth_sock.var
#env | grep SSH_AUTH_SOCK

echo "Start ProcessPullRequest.py..."
unbuffer ./ProcessPullRequests.py

echo "Smoketest finished."

# Using GitHub token the agent magic doesn't necessary
# Remove old agent(s)
#echo "Remove old security agents"
#sudo find /tmp/ -iname 'ssh-*' -type d | egrep -v "$agentdir" | while read oldAgentDir
#do 
#    oldAgentPid=$( ls -l ${oldAgentDir} | grep 'agent' | sed -n "s/^.*agent.\([0-9].*\)/\1/p" ); 
#    oldAgentPid=$(( $oldAgentPid + 1 ))
#    printf "Kill old agent (%s) and remove it's directory (%s)\n" $oldAgentPid $oldAgentDir
#    sudo kill -9 $oldAgentPid
#    sudo rm -rf $oldAgentDir
#done
#echo "Done."

# Remove archived PRs older than 180 days from OldPrs directory to avoid
# "No free disk space left" error

echo "Manage Smoketest directory size"
echo "Current:"
df -h .
echo " "
du -ksch OldPrs
echo "---------------------------------"

echo "Find and remove 'build' and ' HPCC-Platfrom' directories"

find PR-*/ -maxdepth 1 -iname 'build' -type d -print -exec rm -rf '{}' \;
find PR-*/ -maxdepth 1 -iname 'HPCC-Platform' -type d -print -exec rm -rf '{}' \;

find OldPrs/PR-*/ -maxdepth 1 -iname 'build' -type d -print -exec rm -rf '{}' \;
find OldPrs/PR-*/ -maxdepth 1 -iname 'HPCC-Platform' -type d -print -exec rm -rf '{}' \;

if [[ -z "${MAX_CLOSED_PR_KEEPING_DAYS}" ]]
then
    maxDays=30
else
    maxDays=${MAX_CLOSED_PR_KEEPING_DAYS}
fi
echo "Remove all closed PRs older than ${maxDays} days."

find OldPrs -maxdepth 1 -mtime +$maxDays -type d -print -exec rm -rf '{}' \;

echo "---------------------------------"

echo "After:"
df -h .
echo " "
du -ksch OldPrs

echo "Done."

