

# Install dependencies
sudo yum install -y tzdata unzip xvfb libxi6
# sudo yum install -y default-jdk # There is not

## Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
sudo yum install -y ./google-chrome-stable_current_x86_64.rpm 

## Chrome Driver
wget https://chromedriver.storage.googleapis.com/2.41/chromedriver_linux64.zip
unzip chromedriver_linux64.zip

sudo mv chromedriver /usr/bin/chromedriver
sudo chown root:root /usr/bin/chromedriver
sudo chmod +x /usr/bin/chromedriver

## Selenium
wget https://selenium-release.storage.googleapis.com/3.141/selenium-server-standalone-3.141.59.jar
wget http://www.java2s.com/Code/JarDownload/testng/testng-6.8.7.jar.zip
unzip testng-6.8.7.jar.zip

## Java Test

export CLASSPATH=".:../selenium-server-standalone-3.141.59.jar:../testng-6.8.7.jar"

## They are shuld be there
#COPY ./run.sh .
#COPY ./tests ./tests

# This is AWS instance specific with 'list ens5'
LOCAL_IP4=$(/sbin/ip -o -4 addr list ens5 | awk '{print $4}' | cut -d/ -f1)
export LOCAL_IP4


#Run:
#----

pushd tests

javac *.java

popd

./run.sh http://$LOCAL_IP4:8010 >eclWatchUiTest.log 2>&1

echo "End of $0"
