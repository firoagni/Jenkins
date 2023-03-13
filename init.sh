#!/bin/bash

jenkinsVersion="lts-jdk11"

# Function to print error message and exit
# $1 = message
printErrMsgAndExit() {
	echo -e "ERROR: $1"
  print_usage
	exit 254
}

# Function to print warning message
# $1 = message
printWarnMsg() {
  echo -e "WARN: $1"
}

# Function to print info message
# $1 = message
printInfoMsg() {
  echo -e "INFO: $1"
}

printLine(){
  echo -e "-------------------------------------"
}

printLine
cd master || printErrMsgAndExit "jenkins: could not cd to master directory"
echo "Building Jenkins master image for version $jenkinsVersion"
cat Dockerfile.template | sed -e "s%SED_JENKINS_VERSION%$jenkinsVersion%"  > ./Dockerfile  || printErrMsgAndExit "Could not set version in Jenkins master Dockerfile"
cp -f plugins.txt.$jenkinsVersion plugins.txt || errExit "Could not copy plugins.txt.$jenkinsVersion"
docker build -t jenkins-master:$jenkinsVersion . 
docker images | grep jenkins-master
printLine