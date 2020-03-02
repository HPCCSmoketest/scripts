#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

DOCS_BUILD=0
SMOKETEST_HOME=
ADD_GIT_COMMENT=0
INSTANCE_NAME="PR-12701"

DRY_RUN=''  #"-dryRun"
if [[ -z ${DRY_RUN} ]]
then
    INSTANCE_TYPE="m4.4xlarge"      # 0.888 USD per Hour (16 Cores, 64 GB RAM)
    #INSTANCE_TYPE="m4.10xlarge"    # 2.22 USD per Hour (40 Cores, 163GB RAM)
    #INSTANCE_TYPE="m4.16xlarge"    # 3.552 USD per Hour (64 Cores, 256 GB RAM)
else
    INSTANCE_TYPE="t2.micro"
fi

instanceDiskVolumeSize=20
AMI_ID="ami-016bc6be662a27746"
SECURITY_GROUP_ID="sg-08a92c3135ec19aea"
SUBNET_ID="subnet-0f5274ec85eec91da"

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
                
    esac
    shift
done


echo "Create instance for ${INSTANCE_NAME}, type: $INSTANCE_TYPE, disk: $instanceDiskVolumeSize, build ${DOCS_BUILD}"

instance=$( aws ec2 run-instances --image-id ${AMI_ID} --count 1 --instance-type $INSTANCE_TYPE --key-name HPCC-Platform-Smoketest --security-group-ids ${SECURITY_GROUP_ID} --subnet-id ${SUBNET_ID} --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$instanceDiskVolumeSize,\"DeleteOnTermination\":true,\"Encrypted\":true}}]" 2>&1 )
echo "Instance: $instance"

instanceId=$( echo "$instance" | egrep 'InstanceId' | tr -d '", ' | cut -d : -f 2 )
echo "Instance ID: $instanceId"

if [[ -z "$instanceId" ]]
then
   echo "Instance creation failed, exit"
   exit -1 
fi

instanceInfo=$( aws ec2 describe-instances --instance-ids ${instanceId} 2>&1 | egrep -i 'instan|status|public|volume' )
echo "Instance info: $instanceInfo"

instancePublicIp=$( echo "$instanceInfo" | egrep 'PublicIpAddress' | tr -d '", ' | cut -d : -f 2 )
echo "Public IP: ${instancePublicIp}"

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
        2>&1 )

echo "Wait ~2 minutes for initialise instance"
sleep 1m

tryCount=4
 
while [[ $tryCount -ne 0 ]] 
do
    echo "Check user directory"
    ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no centos@${instancePublicIp} "ls -l"

    [ $? -eq 0 ] && break

    sleep 20
    tryCount=$(( $tryCount-1 )) 

done

if [[ $tryCount -ne 0 ]] 
then

    echo "Upload token.dat files into smoketest directory"
    rsync -var --timeout=60 -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" ${SMOKETEST_HOME}/token.dat centos@${instancePublicIp}:/home/centos/smoketest/

    if [ -d ${SMOKETEST_HOME}/${INSTANCE_NAME} ]
    then

        echo "Upload *.dat files"
        rsync -var --timeout=60 -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" ${SMOKETEST_HOME}/${INSTANCE_NAME}/*.dat centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME}/
        
        if [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/environment.xml ]]
        then
            echo "Upload environment.xml file"
            rsync -var --timeout=60 -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" ${SMOKETEST_HOME}/${INSTANCE_NAME}/environment.xml centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME}/
        fi
    fi


    echo "Upload init.sh"
    rsync -va --timeout=60 -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" ${SMOKETEST_HOME}/init.sh centos@${instancePublicIp}:/home/centos/

    echo "Set it to executable"
    ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no centos@${instancePublicIp} "chmod +x init.sh"

    echo "Check user directory"
    ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no centos@${instancePublicIp} "ls -l"

    echo "Execute init.sh"
    ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "~/init.sh -instanceName=${INSTANCE_NAME} ${DOCS_BUILD} ${ADD_GIT_COMMENT} ${DRY_RUN}"

    echo "Check user directory"
    ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "ls -l"

    if [[ ${DOCS_BUILD} -ne 0 ]]
    then
        echo "Check fop"
        ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "/usr/bin/fop -version"
    fi
    
    echo "Check Smoketest"
    ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "ls -l ~/smoketest/"

    echo "Check crontab"
    ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "crontab -l"

    if [[ -z $DRY_RUN ]]
    then
        INIT_WAIT=2m # minutes
    else
        INIT_WAIT=10s # 10sec
    fi
    
    echo $(date "+%y-%m-%d %H:%M:%S")": Wait ${INIT_WAIT} before start checking Smoketest state"
    sleep ${INIT_WAIT}
    smoketestRunning=1
    while [[ $smoketestRunning -eq 1 ]]
    do
        sleep 1m
        smoketestRunning=$( ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "pgrep smoketest | wc -l" )
        echo $(date "+%y-%m-%d %H:%M:%S")": Smoketest is $( [[ $smoketestRunning -eq 1 ]] && echo 'running.' || echo 'finished.')"
    done

    echo "Check Smoketest"
    ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "ls -l ~/smoketest/${INSTANCE_NAME}"
    
    echo "Smoketest finished."
    age=2 # minutes
    echo "Archive previous test session logs and other files older than $age minutes."
    timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
     # Move all *.log, *test*.summary, *.diff, *.txt and *.old files into a zip archive.
    # TO-DO check if there any. e.g. for a new PR there is not any file to archive
    find ${SMOKETEST_HOME}/${INSTANCE_NAME}/ -maxdepth 1 -mmin +$age -type f -iname '*.log' -o -iname '*test*.summary' -o -iname '*.diff' -o -iname '*.txt' -o -iname '*.old' | zip -m -u ${SMOKETEST_HOME}/${INSTANCE_NAME}/old-logs-${timestamp} -@

    echo "Compress and download result"
    ssh -i ~/HPCC-Platform-Smoketest.pem centos@${instancePublicIp} "zip -m ~/smoketest/${instanceName}/HPCCSystems-regression-$(date '+%y-%m-%d_%H-%M-%S') -r ~/smoketest/${instanceName}/HPCCSystems-regression/* > ~/smoketest/${instanceName}/HPCCSystems-regression-$(date '+%y-%m-%d_%H-%M-%S').log 2>&1"
    rsync -va --timeout=60 --exclude=*.rpm --exclude=*.sh --exclude=*.py --exclude=*.txt -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" centos@${instancePublicIp}:/home/centos/smoketest/${INSTANCE_NAME} ${SMOKETEST_HOME}/
    rsync -va --timeout=60 -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" centos@${instancePublicIp}:/home/centos/smoketest/SmoketestInfo.csv ${SMOKETEST_HOME}/${INSTANCE_NAME}/SmoketestInfo-${INSTANCE_NAME}-$(date '+%y-%m-%d_%H-%M-%S').csv
    rsync -va --timeout=60 -e "ssh -i ~/HPCC-Platform-Smoketest.pem -oStrictHostKeyChecking=no" centos@${instancePublicIp}:/home/centos/smoketest/prp-$(date '+%Y-%m-%d').log ${SMOKETEST_HOME}/${INSTANCE_NAME}/prp-$(date '+%Y-%m-%d')-${INSTANCE_NAME}-${instancePublicIp}.log

fi

echo "Wait 10 seconds before terminate"
sleep 10

terminate=$( aws ec2 terminate-instances --instance-ids ${instanceId} 2>&1 )
echo "Terminate: ${terminate}"

echo "Instance:"
aws ec2 describe-instances --filters "Name=tag:PR,Values=${instanceName}"  | egrep -i 'instan|status|public'

