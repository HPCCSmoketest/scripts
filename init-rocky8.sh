#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x
. ./timestampLogger.sh

TIME_STAMPT=$( date "+%y-%m-%d_%H-%M-%S" )
LOG_FILE="/home/$USER/init-${TIME_STAMPT}.log"
myEcho()
{
    msg=$1
    WriteLog "$msg" "$LOG_FILE"
}

#export PATH=$PATH:/usr/local/bin:/bin:/usr/local/sbin:/sbin:/usr/sbin:
myEcho "path: $PATH"

PUBLIC_IP=$( curl -q http://checkip.amazonaws.com )
myEcho "PUBLIC_IP: '$PUBLIC_IP'"

PUBLIC_HOSTNAME=$( wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname )
myEcho "PUBLIC_HOSTNAME: '$PUBLIC_HOSTNAME'"

IP_FULL_PATH=$( which "ip" )
myEcho "IP_FULL_PATH: '$IP_FULL_PATH'"
LOCAL_IP=$($IP_FULL_PATH -4 addr | egrep '10\.' | awk '{ print $2 }' | cut -d / -f1)
myEcho "LOCAL_IP: '$LOCAL_IP'"

INSTANCE_NAME="PR-12701"
DOCS_BUILD=0
DOCS_BUILD_STR=''
KEEP_FILES=0
DRY_RUN=0
AVERAGE_SESSION_TIME=0.75 # Hours for m4.4xlarge instance
AVERAGE_SESSION_TIME=1.2 # Hours for m4.2xlarge instance
BASE_TEST=0
BASE_TAG=''

SYSTEM_ID=$( cat /etc/*-release | egrep -i "^PRETTY_NAME" | cut -d= -f2 | tr -d '"' )
if [[ "${SYSTEM_ID}" == "" ]]
then
    SYSTEM_ID=$( cat /etc/*-release | head -1 )
fi

SYSTEM_ID=${SYSTEM_ID// (*)/}
SYSTEM_ID=${SYSTEM_ID// /_}
SYSTEM_ID=${SYSTEM_ID//./_}

while [ $# -gt 0 ]
do
    param=$1
    param=${param#-}
    myEcho "Param: ${param}"
    case $param in
    
        instance*)  INSTANCE_NAME=${param//instanceName=/}
                INSTANCE_NAME=${INSTANCE_NAME//\"/}
                #INSTANCE_NAME=${INSTANCE_NAME//PR/PR-}
                # To keep listTests3.py happy
                echo "Instance name: '${INSTANCE_NAME}'"
                ;;
                
        docs*)  DOCS_BUILD_STR=param
                DOCS_BUILD=${param//docs=True/1}
                DOCS_BUILD=${DOCS_BUILD//docs=False/0}
                myEcho "Build docs: '${DOCS_BUILD}'"
                ;;
               
        addGitC*) ADD_GIT_COMMENT=${param//addGitComment=True/1}
                ADD_GIT_COMMENT=${ADD_GIT_COMMENT//addGitComment=False/0}
                myEcho "Add git comment: ${ADD_GIT_COMMENT}"
                ;;
                
        commit*) COMMIT_ID=${param//commitId=/}
                COMMIT_ID=${COMMIT_ID//\"/}
                # To keep listTests3.py happy
                echo "Commit ID: ${COMMIT_ID}"
                ;;
                
        dryRun) DRY_RUN=1
                myEcho "Dry run."
                ;;
                
        sessionTime*)  AVERAGE_SESSION_TIME=${param//sessionTime=/}
                myEcho "Average session time: ${AVERAGE_SESSION_TIME}"
                ;;
                
        baseTest*) BASE_TEST=1
#                BASE_TAG=${param//baseTest=/}
#                BASE_TAG=${BASE_TAG//\"/}
#                myEcho "Execute base test with tag: ${BASE_TAG}"
                ;;
                
        *)  myEcho "Unknown parameter: ${param}."
                ;;
    esac
    shift
done

#cat << DATASTAX_ENTRIES | sudo tee /etc/yum.repos.d/datastax.repo
#[datastax]
#name = DataStax Repo for Apache Cassandra
#baseurl = http://rpm.datastax.com/community
#enabled = 1
#gpgcheck = 0
#DATASTAX_ENTRIES

#sudo yum remove -y nodejs

#curl --silent --location https://rpm.nodesource.com/setup_14.x | sudo bash -

PACKAGES_TO_INSTALL="expect bc gdb"
#if [ $DOCS_BUILD -eq 1 ]
#then
#    wget http://mirror.centos.org/centos/7/os/x86_64/Packages/fop-1.1-6.el7.noarch.rpm
    #PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL fop-1.1-6.el7"
#fi

myEcho "Packages to install: ${PACKAGES_TO_INSTALL}"
sudo yum install -y ${PACKAGES_TO_INSTALL}


# Configure and start TinyProxy
#
myEcho "Generate TinyProxy config"
echo "Port 8888"    > tinyproxy.conf
echo "Timeout 600" >> tinyproxy.conf
echo "StartServers 5" >> tinyproxy.conf
echo "MaxClients 5" >> tinyproxy.conf
echo "DisableViaHeader yes" >> tinyproxy.conf
myEcho "  Done"
myEcho "Start TinyProxy..."
res=$( sudo tinyproxy -c tinyproxy.conf 2>&1)
retCode=$?
if [[ $retCode -ne 0 ]]
then
    myEcho "Error at start: $retCode"
    myEcho "res:$res"
fi
myEcho "TinyProxy pid(s): $(pgrep tinyproxy)"
myEcho "  Done"


myEcho "Node version: $(node --version)"
sudo yum remove -y nodejs
sudo yum --enablerepo=nodesource clean metadata

# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Download and install Node.js:
nvm install 22

# Verify the Node.js version:
myEcho "Node version: $(node -v )"    # Should print "v22.12.0".
myEcho "nvm current : $(nvm current)" # Should print "v22.12.0".
myEcho "npm version : $(npm -v )"     # Should print "10.9.0".

myEcho "npm install @playwright/test"
res=$(npm install @playwright/test 2>&1)
retCode=$?
myEcho "retCode: $retCode"
myEcho "res: $res"

myEcho "npx playwright install --with-deps"
res=$(npx playwright install --with-deps 2>&1)
retCode=$?
myEcho "retCode: $retCode"
myEcho "res: $res"

#sudo yum install -y gcc-toolset-12

#curl -q -o autoconf-archive-2021.02.19.tar.xz http://ftp.gnu.org/gnu/autoconf-archive/autoconf-archive-2021.02.19.tar.xz && \
#xz -d -v autoconf-archive-2021.02.19.tar.xz && \
#tar xvf autoconf-archive-2021.02.19.tar && \
#pushd autoconf-archive-2021.02.19 && \
#./configure && \
#make && \
#sudo make install
#popd



GUILLOTINE=$( echo " 2 * $AVERAGE_SESSION_TIME * 60" | bc |  xargs printf "%.0f" ) # minutes ( 2 x AVERAGE_SESSION_TIME)
printf "AVERAGE_SESSION_TIME = %f hours, GUILLOTINE = %d minutes\n" "$AVERAGE_SESSION_TIME" "$GUILLOTINE"

[ ! -d smoketest ] && mkdir smoketest

cd smoketest
rm -rf scripts
git clone https://github.com/HPCCSmoketest/scripts.git

# check scripts dir

cp scripts/*.sh .
cp scripts/*.py .

#myEcho "Check and install CMake 3.18.0"
#CMAKE_3_18=$( find ~/ -iname 'cmake-3.18.0.tar.gz' -type f -size +1M -print | head -n 1 )
#if [[ -n "$CMAKE_3_18" ]]
#then
#    myEcho "$CMAKE_3_18 found, unzip and install it"
#    tar -xzvf  ${CMAKE_3_18} > cmake.log
#    pushd cmake-3.18.0
#    ./bootstrap
#    make -j
#    sudo make install
#    popd
#    type "cmake"
#    cmake --version;
#else
#    myEcho "$CMAKE_3_18 not found."
#fi

[[ -f ./build.new ]] && cp -v ./build.new build.sh

[ ! -d $INSTANCE_NAME ] && mkdir $INSTANCE_NAME

cd $INSTANCE_NAME
myEcho "Execute Smoketest on $INSTANCE_NAME" > test.log

if [[ -f ~/vcpkg_downloads.zip ]]
then
    myEcho "vcpkg_downloads.zip found, extract it."
    [[ ! -d build ]] && mkdir build
    pushd build
    res=$( unzip ~/vcpkg_downloads.zip 2>&1 )
    [[ $? -ne 0 ]] && myEcho "$res"
    popd
    myEcho "  Done."
    
    myEcho "Delete vcpkg_downloads.zip."
    myEcho "$(rm -v ~/vcpkg_downloads.zip)"
    myEcho "  Done."
fi


if [[ $BASE_TEST  -eq 1 ]]
then
    myEcho "Because build.sh will be executed instead of ProcessPullRequest.py"
    myEcho "We need:"
    myEcho "   Clone HPCC-Platform"
    res=$( git clone https://github.com/HPCC-Systems/HPCC-Platform.git 2>&1 )
    myEcho "     Res: ${res}"
    pushd HPCC-Platform
    # Should get RTE from master
    COMMON_RTE_DIR=~/smoketest/rte
    [[ ! -d $COMMON_RTE_DIR ]] && mkdir $COMMON_RTE_DIR
    myEcho "   Checkout master"
    res=( git checkout master )
    myEcho "     Res: ${res}"
    myEcho "   Copy Regression Test Engine to $COMMON_RTE_DIR"
    res=$(  cp -v testing/regress/ecl-test* $COMMON_RTE_DIR/  2>&1) 
    myEcho "     Res: ${res}"
    res=$(  cp -v -r testing/regress/hpcc $COMMON_RTE_DIR/hpcc  2>&1) 
    myEcho "     Res: ${res}"
    myEcho "   Checkout latest Git tag: ${INSTANCE_NAME} to build and test"
    res=$( git checkout ${INSTANCE_NAME} -b latest )
    myEcho "     Res: ${res}"
    myEcho "   Check where we are"
    res=$( git log -1 )
    myEcho "     Res: ${res}"
    myEcho "   Submodule update"
    res=$( git submodule update --init --recursive )
    myEcho "     Res: ${res}"
    myEcho "   Check branch status"
    res=$( git status )
    myEcho "     Res: ${res}"
    popd
    cp -v ../build.sh .
    #myEcho "Update PATH..."
    #export PATH=$PATH:/usr/local/bin:/bin:/usr/local/sbin:/sbin:/usr/sbin:
    myEcho "path: $PATH"
    type "cmake"
    cmake --version;
    type "git"
    git --version
fi

cd .. 

myEcho "Add items for crontab"

prId=${INSTANCE_NAME//PR-/}
INSTANCE_ID=$( wget -q -t1 -T1 -O - http://169.254.169.254/latest/meta-data/instance-id )

# Schedule smoketest in one or two minutes time
[[ $(date "+%-S") -ge 50 ]] && timeStep=1 || timeStep=1

# Add environment settings to crotab
(echo "PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/sbin:/usr/sbin:"; echo "SHELL=/bin/bash"; crontab -l) | crontab

DEVTOOLSET=$( scl list-collections | egrep 'toolset' | sort -V | tail -n 1 )
myEcho "DEVTOOLSET: '$DEVTOOLSET'"

if [[ $DRY_RUN -eq 0 ]]
then
    if [[ $BASE_TEST  -eq 1 ]]
    then
        # For base test
        ( crontab -l; echo $( date  -d "$today + $timeStep minute" "+%M %H %d %m") " * . scl_source enable $DEVTOOLSET; export CL_PATH=/opt/rh/$DEVTOOLSET/root/usr; export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH; cd ${HOME}/smoketest/$INSTANCE_NAME; export commitId=${COMMIT_ID}; export addGitComment=${ADD_GIT_COMMENT}; export runOnce=1; export keepFiles=$KEEP_FILES; export testOnlyOnePR=1; export testPrNo=$prId; export runFullRegression=1; export useQuickBuild=0; export skipDraftPr=0; export AVERAGE_SESSION_TIME=$AVERAGE_SESSION_TIME; ./build.sh -tests='*.ecl ' -docs=False -unittest=True -wuttest=True -keepFiles=False -enableStackTrace=True" ) | crontab
        
        # Add self destruction with email notification
        ( crontab -l; echo ""; echo "# Self destruction initiated in ${GUILLOTINE} minutes"; echo $( date  -d "$today + ${GUILLOTINE} minutes" "+%M %H %d %m") " * sleep 10; echo \"At $(date '+%Y.%m.%d %H:%M:%S') the ${INSTANCE_ID} is still running, terminate it.\" | mailx -s \"Instance self-destruction initiated\" attila.vamos@gmail.com; sudo shutdown now " ) | crontab
        
        # Add self destruction without email notification
        #( crontab -l; echo ""; echo "# Self destruction initiated in ${GUILLOTINE} minutes"; echo $( date  -d "$today + ${GUILLOTINE} minutes" "+%M %H %d %m") " * sleep 10; sudo shutdown now " ) | crontab
    else
        # For PR test
        ( crontab -l; echo $( date -d "+$timeStep minute" "+%M %H %d %m") " * source ~/.bashrc; . scl_source enable $DEVTOOLSET; export CL_PATH=/opt/rh/$DEVTOOLSET/root/usr; export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH; cd ~/smoketest; ./update.sh; export commitId=${COMMIT_ID}; export addGitComment=${ADD_GIT_COMMENT}; export runOnce=1; export keepFiles=$KEEP_FILES; export testOnlyOnePR=1; export testPrNo=$prId; export runFullRegression=1; export useQuickBuild=0; export skipDraftPr=0; export AVERAGE_SESSION_TIME=$AVERAGE_SESSION_TIME; export disableFailIfCoreFound=0; ./smoketest.sh" ) | crontab
        
        # Add self destruction with email notification
        ( crontab -l; echo ""; echo "# Self destruction initiated in ${GUILLOTINE} minutes"; echo $( date -d "+${GUILLOTINE} minutes" "+%M %H %d %m") " * sleep 10; echo \"At $(date '+%Y.%m.%d %H:%M:%S') the ${INSTANCE_ID} is still running, terminate it.\" | mailx -s \"Instance self-destruction initiated\" attila.vamos@gmail.com; sudo shutdown now " ) | crontab
        
        # Add self destruction without email notification
        #( crontab -l; echo ""; echo "# Self destruction initiated in ${GUILLOTINE} minutes"; echo $( date -d "+${GUILLOTINE} minutes" "+%M %H %d %m") " * sleep 10; sudo shutdown now " ) | crontab
    fi
else
    # For base test
    if [[ $BASE_TEST  -eq 1 ]]
    then
        # Ensure it is never kick off, but to check the crontab entry s ok
        ( crontab -l; echo $( date  -d "$today + 20 minutes" "+%M %H %d %m") " * . scl_source enable ${DEVTOOLSET}; export CL_PATH=/opt/rh/${DEVTOOLSET}/root/usr; export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH};cd ~/smoketest; ./update.sh; export commitId=${COMMIT_ID}; export addGitComment=${ADD_GIT_COMMENT}; export runOnce=1; export keepFiles=$KEEP_FILES; export testOnlyOnePR=1; export testPrNo=$prId; export runFullRegression=1; export useQuickBuild=0; export skipDraftPr=0; export AVERAGE_SESSION_TIME=$AVERAGE_SESSION_TIME; cd ${INSTANCE_NAME}; ./build.sh -tests='*.ecl ' -docs=False -unittest=True -wuttest=True -keepFiles=False -enableStackTrace=True" ) | crontab
    else
        ( crontab -l; echo $( date  -d "$today + $timeStep minute" "+%M %H %d %m") " * cd ~/smoketest; ./update.sh; cd $INSTANCE_NAME; echo 'Build: success' > build.summary; export addGitComment=${ADD_GIT_COMMENT} " ) | crontab
    fi
    
    # Add self destruction without email notification
    ( crontab -l; echo ""; echo "# Self destruction initiated in 10 minutes"; echo $( date  -d "$today + 10 minutes" "+%M %H %d %m") " * sleep 10; sudo shutdown now " ) | crontab
fi

# Before self destruction initiate it would be nice to kill (send Ctrl-C/Ctrl-Break signal to) Regression Test Engine to put some log into the PR
BREAK_TIME=27 # $(( ${GUILLOTINE} - 10 ))
BREAK_TIME=$(( ${GUILLOTINE} * 8 / 10 ))
PROCESS_TO_KILL="build.sh"  #"ecl-test"
( crontab -l; echo ""; echo "# Send Ctrl - C to Regression Test Engine after ${BREAK_TIME} minutes"; echo $( date -d " + ${BREAK_TIME} minutes" "+%M %H %d %m") " * REGRESSION_TEST_ENGINE_PID=\$( pgrep -f $PROCESS_TO_KILL ); while [[ -z \"\$REGRESSION_TEST_ENGINE_PID\" ]] ; do date; sleep 10; REGRESSION_TEST_ENGINE_PID=\$( pgrep -f $PROCESS_TO_KILL ); done; echo \"Regression test engine PID(s): \$REGRESSION_TEST_ENGINE_PID\"; sudo kill -SIGINT -- \${REGRESSION_TEST_ENGINE_PID}; sleep 10; sudo kill -SIGINT -- \${REGRESSION_TEST_ENGINE_PID}; " ) | crontab

# Install, prepare and start Bokeh
#myEcho install Bokeh
#p3=$(which "pip3")
#myEcho "p3: '$p3'"
#sudo ${p3} install --upgrade pip
#sudo yum remove -y pyparsing
#p3=$(which "pip3")
#myEcho "p3: '$p3'"
#sudo ${p3} install pandas bokeh pyproj

bk=$(which 'bokeh')
myEcho "bokeh: $bk"

myEcho "Prepare Bokeh"
cd ~/smoketest
# Don't use Public IP, out network may refuse to connect to it
#sed -e 's/origin=\(ec2.*\)/origin='"$PUBLIC_IP"':5006/g' ./startBokeh_templ.sh>  ./startBokeh.sh
#myEcho "Bokeh address: $PUBLIC_IP:5006"

if [[ -n $PUBLIC_HOSTNAME ]]
then
    myEcho "Use Public hostname: '$PUBLIC_HOSTNAME'"
    sed -e 's/origin=\(10.*\):5006/origin='"$PUBLIC_HOSTNAME"':5006/g' ./startBokeh_templ.sh>  ./startBokeh.sh
    myEcho "Bokeh IP address: $PUBLIC_HOSTNAME:5006"
    # To keep listTests3.py happy
    echo "Bokeh address: $PUBLIC_HOSTNAME:5006"
    echo "http://$PUBLIC_HOSTNAME:5006/showStatus" > bokeh.url
else
    myEcho "Perhaps we are in us-east-1 use Local IP: '$LOCAL_IP'"
    sed -e 's/origin=\(10.*\):5006/origin='"$LOCAL_IP"':5006/g' ./startBokeh_templ.sh>  ./startBokeh.sh
    myEcho "Bokeh IP address: $LOCAL_IP:5006"
    # To keep listTests3.py happy
    echo "Bokeh address: $LOCAL_IP:5006"
    echo "http://$LOCAL_IP:5006/showStatus" > bokeh.url

fi
myEcho "Start Bokeh"
chmod +x ./startBokeh.sh
./startBokeh.sh &
myEcho "Bokeh pid: $!"

myEcho "End of init.sh"
