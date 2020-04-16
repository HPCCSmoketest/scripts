#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x

DOCS_BUILD=0
SMOKETEST_HOME=
ADD_GIT_COMMENT=0
INSTANCE_NAME="PR-12701"
DRY_RUN=''  #"-dryRun"

while [ $# -gt 0 ]
do
    param=$1
    param=${param//-/}
    echo "Param: ${param}"
    case $param in
    
        instance*)  INSTANCE_NAME=${param//instanceName=/}
                INSTANCE_NAME=${INSTANCE_NAME//\"/}
                INSTANCE_NAME=${INSTANCE_NAME//PR/PR-}
                echo "Instance name: '${INSTANCE_NAME}'"
                ;;
                
        docs*)  DOCS_BUILD=${param}
                echo "Build docs: '${DOCS_BUILD}'"
                ;;
                
        smoketestH*) SMOKETEST_HOME=${param//smoketestHome=/}
                SMOKETEST_HOME=${SMOKETEST_HOME//\"/}
                echo "Smoketest home: '${SMOKETEST_HOME}'"
                ;;
                
        addGitC*) ADD_GIT_COMMENT=${param}
                echo "Add git comment: ${ADD_GIT_COMMENT}"
                ;;
                
        commit*) COMMIT_ID=${param}
                echo "Commit ID: ${COMMIT_ID}"
                ;;
                
        dryRun) DRY_RUN=${param}
                echo "Dry run: ${DRY_RUN}"
                ;;
                
    esac
    shift
done

if [[ -z ${DRY_RUN} ]]
then
    INSTANCE_TYPE="m4.4xlarge"      # 0.888 USD per Hour (16 Cores, 64 GB RAM)
    #INSTANCE_TYPE="m4.10xlarge"    # 2.22 USD per Hour (40 Cores, 163GB RAM)
    #INSTANCE_TYPE="m4.16xlarge"    # 3.552 USD per Hour (64 Cores, 256 GB RAM)
    instanceDiskVolumeSize=20       # GB
else
    INSTANCE_TYPE="t2.micro"
    instanceDiskVolumeSize=8        # GB    
fi


SSH_KEYFILE="~/HPCC-Platform-Smoketest.pem"
SSH_OPTIONS="-oConnectionAttempts=5 -oConnectTimeout=20 -oStrictHostKeyChecking=no"

#AMI_ID=$( aws ec2 describe-images --owners 446598291512 | egrep -i -B10 '-el7-' | egrep -i '"available"|"ImageId"' | egrep -i '"ImageId"' | tr -d "[:space:]" | cut -d":" -f2 )
AMI_ID="ami-0f6f902a9aff6d384"
SECURITY_GROUP_ID="sg-08a92c3135ec19aea"
SUBNET_ID="subnet-0f5274ec85eec91da"

echo $(date "+%y-%m-%d %H:%M:%S")": Create instance for ${INSTANCE_NAME}, type: $INSTANCE_TYPE, disk: $instanceDiskVolumeSize, build ${DOCS_BUILD}"

instance=$( aws ec2 run-instances --image-id ${AMI_ID} --count 1 --instance-type $INSTANCE_TYPE --key-name HPCC-Platform-Smoketest --security-group-ids ${SECURITY_GROUP_ID} --subnet-id ${SUBNET_ID} --instance-initiated-shutdown-behavior terminate --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$instanceDiskVolumeSize,\"DeleteOnTermination\":true,\"Encrypted\":true}}]" 2>&1 )
#retCode=$?
echo $(date "+%y-%m-%d %H:%M:%S")": Ret code: $retCode"
echo $(date "+%y-%m-%d %H:%M:%S")": Instance: $instance"

instanceId=$( echo "$instance" | egrep 'InstanceId' | tr -d '", ' | cut -d : -f 2 )
echo $(date "+%y-%m-%d %H:%M:%S")": Instance ID: $instanceId"

if [[ -z "$instanceId" ]]
then
   echo "Instance creation failed, exit"
   echo $instance > ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
   exit -1 
fi

instanceInfo=$( aws ec2 describe-instances --instance-ids ${instanceId} 2>&1 | egrep -i 'instan|status|public|volume' )
echo $(date "+%y-%m-%d %H:%M:%S")": Instance info: $instanceInfo"

instancePublicIp=$( echo "$instanceInfo" | egrep 'PublicIpAddress' | tr -d '", ' | cut -d : -f 2 )
echo $(date "+%y-%m-%d %H:%M:%S")": Public IP: ${instancePublicIp}"

volumeId=$( echo "$instanceInfo" | egrep 'VolumeId' | tr -d '", ' | cut -d : -f 2 )
echo "Volume ID: $volumeId"

tag=$( aws ec2 create-tags --resources ${instanceId} ${volumeId} \
           --tags Key=market,Value=in-house-test \
                  Key=product,Value=hpcc-platform \
                  Key=application,Value=q-and-a \
                  Key=Name,Value=${INSTANCE_NAME} \
                  Key=project,Value=smoketest \
                  Key=service,Value=s3bucket \
                  Key=lifecycle,Value=dev \
                  Key=owner_email,Value=attila.vamos@lexisnexisrisk.com \
                  Key=support_email,Value=attila.vamos@lexisnexisrisk.com \
                  Key=purpose,Value=Smoketest \
                  Key=PR,Value=${INSTANCE_NAME} \
                  Key=Commit,Value=${COMMIT_ID//commitId=/} \
        2>&1 )

echo $(date "+%y-%m-%d %H:%M:%S")": Wait ~2 minutes for initialise instance"
sleep 1m

tryCount=8
 
while [[ $tryCount -ne 0 ]] 
do
    echo $(date "+%y-%m-%d %H:%M:%S")": Check user directory"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "ls -l"

    [ $? -eq 0 ] && break

    sleep 20
    tryCount=$(( $tryCount-1 )) 

done

if [[ $tryCount -ne 0 ]] 
then

    echo $(date "+%y-%m-%d %H:%M:%S")": Upload token.dat files into smoketest directory"
    rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/token.dat centos@${instancePublicIp}:/home/centos/smoketest/

    if [ -d ${SMOKETEST_HOME}/${INSTANCE_NAME} ]
    then

        echo $(date "+%y-%m-%d %H:%M:%S")": Upload *.dat files"
        rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/${INSTANCE_NAME}/*.dat centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME}/
        
        if [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/environment.xml ]]
        then
            echo $(date "+%y-%m-%d %H:%M:%S")": Upload environment.xml file"
            rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/${INSTANCE_NAME}/environment.xml centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME}/
        fi
    fi


    echo $(date "+%y-%m-%d %H:%M:%S")": Upload init.sh"
    rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/init.sh centos@${instancePublicIp}:/home/centos/

    echo $(date "+%y-%m-%d %H:%M:%S")": Set it to executable"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "chmod +x init.sh"

    echo $(date "+%y-%m-%d %H:%M:%S")": Check user directory"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "ls -l"

    echo $(date "+%y-%m-%d %H:%M:%S")": Execute init.sh"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "~/init.sh -instanceName=${INSTANCE_NAME} ${DOCS_BUILD} ${ADD_GIT_COMMENT} ${COMMIT_ID} ${DRY_RUN}"

    echo $(date "+%y-%m-%d %H:%M:%S")": Check user directory"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "ls -l"

    if [[ ${DOCS_BUILD} -ne 0 ]]
    then
        echo $(date "+%y-%m-%d %H:%M:%S")": Check fop"
        ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "/usr/bin/fop -version"
    fi
    
    echo $(date "+%y-%m-%d %H:%M:%S")": Check Smoketest"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "ls -l ~/smoketest/"

    echo $(date "+%y-%m-%d %H:%M:%S")": Check crontab"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "crontab -l"

    if [[ -z $DRY_RUN ]]
    then
        INIT_WAIT=2m
        LOOP_WAIT=1m
    else
        INIT_WAIT=1s
        LOOP_WAIT=1m
    fi
    
    echo $(date "+%y-%m-%d %H:%M:%S")": Wait ${INIT_WAIT} before start checking Smoketest state"
    sleep ${INIT_WAIT}
    smoketestIsRunning=1
    checkCount=0
    emergencyLogDownloadThreshold=60  # minutes
    while [[ $smoketestIsRunning -eq 1 ]]
    do
        smoketestIsRunning=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "pgrep smoketest | wc -l"  2>&1 )
        if [[ $? -ne 0 ]]
        then
            # Something is wrong, try to find out what
            timeOut=$( echo "$smoketestIsRunning" | egrep 'timed out' | wc -l);
            if [[ $timeOut -eq 0 ]]
            then
                echo $(date "+%y-%m-%d %H:%M:%S")": ssh error, try again"
                smoketestIsRunning=1
            else
                echo $(date "+%y-%m-%d %H:%M:%S")": ssh timed out, chek if the instance is still running"
                isTerminated=$( aws ec2 describe-instances --filters "Name=tag:PR,Values=${INSTANCE_NAME}" --query "Reservations[].Instances[].State[].Name" | egrep -c 'terminated|stopped'  )
                if [[ $isTerminated -ne 0 ]]
                then
                    echo $(date "+%y-%m-%d %H:%M:%S")": instance is terminated, exit"
                    smoketestIsRunning=0
                    if [[ ! -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary ]] 
                    then
                        echo "Instance is terminated, exit." > ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
                    fi
                    exit -3
                else
                    echo $(date "+%y-%m-%d %H:%M:%S")": instance is still running, try again"
                    smoketestIsRunning=1
                fi
            fi
        else
            echo $(date "+%y-%m-%d %H:%M:%S")": Smoketest is $( [[ $smoketestIsRunning -eq 1 ]] && echo 'running.' || echo 'finished.')"
            
            checkCount= $(( $checkCount + 1 ))
            
            # If session run time is longger than 1.25 * average_instance_time then we need to make emergency backup form logfiles regurarly (every 1-2 -3 minutes).
            if [[ ( $checkCount -ge $emergencyLogDownloadThreshold ) && ( $(( $checkCount % 2 )) -eq 0) ]]
            then
                echo $(date "+%y-%m-%d %H:%M:%S")": This instance is running in $checkCount minutes (> $emergencyLogDownloadThreshold). Download its logs."
                rsync -va --timeout=60 --exclude=*.rpm --exclude=*.sh --exclude=*.py --exclude=*.txt --exclude=*.xml --exclude=build/* --exclude=HPCC-Platform/* -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME}/* ${SMOKETEST_HOME}/${INSTANCE_NAME}/
            fi

        fi
        
        if [[ $smoketestIsRunning -eq 1 ]]
        then
            sleep ${LOOP_WAIT}
        fi
    done

    echo $(date "+%y-%m-%d %H:%M:%S")": Check Smoketest"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "ls -l ~/smoketest/${INSTANCE_NAME}"
    
    echo $(date "+%y-%m-%d %H:%M:%S")": Smoketest finished."
    age=2 # minutes
    echo $(date "+%y-%m-%d %H:%M:%S")": Archive previous test session logs and other files older than $age minutes."
    timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
     # Move all *.log, *test*.summary, *.diff, *.txt and *.old files into a zip archive.
    # TO-DO check if there any. e.g. for a new PR there is not any file to archive
    find ${SMOKETEST_HOME}/${INSTANCE_NAME}/ -maxdepth 1 -mmin +$age -type f -iname '*.log' -o -iname '*test*.summary' -o -iname '*.diff' -o -iname '*.txt' -o -iname '*.old' | zip -m -u ${SMOKETEST_HOME}/${INSTANCE_NAME}/old-logs-${timestamp} -@

    echo $(date "+%y-%m-%d %H:%M:%S")": Compress and download result"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "zip -m /home/centos/smoketest/${INSTANCE_NAME}/HPCCSystems-regression-$(date '+%y-%m-%d_%H-%M-%S') -r /home/centos/smoketest/${INSTANCE_NAME}/HPCCSystems-regression/* > /home/centos/smoketest/${INSTANCE_NAME}/HPCCSystems-regression-$(date '+%y-%m-%d_%H-%M-%S').log 2>&1"
    ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} centos@${instancePublicIp} "rm -rf /home/centos/smoketest/${INSTANCE_NAME}/HPCC-Platform /home/centos/smoketest/${INSTANCE_NAME}/build"
    rsync -va --timeout=60 --exclude=*.rpm --exclude=*.sh --exclude=*.py --exclude=*.txt -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME} ${SMOKETEST_HOME}/
    rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" centos@${instancePublicIp}:/home/centos/smoketest/SmoketestInfo.csv ${SMOKETEST_HOME}/${INSTANCE_NAME}/SmoketestInfo-${INSTANCE_NAME}-$(date '+%y-%m-%d_%H-%M-%S').csv
    rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" centos@${instancePublicIp}:/home/centos/smoketest/prp-$(date '+%Y-%m-%d').log ${SMOKETEST_HOME}/${INSTANCE_NAME}/prp-$(date '+%Y-%m-%d')-${INSTANCE_NAME}-${instancePublicIp}.log
else
    echo $(date "+%y-%m-%d %H:%M:%S")": The try count exhausted before the instance became up and running."
    echo $(date "+%y-%m-%d %H:%M:%S")": The try count exhausted before the instance became up and running." > ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
    echo $instance >> ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
fi

echo $(date "+%y-%m-%d %H:%M:%S")": Wait 10 seconds before terminate"
sleep 10

terminate=$( aws ec2 terminate-instances --instance-ids ${instanceId} 2>&1 )
echo $(date "+%y-%m-%d %H:%M:%S")": Terminate: ${terminate}"

echo $(date "+%y-%m-%d %H:%M:%S")": Instance:"
aws ec2 describe-instances --filters "Name=tag:PR,Values=${INSTANCE_NAME}"  | egrep -i 'instan|status|public'

