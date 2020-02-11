#!/bin/bash

SignalHandler()
{
    # run if user hits control-c or process receives SIGTERM signal
    echo "User break (Ctrl-c) or KILL!"
    
    pids=$( ps aux | grep '[p]ython ./ProcessPullRequests.py' | awk '{print $2}' )
    echo "Pids: ${pids}" 
    
    sudo kill ${pids}
}

logfile=prp-$(date +%Y-%m-%d).log
exec >> ${logfile} 2>&1

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

pids=$( ps aux | grep '[p]ython ./ProcessPullRequests.py' | awk '{print $2}' )
echo "Pids: ${pids}"
#echo "pwd:$( pwd )"

echo "At $(date "+%Y-%m-%d %H:%M:%S") " >> ${logfile} 2>&1
if [ -n "${pids}" ]
then
    echo "It is running. (${pids})"
else
    echo "It isn't running."
    echo "Start it."
    echo "Set core file name format to : core_%e.%p, where %e the name of executable and %p is its PID"
    echo 'core_%e.%p' | sudo tee /proc/sys/kernel/core_pattern

    echo "Enable core generation."
    ulimit -c unlimited

    ulimit -a

    # Update agent pid
    # get the latest ssh-* directory name
    agentdir=$( sudo ls -td1 /tmp/ssh-* | head -n 1 );

    # position independet way to get agent.xxxxx value
    agentPid=$( ls -l ${agentdir} | grep 'agent' | sed -n "s/^.*\(agent.[0-9].*\)/\1/p" )

    printf "export SSH_AUTH_SOCK=%s/%s\n" ${agentdir} $agentPid > .ssh_auth_sock.var
    cat .ssh_auth_sock.var
    . ./.ssh_auth_sock.var
    env | grep SSH_AUTH_SOCK

    echo "Start ProcessPullRequest.py..."
    unbuffer ./ProcessPullRequests.py
    
    # Remove old agent(s)
    echo "Smoketest finished. Remove old security agents"
    sudo find /tmp/ -iname 'ssh-*' -type d | egrep -v "$agentdir" | while read oldAgentDir
    do 
        oldAgentPid=$( ls -l ${oldAgentDir} | grep 'agent' | sed -n "s/^.*agent.\([0-9].*\)/\1/p" ); 
        oldAgentPid=$(( $oldAgentPid + 1 ))
        printf "Kill old agent (%s) and remove it's directory (%s)\n" $oldAgentPid $oldAgentDir
        sudo kill -9 $oldAgentPid
        sudo rm -rf $oldAgentDir
    done
    echo "Done."

    # Remove archived PRs older than 180 days from OldPrs directory to avoid
    # "No free disk space left" error

    echo "Manage Smoketest directory size"
    echo "Current:"
    df -h .
    echo " "
    du -ksch OldPrs
    echo "---------------------------------"

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
fi

