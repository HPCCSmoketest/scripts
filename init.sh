#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

. ./timestampLogger.sh

TIME_STAMPT=$( date "+%y-%m-%d_%H-%M-%S" )
LOG_FILE="/home/centos/init-${TIME_STAMPT}.log"
myEcho()
{
    msg=$1
    WriteLog "$msg" "$LOG_FILE"
}

export PATH=$PATH:/usr/local/sbin:/usr/sbin:
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
KEEP_FILES=1
DRY_RUN=0
AVERAGE_SESSION_TIME=0.75 # Hours for m4.4xlarge instance
AVERAGE_SESSION_TIME=1.2 # Hours for m4.2xlarge instance
BASE_TEST=0
BASE_TAG=''
BASE='master'

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
                myEcho "Instance  name: '${INSTANCE_NAME}'"
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
                myEcho "CommitID: ${COMMIT_ID}"
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
                
        base*) BASE=${param//base=/}
                WriteLog "Base : ${BASE}" "$LOG_FILE"
                ;;
                
        *)  myEcho "Unknown parameter: ${param}."
                ;;
    esac
    shift
done

#cat << DATASTAX_ENTRIES | sudo tee /etc/yum.repos.d/datastax.repo
#[datastax]
#name = DataStax Repo for Apache Cassandra
#baseurl = https://rpm.datastax.com/community
#enabled = 1
#gpgcheck = 0
#DATASTAX_ENTRIES

# Ignore Cassandra
#cat << CASSANDRA_ENTRIES | sudo tee /etc/yum.repos.d/cassandra.repo
#[cassandra]
#name=Apache Cassandra
#baseurl=https://www.apache.org/dist/cassandra/redhat/311x/
#gpgcheck=0
#repo_gpgcheck=0
#gpgkey=https://www.apache.org/dist/cassandra/KEYS
#CASSANDRA_ENTRIES
myEcho "-------------------------------------"

# Commented out when the latest CentOS 7 AMI has this version of nodejs
myEcho "Node version: $(node --version)"
if [[ "$(node --version)" != "v18.13.1" ]]
then
    myEcho "Wrong version, remove and install 18.13.1"
    sudo yum remove -y nodejs
    sudo yum --enablerepo=nodesource clean metadata

    # This approach works
    wget https://rpm.nodesource.com/pub_18.x/el/7/x86_64/nodejs-18.13.0-1nodesource.x86_64.rpm
    sudo rpm -i nodejs-18.13.0-1nodesource.x86_64.rpm
    myEcho "Node version: $(node --version)"
else
    myEcho "Good version, keep it"
fi
myEcho "-------------------------------------"

#PACKAGES_TO_INSTALL="expect mailx dsc30 cassandra30 cassandra30-tools bc psmisc"
#PACKAGES_TO_INSTALL="expect mailx dsc cassandra cassandra-tools bc psmisc git ncurses-devel"
PACKAGES_TO_INSTALL="expect mailx bc psmisc"

#if [ $DOCS_BUILD -eq 1 ]
#then
    wget -q http://mirror.centos.org/centos/7/os/x86_64/Packages/fop-1.1-6.el7.noarch.rpm
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL fop-1.1"
#fi

# This related to Bokeh installation, but should be here because it removes perl-IPC-Cmd 
# (needs to build OpenSSL) as well.
myEcho "Remove pyparsing"
res=$( sudo yum remove -y pyparsing 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Packages to install: ${PACKAGES_TO_INSTALL}"
res=$( sudo yum install -y ${PACKAGES_TO_INSTALL} 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Install git zip unzip wget python3 libtool."
res=$( sudo yum install -y git zip unzip wget python3 libtool 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Install ncurses-devel libmemcached-devel numactl-devel heimdal-devel java-11-openjdk-devel libuv-devel python3-devel kernel-devel perl-IPC-Cmd."
res=$(sudo yum install -y \
    ncurses-devel \
    libmemcached-devel \
    numactl-devel \
    heimdal-devel \
    java-11-openjdk-devel \
    libuv-devel \
    python3-devel \
    kernel-devel \
    perl-IPC-Cmd   2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Install centos-release-scl."
res=$( sudo yum install -y centos-release-scl 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Install devtoolset-9."
res=$(sudo yum install -y devtoolset-9 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Install devtoolset-11."
res=$(sudo yum install -y devtoolset-11 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "Update Pyhon3"
myEcho "Python version: $( python --version 2>&1 )"
myEcho "Python2 version: $( python2 --version 2>&1 )"
myEcho "Python3 version: $( python3 --version )"

myEcho "Before fix Pyhon3"
myEcho "$(ls -l /usr/bin/python3*)"

myEcho "sudo python2 /usr/bin/yum reinstall -y python3 python3-libs"
res=$(sudo python2 /usr/bin/yum reinstall -y python3 python3-libs 2>&1)
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "sudo rm -v /usr/bin/python3"
res=$(sudo rm -v /usr/bin/python3 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "sudo ln -s /usr/local/bin/python3.6 /usr/bin/python3"
res=$(sudo ln -s /usr/local/bin/python3.6 /usr/bin/python3 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "After fix Pyhon3"
myEcho "$(ls -l /usr/bin/python3*)"

myEcho "Done"
myEcho "-------------------------------------"

# Install  CPPUNIT 1.15.1
#pushd ~/
#myEcho "Update CPPUINT to 1.15.1."
#sudo yum remove -y  cppunit
#wget --no-check-certificate http://dev-www.libreoffice.org/src/cppunit-1.15.1.tar.gz
#tar xvf cppunit-1.15.1.tar.gz
#cd cppunit-1.15.1
#./autogen.sh
#./configure
#make
#make check # optional
#sudo make install
#myEcho "   Done"
#myEcho "-------------------------------------"
#popd


GUILLOTINE=$( echo " 2 * $AVERAGE_SESSION_TIME * 60" | bc |  xargs printf "%.0f" ) # minutes ( 2 x AVERAGE_SESSION_TIME)
myEcho "$( printf 'AVERAGE_SESSION_TIME = %f hours, GUILLOTINE = %d minutes\n' $AVERAGE_SESSION_TIME $GUILLOTINE )"

[ ! -d smoketest ] && mkdir smoketest

cd smoketest

myEcho "Clone smoketest"
res=$(git clone https://github.com/HPCCSmoketest/scripts.git 2>&1)
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

# check scripts dir

cp scripts/*.sh .
cp scripts/*.py .

myEcho "Check and install CMake"
CMAKE_VER=$( find ~/ -iname 'cmake-*.tar.gz' -type f -size +1M -print | head -n 1 )
if [[ -n "$CMAKE_VER" ]]
then
    CMAKE_DIR=${CMAKE_VER//.tar.gz/}
    CMAKE_DIR=$(basename $CMAKE_DIR)

    pushd ~/
    myEcho "$CMAKE_VER found, unzip and install it"
    tar -xzvf  ${CMAKE_VER} > cmake.log
    pushd $CMAKE_DIR
    ./bootstrap && \
    make -j && \
    sudo make install
    popd
    type "cmake"
    cmake --version;
    popd
else
    myEcho "CMake install not found. Current version: $(cmake --version)"
fi
myEcho "-------------------------------------"

myEcho "Check and install curl 7.67.0"
CURL_7_67=$( find ~/ -iname 'curl-7.67.0.tar.gz' -type f -size +1M -print | head -n 1 )
if [[ -n "$CURL_7_67" ]]
then
    wget --no-check-certificate https://curl.se/download/curl-7.81.0.tar.gz
    myEcho "$CURL_7_81 found, unzip and install it"
    gunzip -c curl-7.81.0.tar.gz | tar xvf -
    pushd curl-7.81.0
    #./configure --with-ssl && \
    ./configure --with-gnutls --with-ssl
    make -j && \
    sudo make install
    popd
    type "curl"
    curl --version;
else
    myEcho "curl 7.67.0 not found. Current version: $(curl --version)"
fi

myEcho "................................................"
myEcho "Install VCPKG stuff"

myEcho "Base: $BASE" "$LOG_FILE"
REQUIRED_FOR_NEW_VCPKG_BUILD=candidate-8.12.x
myEcho "Required for new VCPKG build: $REQUIRED_FOR_VCPKG_BUILD"
[ $(printf "%s\n" "$REQUIRED_FOR_NEW_VCPKG_BUILD" "$BASE" | sort -V | head -n1) = $REQUIRED_FOR_NEW_VCPKG_BUILD ] && VCPKG_NEWER_DEPENDENCIES=1 || VCPKG_NEWER_DEPENDENCIES=0

myEcho "VCPKG_NEWER_DEPENDENCIES: $VCPKG_NEWER_DEPENDENCIES"

if [[ ${VCPKG_NEWER_DEPENDENCIES} -eq 1 ]]
then
    # For 8.12.x and beyond
    curl -q -o pkg-config-0.29.2.tar.gz https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz && \
    tar xvfz pkg-config-0.29.2.tar.gz
    pushd  pkg-config-0.29.2
    ./configure --prefix=/usr/local/pkg_config/0_29_2 --with-internal-glib && \
    make && \
    sudo make install 
    popd
    sudo ln -s /usr/local/pkg_config/0_29_2/bin/pkg-config /usr/local/bin/

    [[ ! -d /usr/local/share/aclocal ]] &&  sudo mkdir /usr/local/share/aclocal
    sudo ln -s /usr/local/pkg_config/0_29_2/share/aclocal/pkg.m4 /usr/local/share/aclocal/

    curl -q -o autoconf-2.71.tar.gz http://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz && \
    gunzip autoconf-2.71.tar.gz && \
    tar xvf autoconf-2.71.tar && \
    pushd autoconf-2.71 && \
    ./configure && \
    make && \
    sudo make install
    popd

    curl -q -o autoconf-archive-2021.02.19.tar.xz http://ftp.gnu.org/gnu/autoconf-archive/autoconf-archive-2021.02.19.tar.xz && \
    xz -d -v autoconf-archive-2021.02.19.tar.xz && \
    tar xvf autoconf-archive-2021.02.19.tar && \
    pushd autoconf-archive-2021.02.19 && \
    ./configure && \
    make && \
    sudo make install
    popd

    curl -q -o automake-1.16.5.tar.gz http://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz && \
    tar xvzf automake-1.16.5.tar.gz && \
    pushd automake-1.16.5 && \
    ./configure && \
    make && \
    sudo make install
    popd

    curl -q -o libtool-2.4.6.tar.gz http://ftp.jaist.ac.jp/pub/GNU/libtool/libtool-2.4.6.tar.gz && \
    tar xvfz libtool-2.4.6.tar.gz && \
    pushd libtool-2.4.6 && \
    ./configure --prefix=/usr/local/libtool/2_4_6 && \
    make && \
    sudo make install
    popd

    sudo ln -s /usr/local/libtool/2_4_6/bin/libtool /usr/local/bin/ && \
    sudo ln -s /usr/local/libtool/2_4_6/bin/libtoolize /usr/local/bin/ && \
    sudo ln -s /usr/local/libtool/2_4_6/include/libltdl /usr/local/include/ && \
    sudo ln -s /usr/local/libtool/2_4_6/include/ltdl.h /usr/local/include/ && \
    sudo ln -s /usr/local/libtool/2_4_6/lib/libltdl.a /usr/local/lib/ && \
    sudo ln -s /usr/local/libtool/2_4_6/lib/libltdl.la /usr/local/lib/ && \
    sudo ln -s /usr/local/libtool/2_4_6/lib/libltdl.so /usr/local/lib/ && \
    sudo ln -s /usr/local/libtool/2_4_6/lib/libltdl.so.7 /usr/local/lib/ && \
    sudo ln -s /usr/local/libtool/2_4_6/lib/libltdl.so.7.3.1 /usr/local/lib/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/libtool.m4 /usr/local/share/aclocal/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/ltargz.m4 /usr/local/share/aclocal/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/ltdl.m4 /usr/local/share/aclocal/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/lt~obsolete.m4 /usr/local/share/aclocal/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/ltoptions.m4 /usr/local/share/aclocal/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/ltsugar.m4 /usr/local/share/aclocal/ && \
    sudo ln -s /usr/local/libtool/2_4_6/share/aclocal/ltversion.m4 /usr/local/share/aclocal/ 

    echo /usr/local/lib | sudo tee /etc/ld.so.conf.d/usr_local_lib.conf

    # Build Tools - Mono  ---
    sudo yum-config-manager --add-repo http://download.mono-project.com/repo/centos/
    sudo yum clean all
    sudo yum makecache
    sudo rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"

    sudo yum install -y mono-complete 

else
    # For 8.8x and 8.10.x
    sudo yum install -y  autoconf automake autoconf-archive 
    
    wget  --no-check-certificate https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
    tar xvfz pkg-config-0.29.2.tar.gz
    pushd  pkg-config-0.29.2
    ./configure --prefix=/usr/local/pkg_config/0_29_2 --with-internal-glib
    make -j 8
    sudo make install
    popd
    sudo ln -s /usr/local/pkg_config/0_29_2/bin/pkg-config /usr/local/bin/
    [[ ! -d /usr/local/share/aclocal ]] && mkdir /usr/local/share/aclocal
    sudo ln -s /usr/local/pkg_config/0_29_2/share/aclocal/pkg.m4 /usr/local/share/aclocal/
    ls -l  /usr/local/bin/pkg*
    ls -l /usr/local/share/aclocal/pkg*
    
    echo /usr/local/lib | sudo tee /etc/ld.so.conf.d/usr_local_lib.conf
    
    # Build Tools - Mono  ---
    sudo yum-config-manager --add-repo http://download.mono-project.com/repo/centos/
    sudo yum clean all
    sudo yum makecache
    sudo rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"

    sudo yum install -y mono-complete 
fi
myEcho "Dependencies and versions:"
myEcho "$(which pkg-config 2>&1 )"
myEcho "$(pkg-config --version | head -n 1 2>&1 )"
myEcho "$(rpm -q pkg-config 2>&1 )"

myEcho "$(which autoconf 2>&1 )"
myEcho "$(autoconf --version | head -n 1 2>&1 )"
myEcho "$(rpm -q autoconf 2>&1 )"

myEcho "$(which automake 2>&1 )"
myEcho "$(automake --version | head -n 1 2>&1 )"
myEcho "$(rpm -q automake 2>&1 )"

myEcho "$(which libtool 2>&1 )"
myEcho "$(libtool --version | head -n 1 2>&1 )"
myEcho "$(rpm -q libtool 2>&1 )"

myEcho "$(which mono 2>&1 )"
myEcho "$(mono --version | head -n 1 2>&1 )"
myEcho "$(rpm -q mono 2>&1 )"


#myEcho "Content of /usr/local/share/aclocal/ "
#ls -l  /usr/local/share/aclocal/ 
myEcho "Number of files in '/usr/local/share/aclocal/' is $(find /usr/local/share/aclocal/ -maxdepth 1 -type f | wc -l ) "

echo -e "\n#=====================================================" >> ~/.bashrc
echo "# For VCPKG stuff " >> ~/.bashrc
echo "# " >> ~/.bashrc
echo "export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
echo "export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:\$PKG_CONFIG_PATH" >> ~/.bashrc
echo "export ACLOCAL_PATH=/usr/local/share/aclocal:\$ACLOCAL_PATH" >> ~/.bashrc

echo "export VCPKG_BINARY_SOURCES=\"clear;nuget,GitHub,readwrite\"" >> ~/.bashrc
echo "export VCPKG_NUGET_REPOSITORY=https://github.com/hpcc-systems/vcpkg" >> ~/.bashrc
echo "# end." >> ~/.bashrc

myEcho " $(cat ~/.bashrc) "

if [[ -d /usr/share/systemtap/tapset ]]
then
    myEcho "Set 777 to /usr/share/systemtap/tapset to enable VCPKG (which is not root in this time) \nto copy couchbase related stuff there."
    myEcho "Before:\n $(ls -ld /usr/share/systemtap/tapset)"
    sudo chmod 777 /usr/share/systemtap/tapset
    myEcho "After:\n $(ls -ld /usr/share/systemtap/tapset)"
fi

myEcho "VCPKG done."
myEcho "................................................"

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

if [[ $BASE_TEST -eq 1 ]]
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

myEcho "---------------------------------------------------------------------------------- "
myEcho "Add items for crontab"

prId=${INSTANCE_NAME//PR-/}
INSTANCE_ID=$( wget -q -t1 -T1 -O - http://169.254.169.254/latest/meta-data/instance-id )

# Schedule smoketest in one or two minutes time
[[ $(date "+%S") -ge 30 ]] && timeStep=2 || timeStep=1

# Add environment settings to crotab
(echo "PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/sbin:/usr/sbin:" ; \
 echo "SHELL=/bin/bash" ; \
 crontab -l ) | crontab

DEVTOOLSET=$( scl -l | egrep 'devtoolset' | sort -V | tail -n 1 )
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
        ( crontab -l; echo $( date -d "+$timeStep minute" "+%M %H %d %m") " * source ~/.bashrc; . scl_source enable $DEVTOOLSET; export CL_PATH=/opt/rh/$DEVTOOLSET/root/usr; export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH; cd ~/smoketest; ./update.sh; export commitId=${COMMIT_ID}; export addGitComment=${ADD_GIT_COMMENT}; export runOnce=1; export keepFiles=$KEEP_FILES; export testOnlyOnePR=1; export testPrNo=$prId; export runFullRegression=1; export useQuickBuild=0; export skipDraftPr=0; export AVERAGE_SESSION_TIME=$AVERAGE_SESSION_TIME; export disableFailIfCoreFound=1; ./smoketest.sh" ) | crontab
        
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
( crontab -l; echo ""; echo "# Send Ctrl - C to Regression Test Engine after ${BREAK_TIME} minutes"; echo $( date -d "+${BREAK_TIME} minutes" "+%M %H %d %m") " * REGRESSION_TEST_ENGINE_PID=\$( pgrep -f $PROCESS_TO_KILL ); while [[ -z \"\$REGRESSION_TEST_ENGINE_PID\" ]] ; do date; sleep 10; REGRESSION_TEST_ENGINE_PID=\$( pgrep -f $PROCESS_TO_KILL ); done; echo \"Regression test engine PID(s): \$REGRESSION_TEST_ENGINE_PID\"; sudo kill -SIGINT -- \${REGRESSION_TEST_ENGINE_PID}; sleep 10; sudo kill -SIGINT -- \${REGRESSION_TEST_ENGINE_PID}; " ) | crontab

myEcho "crontab at $(date +%Y.%m%d\ %H:%M:%S)"
myEcho "$( crontab -l )"
myEcho "---------------------------------------------------------------------------------- "

myEcho "Install Bokeh"
p3=$(which "pip3")
myEcho "p3: '$p3'"
res=$(sudo ${p3} install --upgrade pip 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

p3=$(which "pip3")
myEcho "p3: '$p3'"
myEcho "Install pandas bokeh pyproj"
res=$(sudo ${p3} install pandas bokeh pyproj 2>&1 )
[[ $? -ne 0 ]] && echo "Res: $res"
myEcho "  Done"

myEcho "LD_LIBRARY_PATH: '$LD_LIBRARY_PATH'"
export LD_LIBRARY_PATH=/usr/lib:/usr/lib64:$LD_LIBRARY_PATH
myEcho "LD_LIBRARY_PATH: '$LD_LIBRARY_PATH'"
bk=$(which 'bokeh')
myEcho "Bokeh: $bk"
myEcho "$(bokeh info)"

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
