#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x


LOG_FILE="/dev/null"

#
#------------------------------
#
# Import settings
#
# WriteLog() function

. ~/smoketest/timestampLogger.sh

res=$( declare -f -F WriteLog  2>&1 )
    
if [ $? -ne 0 ]
then
    echo "WriteLog() function is missing (${res}, cwd: $(pwd)) try to import again"
    . ~/smoketest/timestampLogger.sh
    res=$( declare -f -F WriteLog  2>&1 )
fi

WriteLog "res: ${res}" "$LOG_FILE"


#
#------------------------------
#
# Functions
#

MyExit()
{
    errorCode=$1
    errorTitle=$2
    errorMsg=$3
    instanceName=$4
    commitId=$5

    # Check if instance running
    runningInstanceID=$( aws ec2 describe-instances --filters "Name=tag:Name,Values=${instanceName}" "Name=tag:Commit,Values=${commitId}" --query "Reservations[].Instances[].InstanceId" --output text )
    publicIP=$( aws ec2 describe-instances --filters "Name=tag:Name,Values=${instanceName}" "Name=tag:Commit,Values=${commitId}" --query "Reservations[].Instances[].PublicIpAddress" --output text )
    [[ -z ${publicIP} ]] && publicIP="N/A"
    WriteLog "MyExit(): Public IP: ${publicIP}" "$LOG_FILE"
    
    if [[ -n ${runningInstanceID} ]]
    then
        terminate=$( aws ec2 terminate-instances --instance-ids ${runningInstanceID} 2>&1 )
        WriteLog "MyExit(): Terminate in instance result:\n ${terminate}" "$LOG_FILE"
        WriteLog "End." "$LOG_FILE"
    else
        WriteLog "MyExit(): Running instance ID not found." "$LOG_FILE"
        WriteLog "End." "$LOG_FILE"
    fi

    (echo "At $(date "+%Y.%m.%d %H:%M:%S") session (instance ID: ${runningInstanceID} on IP: ${publicIP}) exited with error code: $errorCode."; echo "${errorMsg}"; echo "${terminate}" ) | mailx -s "Abnormal end of session $instanceName ($commitId) on ${publicIP}" attila.vamos@gmail.com,attila.vamos@lexisnexisrisk.com

    exit $errorCode
}

CompressAndDownload()
{
    param=$1
    
    WriteLog "Compress and download HPCCSystems logs..." "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "[ -d /var/log/HPCCSystems ] && ( zip -u /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-logs-$(date '+%y-%m-%d_%H-%M-%S') -r /var/log/HPCCSystems/* > /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-logs-$(date '+%y-%m-%d_%H-%M-%S').log 2>&1 ) || echo \"There is no /var/log/HPCCSystems/ directory.\" " 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-logs-* ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    if [[ -z "$param" ]]
    then
        WriteLog "Compress and download pullRequests*.json file(s)..." "$LOG_FILE"
        res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "zip -u /home/$SSH_USER/smoketest/pullRequests-$(date '+%y-%m-%d_%H-%M-%S') /home/$SSH_USER/smoketest/pullRequests*.json > /home/$SSH_USER/smoketest/pullRequests-$(date '+%y-%m-%d_%H-%M-%S').log 2>&1 " 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"

        res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/pullRequests-* ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
    else
        WriteLog "Compress and download HPCCSystems-regression/log and zap directories ..." "$LOG_FILE"
        timeStamp="$(date '+%y-%m-%d_%H-%M-%S')"
        res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "zip -u /home/$SSH_USER/smoketest/HPCCSystems-regression-$timeStamp /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-regression/log/*  > /home/$SSH_USER/smoketest/HPCCSystems-regression-$timeStamp.log 2>&1 " 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
        res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "zip -u /home/$SSH_USER/smoketest/HPCCSystems-regression-$timeStamp /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-regression/zap/*  > /home/$SSH_USER/smoketest/HPCCSystems-regression-$timeStamp.log 2>&1 " 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"

        res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/HPCCSystems-regression-$timeStamp* ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
    
    fi
    
    WriteLog "Check and download email from Cron..." "$LOG_FILE"
    res=$(  rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/var/mail/$SSH_USER ${SMOKETEST_HOME}/${INSTANCE_NAME}/$SSH_USER-$(date '+%y-%m-%d_%H-%M-%S').mail 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
}

CreateResultFile()
{
    MSG=$1
    C_ID=$2
    RESULT_FILE=${SMOKETEST_HOME}/${INSTANCE_NAME}/result-${TIME_STAMPT}.log
    echo "${MSG}" > $RESULT_FILE
    echo "1/1. Process ${INSTANCE_NAME}, label: ${MSG}" >> $RESULT_FILE 
    echo " sha : ${C_ID} " >> $RESULT_FILE
    echo " Summary : 0 sec (00:00:00) " >> $RESULT_FILE
    echo " pass : False " >> $RESULT_FILE
}

#
#------------------------------
#
# Main
#

DOCS_BUILD=0
SMOKETEST_HOME=$(pwd)
ADD_GIT_COMMENT=0
INSTANCE_NAME="PR-12701"
DRY_RUN=''  #"-dryRun"
AVERAGE_SESSION_TIME=1.5 # Hours
TIME_STAMPT=$( date "+%y-%m-%d_%H-%M-%S" )
APP_ID=$(hostname)
BASE_TEST=''
BASE='master'
DAY_STAMPT=$( date "+%y-%m-%d" )

while [ $# -gt 0 ]
do
    param=$1
    param=${param#-}
    WriteLog "Param: ${param}" "$LOG_FILE"
    case $param in
    
        instance*)  INSTANCE_NAME=${param//instanceName=/}
                INSTANCE_NAME=${INSTANCE_NAME//\"/}
                #INSTANCE_NAME=${INSTANCE_NAME//PR/PR-}
                WriteLog "Instancename: '${INSTANCE_NAME}'" "$LOG_FILE"
                ;;
                
        docs*)  DOCS_BUILD=${param}
                WriteLog "Build docs: '${DOCS_BUILD}'" "$LOG_FILE"
                ;;
                
        smoketestH*) SMOKETEST_HOME=${param//smoketestHome=/}
                SMOKETEST_HOME=${SMOKETEST_HOME//\"/}
                WriteLog "Smoketest home: '${SMOKETEST_HOME}'" "$LOG_FILE"
                ;;
                
        addGitC*) ADD_GIT_COMMENT=${param}
                WriteLog "Add git comment: ${ADD_GIT_COMMENT}" "$LOG_FILE"
                ;;
                
        commit*) COMMIT_ID=${param}
                WriteLog "CommitID: ${COMMIT_ID}" "$LOG_FILE"
                C_ID=${COMMIT_ID//commitId=/}
                ;;
                
        dryRun) DRY_RUN=${param}
                WriteLog "Dry run: ${DRY_RUN}" "$LOG_FILE"
                ;;
                
        appId) APP_ID=${param}
                WriteLog "App ID: ${APP_ID}" "$LOG_FILE"
                ;;
                
        baseTest*) BASE_TEST=${param}
                WriteLog "Base test: ${BASE_TEST}" "$LOG_FILE"
#                BASE_TAG=${param//baseTest=/}
#                BASE_TAG=${BASE_TAG//\"/}
#                WriteLog "Execute base test with tag: ${BASE_TAG}" "$LOG_FILE"
                ;;
                
        base*) BASE=${param//base=/}
                WriteLog "Base : ${BASE}" "$LOG_FILE"
                ;;
                
        jira*) JIRA=${param//jira=/}
                WriteLog "Jira : ${JIRA}" "$LOG_FILE"
                ;;                
        
    esac
    shift
done

[[ ! -d ${SMOKETEST_HOME}/${INSTANCE_NAME} ]] && mkdir ${SMOKETEST_HOME}/${INSTANCE_NAME}

LOG_FILE="${SMOKETEST_HOME}/${INSTANCE_NAME}/instance-${INSTANCE_NAME}-${C_ID}-${TIME_STAMPT}.info"

if [[ -z ${DRY_RUN} ]]
then
   # (I hope)  Temporarily change instance type from m4.4xlarge to m4.3xlarge, based on the 
   # instance creation error from 21st of Ocober 2020
    #INSTANCE_TYPE="m4.4xlarge"      # 0.888 USD per Hour (16 Cores, 64 GB RAM)
    INSTANCE_TYPE="m4.2xlarge"      # 0.444 USD per Hour (8 Cores, 32 GB RAM)
    AVERAGE_SESSION_TIME=1.2         # Hours for m4.2xlarge instance

    # An experiment from 2020-10-29
    INSTANCE_TYPE="m5.4xlarge"      # 0.856 USD per Hour (16 Cores, 3.1GHz, 64 GB RAM)
    AVERAGE_SESSION_TIME=0.75       # Hours for m5.2xlarge instance
    
    # An experiment from 2021-10-05 in one-off test it was 11 minutes slower than same PR with m5.4xlarge
    #INSTANCE_TYPE="m5a.4xlarge"      # 0.768 USD per Hour (16 Cores, 64 GB RAM)
    #AVERAGE_SESSION_TIME=0.75       # Hours for m5.2xlarge instance
    
    # An experiment from 2021-10-06
    INSTANCE_TYPE="c5.4xlarge"      # 0.744 USD per Hour (16 Cores, 3.4GHz, 32 GB RAM)
    AVERAGE_SESSION_TIME=1.5       # Hours for c5.4xlarge instance with VCPKG build
    
    # An experiment from 2021-10-06 -> Can't create instance
    #INSTANCE_TYPE="c5a.8xlarge"      # 0.1.344 USD per Hour (32 Cores, 3.3 GHz, 64 GB RAM)
    #AVERAGE_SESSION_TIME=0.75       # Hours for m5.2xlarge instance

    #INSTANCE_TYPE="m4.10xlarge"    # 2.22 USD per Hour (40 Cores, 163GB RAM)
    #INSTANCE_TYPE="m4.16xlarge"    # 3.552 USD per Hour (64 Cores, 256 GB RAM)
    instanceDiskVolumeSize=100       # GB
else
    INSTANCE_TYPE="t2.micro"
    instanceDiskVolumeSize=8        # GB    
    AVERAGE_SESSION_TIME=0.1 # Hours
fi


if [[ -n "$BASE_TEST" ]]
then
    WriteLog "Execute base test with tag: ${INSTANCE_NAME}" "$LOG_FILE"
else
    WriteLog "Param: instanceName= ${INSTANCE_NAME}" "$LOG_FILE"
    WriteLog "Param: commitId= ${C_ID}" "$LOG_FILE"
    WriteLog "Param: Base= ${BASE}" "$LOG_FILE"
    WriteLog "Param: Jira= ${JIRA}" "$LOG_FILE"
fi

REGION=$(aws configure get region)
WriteLog "Param: region= ${REGION}" "$LOG_FILE"
SSH_KEYFILE="~/HPCC-Platform-Smoketest.pem"
SSH_OPTIONS="-oConnectionAttempts=3 -oConnectTimeout=20 -oStrictHostKeyChecking=no"

#AMI_ID=$( aws ec2 describe-images --owners 446598291512 | egrep -i '"name"|imageid' | egrep -i -A2 '-el7-' | egrep -i '"ImageId"' | tr -d " " | cut -d":" -f2 )
# Better approach
# CentOS 7
NEW_AMI=0
AMI_ID=$( aws ec2 describe-images --owners 446598291512 --filters "Name=name,Values=*dev-el7-x86_64" --query Images[].ImageId --output text )
[ -z "${AMI_ID}" ] && AMI_ID=$( aws ec2 describe-images --owners 446598291512 --filters "Name=name,Values=*dev-el7-x86_64-2021" --query Images[].ImageId --output text ) || NEW_AMI=1
[ -z "${AMI_ID}" ] && AMI_ID="ami-0f6f902a9aff6d384"
# CentOS 8
#AMI_ID=$( aws ec2 describe-images --owners 446598291512 --filters "Name=name,Values=*-el8-x86_64" --query Images[].ImageId --output text )
#[ -z ${AMI_ID} ] && AMI_ID="ami-0c464387e25013b1f"
WriteLog "AMI_ID: ${AMI_ID}, new AMI: ${NEW_AMI}" "$LOG_FILE"

SSH_USER="centos"
if [[ $REGION =~ 'us-east-1' ]]
then
    #AMI_ID="ami-00e1c66ba91987906"    # CentOS 7
    AMI_ID="ami-05a2bf1b49fda2414"    # Rocky-8
    SECURITY_GROUP_ID="sg-0f8acde8c1dc008f1"
    SUBNET_ID="subnet-00c6da41f8516f57d"
    SSH_USER="rocky"
else
    SECURITY_GROUP_ID="sg-08a92c3135ec19aea"
    SUBNET_ID="subnet-0f5274ec85eec91da"
fi

WriteLog "Create instance for ${INSTANCE_NAME}, type: $INSTANCE_TYPE, disk: $instanceDiskVolumeSize, build ${DOCS_BUILD}" "$LOG_FILE"
#cmd=aws ec2 run-instances --image-id ${AMI_ID} --count 1 --instance-type $INSTANCE_TYPE --key-name HPCC-Platform-Smoketest --security-group-ids ${SECURITY_GROUP_ID} --subnet-id ${SUBNET_ID} --instance-initiated-shutdown-behavior terminate --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$instanceDiskVolumeSize,\"DeleteOnTermination\":true,\"Encrypted\":true}}]"
#cmd="aws ec2 run-instances --image-id ${AMI_ID} --count 1 --instance-type $INSTANCE_TYPE --key-name HPCC-Platform-Smoketest --security-group-ids ${SECURITY_GROUP_ID} --subnet-id ${SUBNET_ID} --instance-initiated-shutdown-behavior terminate --block-device-mappings \"[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$instanceDiskVolumeSize,\"DeleteOnTermination\":true,\"Encrypted\":true}}]"
#echo "cmd:$cmd"
instance=$( aws ec2 run-instances --image-id ${AMI_ID} --count 1 --instance-type $INSTANCE_TYPE --key-name HPCC-Platform-Smoketest --security-group-ids ${SECURITY_GROUP_ID} --subnet-id ${SUBNET_ID} --instance-initiated-shutdown-behavior terminate --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$instanceDiskVolumeSize,\"DeleteOnTermination\":true,\"Encrypted\":true}}]" 2>&1 )
#instance=$( eval ${cmd} )
#instance=$( aws ec2 run-instances --launch-template LaunchTemplateId=lt-0f4cd6101ec4d94ea --count 1 --key-name HPCC-Platform-Smoketest --instance-initiated-shutdown-behavior terminate --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$instanceDiskVolumeSize,\"DeleteOnTermination\":true,\"Encrypted\":true}}]" 2>&1 )
retCode=$?
WriteLog "Ret code: $retCode" "$LOG_FILE"
WriteLog "Instance: $instance" "$LOG_FILE"

instanceId=$( echo "$instance" | egrep 'InstanceId' | tr -d '", ' | cut -d : -f 2 )
WriteLog "Instance ID: $instanceId" "$LOG_FILE"

# At the end/begin of the day we can check all instances are terminated
echo "instanceName=${INSTANCE_NAME},commitId=${C_ID},Jira=${JIRA},InstanceId=${instanceId}" >> Instances-$DAY_STAMPT.log

if [[ -z "$instanceId" ]]
then
    WriteLog "Instance creation failed, exit" "$LOG_FILE"
    WriteLog "$instance" > ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
    # Give a chance to re-try.
    [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary ]] && rm ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary

    # Create result-yy-mm-dd_hh-mm-ss.log file to ensure it is appear in listtest.sh output   
    CreateResultFile "Instance creation failed, exit" "${C_ID}"
   
    MyExit "-1" "Instance creation failed, exit" "$instance" "${INSTANCE_NAME}" "${C_ID}"
fi

instanceInfo=$( aws ec2 describe-instances --instance-ids ${instanceId} 2>&1 | egrep -i 'instan|status|publicip|privateip|volume' )
WriteLog "Instance info: $instanceInfo" "$LOG_FILE"

tryCount=5
delay=10 # sec
# Give it some time to become accesible if "InvalidInstanceID.NotFound" error found
while [[ ($instanceInfo =~ "InvalidInstanceID.NotFound")  || ( $(echo $InstanceInfo | egrep -i -c 'volume') -eq 0) ]]
do
    tryCount=$(( $tryCount - 1 ))
    [[ $tryCount -eq 0 ]] && break;
    sleep ${delay}
    
    instanceInfo=$( aws ec2 describe-instances --instance-ids ${instanceId} 2>&1 | egrep -i 'instan|status|publicip|privateip|volume' )
    WriteLog "Instance info (in $tryCount try): $instanceInfo" "$LOG_FILE"
done

if [[ $instanceInfo =~ "InvalidInstanceID.NotFound" ]]
then
    WriteLog "Instance creation failed, exit" "$LOG_FILE"
    # Give a chance to re-try.
    [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary ]] && rm ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
   
    # Create result-yy-mm-dd_hh-mm-ss.log file to ensure it is appear in listtest.sh output
    CreateResultFile "Instance creation failed, exit" "${C_ID}"
   
    MyExit "-1" "Error:${instanceInfo}, exit" "$instance" "${INSTANCE_NAME}" "${C_ID}"

fi
if [[ $REGION =~ 'us-east-1' ]]
then
    instancePublicIp=$( echo "$instanceInfo" | egrep 'PrivateIpAddress' | head -n 1 | tr -d '", ' | cut -d : -f 2 )
else
    instancePublicIp=$( echo "$instanceInfo" | egrep 'PublicIpAddress' | tr -d '", ' | cut -d : -f 2 )
fi

tryCount=5
delay=10 # sec
while [[ -z "$instancePublicIp" ]]
do
    WriteLog "Instance has not public IP yet, wait for ${delay} sec and try again." "$LOG_FILE"
    sleep ${delay}
    instanceInfo=$( aws ec2 describe-instances --instance-ids ${instanceId} 2>&1 | egrep -i 'instan|status|publicip|privateip|volume' )
    WriteLog "Instance info: $instanceInfo" "$LOG_FILE"
    if [[ $REGION =~ 'us-east-1' ]]
    then
        instancePublicIp=$( echo "$instanceInfo" | egrep 'PrivateIpAddress' | head -n 1 | tr -d '", ' | cut -d : -f 2 )
    else
        instancePublicIp=$( echo "$instanceInfo" | egrep 'PublicIpAddress' | tr -d '", ' | cut -d : -f 2 )
    fi
    WriteLog "Public IP: '${instancePublicIp}'" "$LOG_FILE"
    tryCount=$(( $tryCount - 1 ))
    [[ $tryCount -eq 0 ]] && break;
done

if [[ -z "$instancePublicIp" ]]
then
    WriteLog "Instance has not public IP exit" "$LOG_FILE"
    WriteLog "$instance" > ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
    # Give a chance to re-try.
    [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary ]] && rm ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary
   
    # Create result-yy-mm-dd_hh-mm-ss.log file to ensure it is appear in listtest.sh output
    CreateResultFile "Instance has not public IP, exit" "${C_ID}"
   
    # Terminate the isntance
    terminate=$( aws ec2 terminate-instances --instance-ids ${instanceId} 2>&1 )
    WriteLog "Terminate because no Public IP:\n ${terminate}" "$LOG_FILE"
   
    MyExit "-1" "Instance has not public IP, exit" "$instance" "${INSTANCE_NAME}" "${C_ID}"
fi
WriteLog "Public IP: '${instancePublicIp}'" "$LOG_FILE"

WriteLog "Remove Public IP: ${instancePublicIp} from know_hosts to prevent SSH warning \n(man-in-the-middle attack) when public IP address is reused by AWS." "$LOG_FILE"
res=$( ssh-keygen -R ${instancePublicIp} -f ~/.ssh/known_hosts 2>&1 )
WriteLog "Res: ${res}\n" "$LOG_FILE"


#volumeId=$( aws ec2 describe-instances --instance-ids ${instanceId} 2>&1 | egrep 'VolumeId' | tr -d '", ' | cut -d : -f 2 )
volumeId=$( echo $instanceInfo | egrep 'VolumeId' | tr -d '", ' | cut -d : -f 2 )
WriteLog "Volume ID: $volumeId" "$LOG_FILE"

tag=$( aws ec2 create-tags --resources ${instanceId} ${volumeId} \
           --tags Key=market,Value=in-house-test \
                  Key=product,Value=hpcc-platform \
                  Key=application,Value=q-and-a \
                  Key=Name,Value=Smoketest-${INSTANCE_NAME} \
                  Key=project,Value=smoketest \
                  Key=service,Value=s3bucket \
                  Key=lifecycle,Value=dev \
                  Key=owner_email,Value=attila.vamos@lexisnexisrisk.com \
                  Key=support_email,Value=attila.vamos@lexisnexisrisk.com \
                  Key=purpose,Value=Smoketest \
                  Key=PR,Value=${INSTANCE_NAME} \
                  Key=Commit,Value=${C_ID} \
                  Key=AppID,Value=${APP_ID} \
                  Key=bu,Value=research-and-development \
                  Key=costcenter,Value=hpcc-platform-sandbox \
        2>&1 )
WriteLog "Tag: ${tag}" "$LOG_FILE"
        
WriteLog "Wait for a while for initialise instance" "$LOG_FILE"
sleep 20

tryCount=15
instanceIsUp=0
 
while [[ $tryCount -ne 0 ]] 
do
    WriteLog "Check user directory ($tryCount)" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ls -l" 2>&1 )
    retCode=$?
    WriteLog "Return code: $retCode, res: $res" "$LOG_FILE"

    if [[ ${retCode} -eq 0 ]]
    then 
        instanceIsUp=1
        break
    else
        isTerminated=$( aws ec2 describe-instances --instance-ids ${instanceId} --filters "Name=tag:PR,Values=${INSTANCE_NAME}" --query "Reservations[].Instances[].State[].Name" | egrep -c 'terminated|stopped'  )
        if [[ $isTerminated -ne 0 ]]
        then
            WriteLog "Instance is terminated, exit" "$LOG_FILE"
            if [[ ! -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary ]] 
            then
                WriteLog "Instance is terminated, exit." "${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary"
            fi
            MyExit "-3" "Instance is terminated, exit." "No further informations" "${INSTANCE_NAME}" "${C_ID}"
        fi
    fi

    sleep 20
    tryCount=$(( $tryCount-1 )) 

done

if [[ $instanceIsUp -eq 1 ]] 
then
    WriteLog "Instance is up and accessible via ssh." "$LOG_FILE"
    WriteLog "Upload token.dat files into smoketest directory" "$LOG_FILE"
    res=$( rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/token.dat $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/ 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    if [ -d ${SMOKETEST_HOME}/${INSTANCE_NAME} ]
    then

        WriteLog "Upload *.dat files" "$LOG_FILE"
        res=$( rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/${INSTANCE_NAME}/*.dat $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/ 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
         
        if [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/environment.xml ]]
        then
            WriteLog "Upload environment.xml file" "$LOG_FILE"
            res=$( rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/${INSTANCE_NAME}/environment.xml $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/ 2>&1)
            WriteLog "Res: $res" "$LOG_FILE"
        fi
        
        #To test build.sh  in instance without deploy it via GitHub
        if [[ -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.new ]]
        then
            WriteLog "Upload build.new file into instance ~/smoketest directory" "$LOG_FILE"
            res=$( rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.new $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/ 2>&1)
            WriteLog "Res: $res" "$LOG_FILE"
        fi
        
        #To test ECLWatch UI testing feature
        if [[ -d ${SMOKETEST_HOME}/${INSTANCE_NAME}/eclwatch ]]
        then
            WriteLog "Upload eclwatch directory into instance ~/smoketest directory" "$LOG_FILE"
            res=$( rsync -var --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/${INSTANCE_NAME}/eclwatch $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/ 2>&1)
            WriteLog "Res: $res" "$LOG_FILE"
        fi
    fi

    WriteLog "Base: $BASE" "$LOG_FILE"
    REQUIRED_FOR_VCPKG_BUILD=candidate-8.8.x
    WriteLog "Required for VCPKG build: $REQUIRED_FOR_VCPKG_BUILD" "$LOG_FILE"
    [ $(printf "%s\n" "$REQUIRED_FOR_VCPKG_BUILD" "$BASE" | sort -V | head -n1) = $REQUIRED_FOR_VCPKG_BUILD ] && VCPKG_INSTALLS_NEWER_VERSION=1 || VCPKG_INSTALLS_NEWER_VERSION=0
    #[[  "candidate-8.6.x candidate-8.4.x candidate-8.2.x" =~ "$BASE" ]] && VCPKG_INSTALLS_NEWER_VERSION=0 || VCPKG_INSTALLS_NEWER_VERSION=1
    WriteLog "VCPKG_INSTALLS_NEWER_VERSION: $VCPKG_INSTALLS_NEWER_VERSION" "$LOG_FILE"
    
    BOOST_PKG=$( find ~/ -iname 'boost_1_71*' -type f -size +100M -print | head -n 1 )
    if [[ (-n "$BOOST_PKG") &&  (${VCPKG_INSTALLS_NEWER_VERSION} -eq 0) ]]
    then
        WriteLog "Upload boost_1_71_0.tar.gz" "$LOG_FILE"
        res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${BOOST_PKG} $SSH_USER@${instancePublicIp}:/home/$SSH_USER/ 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
    else
        WriteLog "The boost_1_71_0.tar.gz not found." "$LOG_FILE"
    fi

    if [[ (${NEW_AMI} -ge 0)  && (${VCPKG_INSTALLS_NEWER_VERSION} -eq 0) ]]
    then
        CMAKE_VER=$( find ~/ -iname 'cmake-*.tar.gz' -type f -size +5M -print | head -n 1 )
        if [[ -n "$CMAKE_VER" ]]
        then
            WriteLog "Upload $CMAKE_VER" "$LOG_FILE"
            res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${CMAKE_VER} $SSH_USER@${instancePublicIp}:/home/$SSH_USER/ 2>&1 )
            WriteLog "Res: $res" "$LOG_FILE"
        else
            WriteLog "The cmake install package not found." "$LOG_FILE"
        fi
    else
        WriteLog "We have a new AMI, don't upolad make-3.18.0." "$LOG_FILE"
    fi

     if [[  ${VCPKG_INSTALLS_NEWER_VERSION} -eq 0 ]]  # The new ami doesn't have curl 7.67, must upload and install
    then 
        CURL_7_67=$( find ~/ -iname 'curl-7.67.0.tar.gz' -type f -size +1M -print | head -n 1 )
        if [[ -n "$CURL_7_67" ]]
        then
            WriteLog "Upload $CURL_7_67" "$LOG_FILE"
            res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${CURL_7_67} $SSH_USER@${instancePublicIp}:/home/$SSH_USER/ 2>&1 )
            WriteLog "Res: $res" "$LOG_FILE"
        else
            WriteLog "The curl 7.67.0 not found." "$LOG_FILE"
        fi
    else
        WriteLog "We have a new AMI, don't upolad curl 7.67.0." "$LOG_FILE"
    fi
    
    BASE_VERSION=${BASE#candidate-}
    BASE_VERSION=${BASE_VERSION%.*}
    [[ "$BASE_VERSION" != "master" ]] && BASE_VERSION=$BASE_VERSION.x
    VCPKG_DOWNLOAD_ARCHIVE=~/vcpkg_downloads-${BASE_VERSION}.zip
    if [[ -f  $VCPKG_DOWNLOAD_ARCHIVE ]]
    then
        WriteLog "Upload $VCPKG_DOWNLOAD_ARCHIVE as vcpkg_donwloads.zip" "$LOG_FILE"
        res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${VCPKG_DOWNLOAD_ARCHIVE} $SSH_USER@${instancePublicIp}:/home/$SSH_USER/vcpkg_downloads.zip 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
    else
        WriteLog "The $VCPKG_DOWNLOAD_ARCHIVE not found." "$LOG_FILE"
    fi
    
    WriteLog "Upload init.sh" "$LOG_FILE"
    # CentOS 7
    #res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/init.sh ${SMOKETEST_HOME}/timestampLogger.sh $SSH_USER@${instancePublicIp}:/home/$SSH_USER/ 2>&1 )
    # CentOS 8
    #res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/init-cos8.sh $SSH_USER@${instancePublicIp}:/home/$SSH_USER/init.sh 2>&1 )
    # Rocky 8
    res=$( rsync -vapE --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" ${SMOKETEST_HOME}/init-rocky8.sh $SSH_USER@${instancePublicIp}:/home/$SSH_USER/init.sh 2>&1 )
    DOCS_BUILD=''  # Should figure out
    WriteLog "Res: $res" "$LOG_FILE"

#    WriteLog "Set it to executable" "$LOG_FILE"
#    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "chmod +x init.sh" 2>&1 )
#    WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Check user directory" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ls -l" 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Execute init.sh" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "~/init.sh -instanceName=${INSTANCE_NAME} ${DOCS_BUILD} ${ADD_GIT_COMMENT} ${COMMIT_ID} ${DRY_RUN} -sessionTime=${AVERAGE_SESSION_TIME} ${BASE_TEST} -base=$BASE" 2>&1 )
    WriteLog "Res:\n$res" "$LOG_FILE"

    # Donwload init<-timestamp>.log file
    WriteLog "Download /home/$SSH_USER/init-<timestamp>.log file" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/init-*.log ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Check user directory" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ls -l" 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    if [[ ${DOCS_BUILD} -ne 0 ]]
    then
        WriteLog "Check fop" "$LOG_FILE"
        res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "/usr/bin/fop -version" 2>&1 )
        WriteLog "Res: $res" "$LOG_FILE"
    fi
    
    # Donwload Bokeh URL file
    WriteLog "Download /home/$SSH_USER/smoketest/bokeh.url file" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/bokeh.url ${SMOKETEST_HOME}/${INSTANCE_NAME}/bokeh.url 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    #WriteLog "Check Smoketest" "$LOG_FILE"
    #res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ls -l ~/smoketest/" 2>&1 )
    #WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Check crontab" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "crontab -l" 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    if [[ -z $DRY_RUN ]]
    then
        INIT_WAIT=30  # sec
        LOOP_WAIT=1m
    else
        INIT_WAIT=1m
        LOOP_WAIT=1m
    fi
    
    WriteLog "Wait ${INIT_WAIT} before start checking Smoketest state" "$LOG_FILE"
    sleep ${INIT_WAIT}
    smoketestIsRunning=1
    checkCount=0
    emergencyLogDownloadThreshold=$( echo " 60 * $AVERAGE_SESSION_TIME * 4 / 3" | bc ) # 60  # minutes
    WriteLog "emergencyLogDownloadThreshold: $emergencyLogDownloadThreshold minutes" "$LOG_FILE"
    
    while [[ $smoketestIsRunning -ne 0 ]]
    do
        # Should use BASE_TEST to check smoketest or build.sh
        if [[ -z "$BASE_TEST" ]]
        then
            smoketestIsRunning=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ps aux | egrep -c '[s]moketest.sh|[P]rocessPullReq|[b]uild.sh'"  2>&1 )
        else
            smoketestIsRunning=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "pgrep build.sh | wc -l"  2>&1 )
        fi
        retCode=$?
        if [[ $retcode -gt 1 ]]
        then
            # Something is wrong, try to find out what
            WriteLog "retCode: $retCode, smoketestIsRunning:'$smoketestIsRunning'" "$LOG_FILE"
            timeOut=$( echo "$smoketestIsRunning" | egrep 'timed out' | wc -l);
            if [[ $timeOut -eq 0 ]]
            then
                WriteLog "Ssh error, try again" "$LOG_FILE"
                smoketestIsRunning=1
            else
                WriteLog "Ssh timed out, chek if the instance is still running" "$LOG_FILE"
                isTerminated=$( aws ec2 describe-instances --instance-ids ${instanceId} --filters "Name=tag:PR,Values=${INSTANCE_NAME}" --query "Reservations[].Instances[].State[].Name" | egrep -c 'terminated|stopped'  )
                WriteLog "isTerminated: $isTerminated" "$LOG_FILE"
                if [[ $isTerminated -ne 0 ]]
                then
                    WriteLog "Instance is terminated, exit" "$LOG_FILE"
                    smoketestIsRunning=0
                    if [[ ! -f ${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary ]] 
                    then
                        WriteLog "Instance is terminated, exit." "${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary"
                    fi
                    MyExit "-3" "Instance is terminated, exit." "No further informations" "${INSTANCE_NAME}" "${C_ID}"
                else
                    WriteLog "Instance is still running, try again" "$LOG_FILE"
                    smoketestIsRunning=1
                fi
            fi
        else
            WriteLog "Smoketest is $( [[ $smoketestIsRunning -ne 0 ]] && echo 'running.' || echo 'finished.') (Check count: $checkCount)"  "$LOG_FILE"
            
            checkCount=$(( $checkCount + 1 ))
            
            # If session run time is longger than 1.25 * average_instance_time then we need to make emergency backup form logfiles regurarly (every 1- 2 -3 minutes).
            if [[ ( $checkCount -ge $emergencyLogDownloadThreshold ) && ( $(( $checkCount % 2 )) -eq 0) ]]
            then
                WriteLog "This instance is running in $checkCount minutes (> $emergencyLogDownloadThreshold). Download its logs." "$LOG_FILE"
                res=$( rsync -va --timeout=60 --exclude=*.rpm --exclude=*.sh --exclude=*.py --exclude=*.txt --exclude=HPCCSystems-regression --exclude=OBT --exclude=rte --exclude=*.xml --exclude=build --exclude=HPCC-Platform -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/* ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
                WriteLog "Res: $res" "$LOG_FILE"
                
                CompressAndDownload "emergency"
            fi

        fi
        # It is possible the ProcessPullRequests.py is too busy (lots of PRs, etc) and the build.sh doesn't run yet.
        # Give it some time with checking the value of checkCount.
        if [[ ($smoketestIsRunning -eq 0 ) && ($checkCount -le 5) ]]
        then
            procList=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ps aux | egrep '[s]moketest.sh|ProcessPullReq|build.sh'"  2>&1 )
            WriteLog "Proclist:"  "$LOG_FILE"
            WriteLog "$procList"  "$LOG_FILE"
            smoketestIsRunning=1
            
        fi
        
        if [[ $smoketestIsRunning -ne 0 ]]
        then
            sleep ${LOOP_WAIT}
        fi
    done

    WriteLog "Check Smoketest" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "ls -l ~/smoketest/${INSTANCE_NAME}" 2>&1 )
    retCode=$?
    WriteLog "Res: $res \n(retcode:$retCode)" "$LOG_FILE"
    if [[ $retCode -ne 0 ]]
    then
        WriteLog "Remote ${INSTANCE_NAME} directory not found. Create result file." "$LOG_FILE"
        # Create result-yy-mm-dd_hh-mm-ss.log file to ensure it is appear in listtest.sh output
        CreateResultFile "PR directory not found, perhaps it is already closed" "${C_ID}"
    fi
    
    WriteLog "Smoketest finished." "$LOG_FILE"
    age=2 # minutes
    WriteLog "Archive previous test session logs and other files older than $age minutes."  "$LOG_FILE"
    timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
     # Move all *.log, *test*.summary, *.diff, *.txt and *.old files into a zip archive.
    # TO-DO check if there any. e.g. for a new PR there is not any file to archive
    res=$( find ${SMOKETEST_HOME}/${INSTANCE_NAME}/ -maxdepth 1 -mmin +$age -type f -iname '*.log' -o -iname '*test*.summary' -o -iname '*.diff' -o -iname '*.txt' -o -iname '*.old' | egrep -v 'result-|RelWith|init-' | zip -m -u ${SMOKETEST_HOME}/${INSTANCE_NAME}/old-logs-${timestamp} -@ 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Compress and download result" "$LOG_FILE"
    WriteLog "/home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-regression/ directory" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "zip -m /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-regression-$(date '+%y-%m-%d_%H-%M-%S') -r /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-regression/* > /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCCSystems-regression-$(date '+%y-%m-%d_%H-%M-%S').log 2>&1" 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Find and compress log files from /home/$SSH_USER/smoketest/${INSTANCE_NAME}/build/vcpkg_buildtrees/ directory" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "find /home/$SSH_USER/smoketest/${INSTANCE_NAME}/build/vcpkg_buildtrees/ -iname '*.log' -type f | zip /home/$SSH_USER/smoketest/${INSTANCE_NAME}/vcpkg_buildtrees_log-$(date '+%y-%m-%d_%H-%M-%S') -@ "  2>&1 )
   #res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/build/vcpkg_buildtrees/*/*.log ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Download /home/$SSH_USER/smoketest//${INSTANCE_NAME}/build/vcpkg-manifest-install.log" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest//${INSTANCE_NAME}/build/vcpkg-manifest-install.log ${SMOKETEST_HOME}/${INSTANCE_NAME}/vcpkg-manifest-install-$(date '+%y-%m-%d_%H-%M-%S').csv 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Remove /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCC-Platform /home/$SSH_USER/smoketest/${INSTANCE_NAME}/build directory" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "rm -rf /home/$SSH_USER/smoketest/${INSTANCE_NAME}/HPCC-Platform /home/$SSH_USER/smoketest/${INSTANCE_NAME}/build" 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Check if there is any core files in /home/$SSH_USER/smoketest/${INSTANCE_NAME} and make them readable for everyone" "$LOG_FILE"
    res=$( ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS} $SSH_USER@${instancePublicIp} "find /home/$SSH_USER/smoketest/${INSTANCE_NAME}/ -iname 'core*' -type f -print -exec sudo chmod 0755 '{}' \;" 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Download files from /home/$SSH_USER/smoketest/${INSTANCE_NAME} directory" "$LOG_FILE"
    res=$( rsync -va --timeout=60 --exclude=*.rpm --exclude=*.sh --exclude=*.py --exclude=*.txt --exclude=HPCCSystems-regression --exclude=OBT --exclude=rte -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/* ${SMOKETEST_HOME}/${INSTANCE_NAME}/ 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
    
    WriteLog "Download /home/$SSH_USER/smoketest/SmoketestInfo.csv file" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/SmoketestInfo.csv ${SMOKETEST_HOME}/${INSTANCE_NAME}/SmoketestInfo-${INSTANCE_NAME}-$(date '+%y-%m-%d_%H-%M-%S').csv 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Download /home/$SSH_USER/smoketest/prp-$(date '+%Y-%m-%d').log file" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/prp-$(date '+%Y-%m-%d').log ${SMOKETEST_HOME}/${INSTANCE_NAME}/prp-$(date '+%Y-%m-%d')-${INSTANCE_NAME}-${instancePublicIp}.log 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Download /home/$SSH_USER/smoketest/eclwatch/eclWatchUiTest.log file" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/eclwatch/eclWatchUiTest.log ${SMOKETEST_HOME}/${INSTANCE_NAME}/eclWatchUiTest-${C_ID}-$(date '+%Y-%m-%d').log 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"

    WriteLog "Download /home/$SSH_USER/smoketest/${INSTANCE_NAME}/rte/ecl-test.json file" "$LOG_FILE"
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/smoketest/${INSTANCE_NAME}/rte/ecl-test.json ${SMOKETEST_HOME}/${INSTANCE_NAME}/ecl-test-${C_ID}-$(date '+%Y-%m-%d').json 2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
   
    WriteLog "Try to download /home/$SSH_USER/vcpkg_downloads.zip" "$LOG_FILE"
    # See build.sh to build it if CMake takes too long
    res=$( rsync -va --timeout=60 -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}" $SSH_USER@${instancePublicIp}:/home/$SSH_USER/vcpkg_downloads.zip ${SMOKETEST_HOME}/${INSTANCE_NAME}/vcpkg_downloads-${BASE_VERSION}.zip  2>&1 )
    WriteLog "Res: $res" "$LOG_FILE"
   
    CompressAndDownload

else
    WriteLog "The try count exhausted before the instance became up and running." "$LOG_FILE"
    WriteLog "The try count exhausted before the instance became up and running." "${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary"
    WriteLog "$instance" "${SMOKETEST_HOME}/${INSTANCE_NAME}/build.summary"
    if [[ -n "$instanceId" ]]
    then
        terminate=$( aws ec2 terminate-instances --instance-ids ${instanceId} 2>&1 )
        WriteLog "Terminate: ${terminate}" "$LOG_FILE"
    fi
    MyExit "-2" "The try count exhausted before the instance became up and running." "$instance" "${INSTANCE_NAME}" "${C_ID}"
fi

KEEP_INSTANCE=0
WAIT_BEFORE_TERMINATE=20s
if [[ -n $DRY_RUN ]]
then
    WAIT_BEFORE_TERMINATE=4m
fi

if [[ ${KEEP_INSTANCE} -eq 0 ]]
then
    WriteLog "Wait $WAIT_BEFORE_TERMINATE before terminate" "$LOG_FILE"
    sleep ${WAIT_BEFORE_TERMINATE}

    terminate=$( aws ec2 terminate-instances --instance-ids ${instanceId} 2>&1 )
    WriteLog "Terminate: ${terminate}" "$LOG_FILE"
else
    WriteLog "\nSkip auto terminate the instance: ${instanceId}. Do it manually! \n" "$LOG_FILE"
fi

sleep 10

WriteLog "Instance:" "$LOG_FILE"
res=$( aws ec2 describe-instances --instance-ids ${instanceId} --filters "Name=tag:PR,Values=${INSTANCE_NAME}" "Name=tag:Commit,Values=${C_ID}" | egrep -i 'instan|status|public' 2>&1 )
WriteLog "Res: $res" "$LOG_FILE"

WriteLog "End." "$LOG_FILE"
