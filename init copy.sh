#!/bin/bash
set -o pipefail

# declare and init values.
selfStr="$(basename $0)"
baseDir="$(dirname $0)"
debugTime=""
# switched to hardcoded value. Need to keep up to date with actual version for DR:
requiredTerraformVersion="v1.1.4"
project=""
control_project=false
region=""
artifact_reg_region=""
zone=""
cluster=""
doNotGenTfvars=""
installJenkins=""
installNexus=""
installSonar=""
ignoreSecrets=""
buildToolsInstallerSA="build-tools-installer"
buildToolsInstallerSAFile=""
tmpPath="$baseDir/../tmp"
agentsBucket=""
importBucket=""
importPath=""
backupPath=""
buildScriptsPath=""
projectGCPZoneName=""
terraformStateBucket=""
jumphostname="hop"
iapBrandName=""
projectNumber=""

# tool specific vars
jenkinsProject=""
jenkinsRegion=""
jenkinsZone=""
jenkinsCluster=""
jenkinsNodePoolName=""
jenkinsMasterNodePoolName=""
jenkinsNameSpace=""
jenkinsNodePoolMType=""
jenkinsNodePoolMin="2"
jenkinsNodePoolMax="15"
jenkinsMasterGCPZone=""
jenkinsMasterDNSZoneName=""
jenkinsMasterDNSName=""
jenkinsVersion="lts"
jenkinsBackupBucket=""
jenkinsBackupSourceFile=""
jenkinsInitScriptFile="jenkins-init.sh"
jenkinsIAPClientID=""
jenkinsIAPClientSecret=""
jenkinsInitContainerCmd=""
jenkinsPostStartCmd=""

nexusProject=""
nexusRegion=""
nexusZone=""
nexusCluster=""
nexusNodePoolName=""
nexusNameSpace=""
nexusNodePoolMType="n1-standard-4"
nexusNodePoolMin="1"
nexusNodePoolMax="5"
nexusMasterGCPZone=""
nexusMasterDNSZoneName=""
nexusMasterDNSName=""
nexusMainVersion="lts"
nexusBackupSourceFile=""
nexusCredentialSourceFile=""
nexusInitScriptFile=""
nexusIAPClientID=""
nexusIAPClientSecret=""
nexusInitContainerCmd=""
nexusPostStartCmd=""
nexusHttpsHost=""
nexushGcsBkpBucket=""
nexusGcsRestoreBucket=""

sonarProject=""
sonarRegion=""
sonarZone=""
sonarCluster=""
sonarNodePoolName=""
sonarNodePoolMType="n1-standard-4"
sonarNodePoolMin="1"
sonarNodePoolMax="5"
sonarMasterGCPZone=""
sonarMasterDNSZoneName=""
sonarMasterDNSName=""
sonarNameSpace=""
sonarPostgresUser=""
sonarHostName=""
sonarPostgresPassword=""
sonarPostgresDatabase=""
sonarPostgresServer=""
sonarPostgresInstance=""
takeBackupSonarID=""
sonarBackupInstance=""
sonarVersion="9.11.0"

# usage func
usage() {
  echo -e "usage: $selfStr -P <project> -R <region> -Z <zone>"
  echo -e "\t-C <cluster> [-z project_gcp_zone_name] [-B <build_tools_bucket>] [-A <service_account_file>] "
  echo -e "\t[-D] [-I] [-T <terraform_version>] [-J]"
  echo
  echo -e "\t-h display help and exit"
  echo -e "\t-D debug: set bash's -x"
  echo -e "\t-I ignore errors if K8s secrets exist already"
  echo -e "\t-T <version> required Terraform version string (eg 'v0.12.24'). Default is $requiredTerraformVersion"
  echo -e "\t-P <project>"
  echo -e "\t-c <control_project> true only for ss-pp-control-d ss-pp-control-p projects.It's optional for others"
  echo -e "\t-R <region>"
  echo -e "\t-a <artifact_reg_region>"
  echo -e "\t-Z <zone>"
  echo -e "\t-C <cluster_name>"
  echo -e "\t-A <service_account_file> optional"
  echo -e "\t-B <build_tools_bucket_name> optional"
  echo -e "\t-z <project_gcp_zone_name> GCP zone name, tools specific options can override "
  echo -e "\t-J install jenkins"
  echo -e "\tThe following only apply if -J is specified"
  echo -e "\t\t-jP=<project>  defaults to -P value"
  echo -e "\t\t-jR=<region>  defaults to -R value"
  echo -e "\t\t-jZ=<zone>  defaults to -Z value"
  echo -e "\t\t-jN=<name_space>  defaults to 'jenkins'"
  echo -e "\t\t-jp=<node_pool_name> defaults to 'jenkins-node-pool'"
  echo -e "\t\t-jt=<node_pool_type> defaults to 'n2-standard-8'"
  echo -e "\t\t-jm=<node_pool_minimum> defaults to '2'"
  echo -e "\t\t-jM=<node_pool_maximum> defaults to '15'"
  echo -e "\t\t-jz=<gcp_zone_name> default to -z value"
  echo -e "\t\t-jn=<host_dns_name> no default"
  echo -e "\t\t-jv=<jenkins_image_version> defaults to '$jenkinsVersion'"
  echo -e "\t\t-jb=<gcs_jenkins_backup_file> defaults to gs://<-B value>/backups/latestFile "
  echo -e "\t\t-ji=<IAP_client_ID> no default. Script will prompt for a value."
  echo -e "\t\t-js=<IAP_client_secret> no default. Script will prompt for a value."
  echo -e "\t\t-jI=<initContainer commands> defaults to script to restore jenkin's home."
  echo -e "\t\t-jS=<postStart commands> defaults to 'echo'"
  echo -e "\t-N install Nexus"
  echo -e "\tThe following only apply if -N is specified"
  echo -e "\t\t-nP=<project>  defaults to -P value"
  echo -e "\t\t-nR=<region>  defaults to -R value"
  echo -e "\t\t-nZ=<zone>  defaults to -Z value"
  echo -e "\t\t-nN=<name_space>  defaults to 'nexus'"
  echo -e "\t\t-np=<node_pool_name> defaults to 'nexus-node-pool'"
  echo -e "\t\t-nt=<node_pool_type> defaults to 'n1-standard-4'"
  echo -e "\t\t-nm=<node_pool_minimum> defaults to '1'"
  echo -e "\t\t-nM=<node_pool_maximum> defaults to '5'"
  echo -e "\t\t-nz=<gcp_zone_name> default to -z value"
  echo -e "\t\t-nn=<host_dns_name> no default"
  echo -e "\t\t-nv=<nexus_image_version> defaults to '$nexusMainVersion'"
  echo -e "\t\t-nr=<nexus-restore-bucket> defaults to empty value, if set restore procedure will start"
  echo -e "\t-S install Sonar"
  echo -e "\tThe following only apply if -S is specified"
  echo -e "\t\t-sP=<project>  defaults to -P value"
  echo -e "\t\t-sR=<region>  defaults to -R value"
  echo -e "\t\t-sZ=<zone>  defaults to -Z value"
  echo -e "\t\t-sN=<name_space>  defaults to 'sonar'"
  echo -e "\t\t-sp=<node_pool_name> defaults to 'sonar-node-pool'"
  echo -e "\t\t-st=<node_pool_type> defaults to 'n1-standard-4'"
  echo -e "\t\t-sm=<node_pool_minimum> defaults to '1'"
  echo -e "\t\t-sM=<node_pool_maximum> defaults to '10'"
  echo -e "\t\t-sz=<gcp_zone_name> default to -z value"
  echo -e "\t\t-sn=<host_dns_name> no default"
  echo -e "\t\t-sd=<postgres_database_name> defaults to 'postgres'"
  echo -e "\t\t-su=<postgres_user> defaults to 'postgres'"
  echo -e "\t\t-sw=<postgres_password> no default"
  echo -e "\t\t-si=<postgres_instance_name> defaults to 'system-sonar-x"
  echo -e "\t\t-sb=<take_backup_sonar_id> no default"
  echo -e "\t\t-ss=<sonar_backup_instance> no default"
  echo -e "\t"
}

# this allows single char sub-flags like -jB=asdf  -jc=ghjk
#  like -jP= for Jenkins project option, -nP= for Nexus project option
#  $1 = getops' OPTARG value
subopt() {
  # cut the first char
	SUBOPT=`echo "$1" |  cut -c 1`
  # set the value, remove opt char and =
	SUBOPTARG=`echo "$1" | colrm 1 2`
}

# save typing use with ||
errExit() {
	# $1 = message
	# $2 = exit code
  # $3 = show help. optional
  [[ ! -z "$3" ]] && usage
	echo -e "$selfStr: ERROR: $1"
	[[ ! -z "$2" ]] || exit $2
	exit 254
}
errWarn() {
  # $1 = message
  echo -e "$selfStr: WARNING: $1"
}
errInfo() {
  # $1 = message
  echo -e "$selfStr: INFO: $1"
}

# tips and tricks: you can use this one liner to generate the while/case skeleton from the getopts string:
#myoptlist="hDP:R:Z:C:"; echo -e "while getopts \"$myoptlist\" OPT; do\n\tcase \$OPT in" ; for x in $( theChar=":"; count=1; until [[  -z "$theChar" ]]; do theChar=`echo "$myoptlist" | cut -c $count`; [[ ! "$theChar" == ":" ]] &&  echo $theChar; count=$(( $count + 1)); done ); do echo -e "\t\t${x})\n\t\t\techo \$OPTARG\n\t\t;;"; done; echo -e "\tesac\ndone"
while getopts "hDGIT:A:B:P:R:Z:C:z:JNSj:n:s:a:c:" OPT; do
  case $OPT in
    h)
      usage
      exit 0
    ;;
    D)
      debugTime="Y"
      # catch all way to debug. maybe instrument better later
        set -x
    ;;
    I)
      ignoreSecrets="Y"
    ;;
    T)
      requiredTerraformVersion="$OPTARG"
    ;;
    A)
     buildToolsInstallerSAFile="$OPTARG"
    ;;
    P)
      project="$OPTARG"
    ;;
    c)
      control_project="$OPTARG"
    ;;
    R)
      region="$OPTARG"
    ;;
    a)
      artifact_reg_region="$OPTARG"
    ;; 
    Z)
      zone="$OPTARG"
    ;;
    B)
      #these are for build cluster level:
      importBucket="$OPTARG"
    ;;
    C)
      cluster="$OPTARG"
    ;;
    z)
      projectGCPZoneName="$OPTARG"
    ;;
    J)
      installJenkins="Y"
    ;;
    N)
      installNexus="Y"
    ;;
    S)
      installSonar="Y"
    ;;
    j)
      # all jenkins specific
      subopt "$OPTARG"
      case $SUBOPT in
        P)
          jenkinsProject="$SUBOPTARG"
        ;;
        R)
          jenkinsRegion="$SUBOPTARG"
        ;;
        Z)
          jenkinsZone="$SUBOPTARG"
        ;;
        N)
          jenkinsNameSpace="$SUBOPTARG"
        ;;
        p)
          jenkinsNodePoolName="$SUBOPTARG"
        ;;
        t)
          jenkinsNodePoolMType="$SUBOPTARG"
        ;;
        m)
          jenkinsNodePoolMin="$SUBOPTARG"
        ;;
        M)
          jenkinsNodePoolMax="$SUBOPTARG"
        ;;
        z)
          jenkinsMasterGCPZone="$SUBOPTARG"
        ;;
        n)
          jenkinsMasterDNSName="$SUBOPTARG"
          # DNSZoneName is the dns name for the zone. like
          jenkinsMasterDNSZoneName=`echo "$jenkinsMasterDNSName" | awk -F. '{for (x=3; x < NF; x++) printf $x "."}END{printf "\n"}'`
          jenkinsMasterBuildDNSName="$(echo "$jenkinsMasterDNSName" | cut -d'.' -f1)-build.$(echo "$jenkinsMasterDNSName" | cut -d'.' -f2-4)."
        ;;
        v)
          jenkinsVersion="$SUBOPTARG"
        ;;
        b)
          jenkinsBackupSourceFile="$SUBOPTARG"
        ;;
        c)
          jenkinsCredentialSourceFile="$SUBOPTARG"
        ;;
        i)
          jenkinsIAPClientID="$SUBOPTARG"
        ;;
        s)
          jenkinsIAPClientSecret="$SUBOPTARG"
        ;;
        I)
          jenkinsInitContainerCmd="$SUBOPTARG"
        ;;
        S)
          jenkinsPostStartCmd="$SUBOPTARG"
        ;;
        *)
          errExit "unknown option: $OPT$SUBOPT=$SUBOPTARG" 1
        ;;
      esac
    ;;
    n)
      # all Nexus specific
      subopt "$OPTARG"
      case $SUBOPT in
        P)
          nexusProject="$SUBOPTARG"
        ;;
        R)
          nexusRegion="$SUBOPTARG"
        ;;
        Z)
          nexusZone="$SUBOPTARG"
        ;;
        N)
          nexusNameSpace="$SUBOPTARG"
        ;;
        p)
          nexusNodePoolName="$SUBOPTARG"
        ;;
        t)
          nexusNodePoolMType="$SUBOPTARG"
        ;;
        m)
          nexusNodePoolMin="$SUBOPTARG"
        ;;
        M)
          nexusNodePoolMax="$SUBOPTARG"
        ;;
        z)
          nexusMasterGCPZone="$SUBOPTARG"
        ;;
        n)
          nexusMasterDNSName="$SUBOPTARG"
          # DNSZoneName is the dns name for the zone. like
          nexusMasterDNSZoneName=`echo "$nexusMasterDNSName" | awk -F. '{for (x=3; x < NF; x++) printf $x "."}END{printf "\n"}'`
        ;;
        v)
          nexusMainVersion="$SUBOPTARG"
        ;;
        b)
          nexusBackupVersion="$SUBOPTARG"
        ;;
        r)
          nexusGcsRestoreBucket="$SUBOPTARG"
        ;;
        *)
          errExit "unknown option: $OPT$SUBOPT=$SUBOPTARG" 1
        ;;
      esac
    ;;
    s)
      # all Sonar specific
      subopt "$OPTARG"
      case $SUBOPT in
        P)
          sonarProject="$SUBOPTARG"
        ;;
        R)
          sonarRegion="$SUBOPTARG"
        ;;
        Z)
          sonarZone="$SUBOPTARG"
        ;;
        N)
          sonarNameSpace="$SUBOPTARG"
        ;;
        p)
          sonarNodePoolName="$SUBOPTARG"
        ;;
        t)
          sonarNodePoolMType="$SUBOPTARG"
        ;;
        m)
          sonarNodePoolMin="$SUBOPTARG"
        ;;
        M)
          sonarNodePoolMax="$SUBOPTARG"
        ;;
        z)
          sonarMasterGCPZone="$SUBOPTARG"
        ;;
        n)
          sonarMasterDNSName="$SUBOPTARG"
          # DNSZoneName is the dns name for the zone. like
          sonarMasterDNSZoneName=`echo "$sonarMasterDNSName" | awk -F. '{for (x=3; x < NF; x++) printf $x "."}END{printf "\n"}'`
        ;;
        d)
          sonarPostgresDatabase="$SUBOPTARG"
        ;;
        u)
          sonarPostgresUser="$SUBOPTARG"
        ;;
        w)
          sonarPostgresPassword="$SUBOPTARG"
        ;;
        i)
          sonarPostgresInstance="$SUBOPTARG"
        ;;
        b)
          takeBackupSonarID="$SUBOPTARG"
        ;;
        s)
          sonarBackupInstance="$SUBOPTARG"
        ;;
        v)
          sonarVersion="$SUBOPTARG"
        ;;
        *)
          errExit "unknown option: $OPT$SUBOPT=$SUBOPTARG" 1
        ;;
      esac
    ;;
    *)
      # catch all
      errExit "unknown option: $OPT" 1 Y
    ;;
  esac
done

if [[ "$project" == "ss-pp-control-d" || "$project" == "ss-pp-control-p" ]]; then 
  # these globals are required options to run
  [[ -z "$project" ]] && errExit "-P not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$control_project" ]] && errExit "-CP not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$region" ]] && errExit "-R not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$artifact_reg_region" ]] && errExit "-a not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$zone" ]] && errExit "-Z not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$cluster" ]] && errExit "-C not set. Please read the README.md and/or use -h for help" 1
else
  # these globals are required options to run
  [[ -z "$project" ]] && errExit "-P not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$region" ]] && errExit "-R not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$artifact_reg_region" ]] && errExit "-a not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$zone" ]] && errExit "-Z not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$cluster" ]] && errExit "-C not set. Please read the README.md and/or use -h for help" 1
fi
# more globals are not required options to run
[[ ! -z "$buildToolsInstallerSAFile"  && ! -f $buildToolsInstallerSAFile ]] && errExit "-A set and file not found. Please read the README.md and/or use -h for help" 1
[[ -z "$importBucket" ]] && importBucket="${project}-build-tools"
backupPath="gs://$importBucket/data/restore"
buildScriptsPath="gs://$importBucket/scripts"
terraformStateBucket="$project-terraform-state"
[[ -z "$agentsBucket" ]] && agentsBucket="${project}-agents"

# optional stuff for jenkins and set defaults:
if [[ ! -z "$installJenkins" ]]; then
  # required for jenkins:
  # use -z value unless -jz= override is set
  if [[ -z "$jenkinsMasterGCPZone" ]]; then
    [[ -z "$projectGCPZoneName" ]] && errExit "-z and/or -jz= not set. Please read the README.md and/or use -h for help" 1
    jenkinsMasterGCPZone="$projectGCPZoneName"
  fi
  [[ -z "$jenkinsMasterDNSName" ]] && errExit "-jn= not set. Please read the README.md and/or use -h for help" 1

  # set defaults if not already set:
  [[ -z "$jenkinsProject" ]]  && jenkinsProject="$project"
  [[ -z "$jenkinsRegion" ]]  && jenkinsRegion="$region"
  [[ -z "$jenkinsZone" ]]  && jenkinsZone="$zone"
  [[ -z "$jenkinsCluster" ]]  && jenkinsCluster="$cluster"
  [[ -z "$jenkinsNameSpace" ]]  && jenkinsNameSpace="jenkins"
  [[ -z "$jenkinsNodePoolName" ]]  && jenkinsNodePoolName="jenkins-node-pool"
  [[ -z "$jenkinsMasterNodePoolName" ]]  && jenkinsMasterNodePoolName="jenkins-master-node-pool"
  if [[ "$project" == "ss-pp-control-d" || "$project" == "ss-pp-control-p" ]]; then
    [[ -z "$jenkinsNodePoolMType" ]] && jenkinsNodePoolMType="n1-standard-8"
  else
    [[ -z "$jenkinsNodePoolMType" ]] && jenkinsNodePoolMType="n2-standard-8"
  fi
  [[ -z "$jenkinsNodePoolMin" ]] && jenkinsNodePoolMin="2"
  [[ -z "$jenkinsNodePoolMax" ]] && jenkinsNodePoolMax="15"
  [[ -z "$jenkinsBackupBucket" ]] && jenkinsBackupBucket="$project-jenkins-backups"
  [[ -z "$jenkinsVersion" ]] && errExit "-jv= was unset somehow." 1
  # if not manually set, populate based on cluster level values that should have been checked already
  [[ -z "$jenkinsBackupSourceFile" ]] && jenkinsBackupSourceFile="$backupPath/jenkins/backup.tar.gz"
fi

# for jenkins only install, need all node pool names until it can be re-factored
if [[ -z "$installNexus" ]]; then
  [[ -z "$nexusNodePoolName" ]]  && nexusNodePoolName="nexus-node-pool"
fi
if [[ -z "$installSonar" ]]; then
  [[ -z "$sonarNodePoolName" ]]  && sonarNodePoolName="sonarqube-node-pool"
fi
# required for nexus:
# optional stuff for nexus. Set defaults
if [[ ! -z "$installNexus" ]]; then
# required for jenkins:
  # use -z value unless -nz= override is set
  if [[ -z "$nexusMasterGCPZoneName" ]]; then
    [[ -z "$projectGCPZoneName" ]] && errExit "-z and/or -nz= not set. Please read the README.md and/or use -h for help" 1
    nexusMasterGCPZone="$projectGCPZoneName"
    nexusMasterDNSZoneName="$projectGCPZoneName"
  fi
  [[ -z "$nexusMasterDNSZoneName" ]] && errExit "-jn= not set. Please read the README.md and/or use -h for help" 1
  [[ -z "$nexusProject" ]]  && nexusProject="$project"
  [[ -z "$nexusRegion" ]]  && nexusRegion="$region"
  [[ -z "$nexusZone" ]]  && nexusZone="$zone"
  [[ -z "$nexusNameSpace" ]]  && nexusNameSpace="nexus"
  [[ -z "$nexusNodePoolName" ]]  && nexusNodePoolName="nexus-node-pool"
  [[ -z "$nexusNodePoolMType" ]] && nexusNodePoolMType="n1-standard-8"
  [[ -z "$nexusNodePoolMin" ]] && nexusNodePoolMin="1"
  [[ -z "$nexusNodePoolMax" ]] && nexusNodePoolMax="2"
  [[ -z "$nexusMainVersion" ]] && errExit "-nv= was unset somehow." 1
  # set default import locations
  #nexusBackupSourcePath="$backupPath/nexus/backup.tar.gz"
  #nexusCredentialSourcePath="$credsPath/nexus/creds.tar.gz"
fi

# required for sonar:
# optional stuff for sonar. Set defaults
if [[ ! -z "$installSonar" ]]; then
  # use -z value unless -sz= override is set
  if [[ -z "$sonarMasterGCPZone" ]]; then
    [[ -z "$projectGCPZoneName" ]] && errExit "-z and/or -nz= not set. Please read the README.md and/or use -h for help" 1
    sonarMasterGCPZone="$projectGCPZoneName"
  fi
  [[ -z "$sonarProject" ]]  && sonarProject="$project"
  [[ -z "$sonarRegion" ]]  && sonarRegion="$region"
  [[ -z "$sonarZone" ]]  && sonarZone="$zone"
  [[ -z "$sonarNameSpace" ]]  && sonarNameSpace="sonar"
  [[ -z "$sonarNodePoolName" ]]  && sonarNodePoolName="sonarqube-node-pool"
  [[ -z "$sonarNodePoolMType" ]] && sonarNodePoolMType="n1-standard-4"
  [[ -z "$sonarNodePoolMin" ]] && sonarNodePoolMin="1"
  [[ -z "$sonarNodePoolMax" ]] && sonarNodePoolMax="5"
  [[ -z "$sonarPostgresDatabase" ]] && sonarPostgresDatabase=postgres
  [[ -z "$sonarPostgresUser" ]] && sonarPostgresUser=postgres
  [[ -z "$sonarPostgresInstance" ]] && errExit "-si= unset somehow." 1
  [[ -z "$sonarVersion" ]] && errExit "sonarVersion unset somehow." 1
  # set default import locations
  #sonarBackupSourcePath="$backupPath/sonar/backup.tar.gz"
  #sonarCredentialSourcePath="$credsPath/sonar/creds.tar.gz"
fi

# regenerate this list by scanning the script with the below line, and cut and paste:
# cat init.sh | grep "\[\[ -z" | awk '{print $3}' | awk -F\$ '{print $2}' | gawk -F\" '{print "  echo \"" $1 "=$" $1 "\""}'
if [[  -z "$debugTime" ]]; then
  echo ""
  echo "project=$project"
  echo "region=$region"
  echo "artifact_reg_region=$artifact_reg_region"
  echo "zone=$zone"
  echo "cluster=$cluster"
  echo "requiredTerraformVersion=$requiredTerraformVersion"
  echo "jenkinsMasterGCPZone=$jenkinsMasterGCPZone"
  echo "jenkinsMasterDNSZoneName=$jenkinsMasterDNSZoneName"
  echo "jenkinsMasterDNSName=$jenkinsMasterDNSName"
  echo "jenkinsBackupSourceFile=$jenkinsBackupSourceFile"
  echo "buildScriptsPath=$buildScriptsPath"
  echo "jenkinsProject=$jenkinsProject"
  echo "jenkinsRegion=$jenkinsRegion"
  echo "jenkinsZone=$jenkinsZone"
  echo "jenkinsCluster=$jenkinsCluster"
  echo "jenkinsNameSpace=$jenkinsNameSpace"
  echo "jenkinsNodePoolName=$jenkinsNodePoolName"
  echo "jenkinsMasterNodePoolName=$jenkinsMasterNodePoolName"
  echo "jenkinsNodePoolMType=$jenkinsNodePoolMType"
  echo "jenkinsNodePoolMin=$jenkinsNodePoolMin"
  echo "jenkinsNodePoolMax=$jenkinsNodePoolMax"
  echo "nexusProject=$nexusProject"
  echo "nexusRegion=$nexusRegion"
  echo "nexusZone=$nexusZone"
  echo "nexusNameSpace=$nexusNameSpace"
  echo "nexusGcsRestoreBucket=$nexusGcsRestoreBucket"
  echo "sonarProject=$sonarProject"
  echo "sonarRegion=$sonarRegion"
  echo "sonarZone=$sonarZone"
  echo "sonarNameSpace=$sonarNameSpace"
fi

# check paths and files, requirements
if [[ ! -d "$tmpPath" ]]; then
  mkdir -p $tmpPath || errExit "could not create $tmpPath"  2
fi
# check for terraform and any version requirements
terraform -v > /dev/null 2>&1  || errExit "terraform: not installed or not in path." 2
if [[ ! -z "$requiredTerraformVersion" ]] ; then
  tfVer="`terraform -v | head  -1  | awk '{print $2}'`"
  [[ "$requiredTerraformVersion" == "$tfVer" ]] || errExit "terraform: incorrect version installed. Check README.md and options" 2
fi

# export anything needed
export PROJECT_ID="$project"

###################################
# breakout here if you are doing parameter testing
#  exit 0
###################################

[[ `uname` == "Linux" ]]  || errExit "This has only been tested on Linux in a gcp Cloud Shell" 2

# let the user know if not logged in
gcloud auth list
[[ $? -eq 0 ]] || errExit "gcloud auth check failed" 2

errInfo "Enabling GCP APIs"
# enable any GCP APIs
# enabled by Zebra IT at project creation time, but just in case:
ITapiList="compute.googleapis.com \
  firebase.googleapis.com \
  bigquery.googleapis.com \
  container.googleapis.com \
  recommender.googleapis.com \
  stackdriver.googleapis.com \
  storage-api.googleapis.com \
  storage-component.googleapis.com \
  storage.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  cloudbilling.googleapis.com \
  billingbudgets.googleapis.com \
  pubsub.googleapis.com \
  cloudresourcemanager.googleapis.com \
  oslogin.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com"
# anything else _for build tools only_, add here. Anything related to applications should be in application terraform and applied to the target project.
# note: spanner.googleapis.com added because probably a bug in terraform/gcloud - without enabling this API it is not possible to create instance in target project (04-27-2021)
otherAPIsList="containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  dns.googleapis.com \
  iam.googleapis.com \
  iap.googleapis.com \
  cloudkms.googleapis.com \
  osconfig.googleapis.com \
  secretmanager.googleapis.com \
  spanner.googleapis.com \
  dataflow.googleapis.com \
  binaryauthorization.googleapis.com"

for x in $ITapiList $otherAPIsList ; do
#TODO: should check if enabled, enable if not, and errExit on failed enable call
  gcloud services enable $x
  [[ $? -ne 0 ]] || errWarn "Could not enable API: $x"
done

# create SAs, if they do not exist. (consider disabling any only needed for the buildtools install when done)
# add terraform SA used to deploy applications in other projects here, maybe?
errInfo "Creating service account(s)"
saList="$buildToolsInstallerSA"
for x in $saList ; do
  gcloud iam service-accounts list --format='get(email)' | grep "^${x}@${project}.iam.gserviceaccount.com$" > /dev/null
  # if doesn't exist, create. If disabled, enable.
  if [[ $? -eq 1 ]]; then
    gcloud iam service-accounts create ${x}  || errExit "Could not create SA: $x" 5
  else
    isEnabled=`gcloud iam service-accounts list --format='get(email,disabled)' | grep "${x}@${project}.iam.gserviceaccount.com" | awk '{print $2}'`
    [[ "$isEnabled" == "False" ]] && gcloud iam service-accounts enable "${x}@${project}.iam.gserviceaccount.com" || errExit "Could not enable SA: $x" 5
  fi
done

# create terrform bucket. chicken and egg with teraform so create here.
errInfo "Creating GCS bucket for Terraform State, if it does not exist"
gsutil ls gs:// | grep "gs://$terraformStateBucket/" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  gsutil mb -p $project -c REGIONAL -l $region gs://$terraformStateBucket || errExit "could not create terraform state bucket" 5
fi
gsutil versioning set on gs://$terraformStateBucket || errExit "could not enable versioning for terraform bucket" 5

# create build-tools bucket.
#TODO: eliminate interaction if possible. add yet another option?
errInfo "Create GCS Bucket for restoring backups, if it does not exist"
gsutil ls gs:// | grep "gs://$importBucket/" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  # if the bucket didn't exist, then the tar balls are not there. Give the user a chance to upload them.
  gsutil mb -p $project  -c REGIONAL -l $region gs://$importBucket || errExit "could not create build tools bucket" 5
  echo  -e "INPUT NEEDED\nThe $project-build-tools bucket has been created, please upload the backup tarball now\nIt is safe to ctl-C now also. Just rerun this script when ready."
  read -p "Press Enter to continue. ctl-C to break" dummyvariable
fi

# create agents bucket.
#TODO: eliminate interaction if possible. add yet another option?
errInfo "Create GCS Bucket for Sec-Agents if it does not exist"
gsutil ls gs:// | grep "gs://$agentsBucket/" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  # if the bucket didn't exist, then the tar balls are not there. Give the user a chance to upload them.
  gsutil mb -p $project  -c REGIONAL -l $region gs://$agentsBucket || errExit "could not create build tools bucket" 5
  echo  -e "INPUT NEEDED\nThe $agentsBucket bucket has been created, please upload the sec-agents zip, deb, and rpm files now\nIt is safe to ctl-C now also. Just rerun this script when ready."
  read -p "Press Enter to continue. ctl-C to break" dummyvariable
fi

# grant SA read/write to bucket with agents:
gsutil iam ch serviceAccount:$buildToolsInstallerSA@${project}.iam.gserviceaccount.com:legacyBucketWriter,legacyBucketReader,legacyObjectReader gs://$agentsBucket || errExit "could not grant $buildToolsInstallerSA to $agentsBucket" 5

# grant SA read/write to bucket with backups:
gsutil iam ch serviceAccount:$buildToolsInstallerSA@${project}.iam.gserviceaccount.com:legacyBucketWriter,legacyBucketReader,legacyObjectReader gs://$importBucket || errExit "could not grant $buildToolsInstallerSA to $importBucket" 5

# create logs bucket
errInfo "Creating logging bucket"
logsBucket="${project}-logs-bucket"
gsutil ls gs:// | grep "gs://$logsBucket/" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  gsutil mb -p $project -c REGIONAL -l $region gs://$logsBucket || errExit "could not create logs bucket $logsBucket" 5
  #Keep logs for 1 year
  echo '{"rule": [{"action": {"type": "Delete"},"condition": {"age": 365}}]}' >lifetime.json
  gsutil lifecycle set lifetime.json gs://$project-logs-bucket || errExit "could not set lifecycle" 5
  rm lifetime.json
  # grant access to logsBucket
  gsutil iam ch group:cloud-storage-analytics@google.com:legacyBucketWriter gs://$logsBucket || errExit "could not grant perms on bucket $logsBucket" 5
fi
# turn on logging
gsutil logging set on -b gs://$logsBucket -o log_object_prefix gs://$terraformStateBucket gs://$importBucket || errExit "could not set logging on bucket $logBucket" 5

#*********************
# IAP Brand Name resource CANNOT be deleted once created. So jumping through hoops here in case previous run created it
# iapbrand level
errInfo "Creating or importing IAP Brand resource"
cd $baseDir/../iapbrand || errExit "iapbrand: could not cd to iapbrand directory" 10
projectNumber=`gcloud projects describe $project | grep projectNumber | awk -F\' '{print $2}'` || errExit "iapbrand: could not get the projectNumber" 10
iapBrandName="projects/${projectNumber}/brands/${projectNumber}"

# get the IAP Brand name from TF outputs
terraform init -backend-config="bucket=$terraformStateBucket"  || errExit "iapbrand: could not terraform init" 10
terraform apply  -auto-approve  || errWarn "iapbrand: could not terraform apply; IAP Brand probably exist already"

##########
errInfo "**************"
errInfo "This only needs to be done ONCE, but you might want to confirm:"
errInfo "  You must set the Authorized Domain Manually. Go to the URL"
errInfo "  https://console.cloud.google.com/apis/credentials/consent?cloudshell=false&project=${project}"
errInfo "  Click 'Edit App' next to 'OAuth Tooling'"
errInfo "  Under 'Authorized domains' Click '+Add Domain'"
errInfo "    Enter  'zebra.engineering'"
errInfo "  Developer contact information:"
errInfo "    Enter email address."
errInfo "  Click Save and Continue."
errInfo "  Click Save and Continue."
errInfo "**************"
errInfo "*** Please press Enter to Continue once complete"
read -p "waiting for you> " dummyvariable

cd $baseDir/../buildcluster || errExit "buildcluster: could not cd to buildcluster directory" 15
# create terraform.tfvars  unless doNotGenTfvars is set
if [[ -z "$doNotGenTfvars" ]]; then
  echo "# WARNING: This will be replaced by the build scripts by default. check script options." > terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "project=\"$project\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "region=\"$region\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "zone=\"$zone\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "cluster=\"$cluster\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "gcp_zone=\"${projectGCPZoneName}-zebra-engineering\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "dns_zone_name=\"${projectGCPZoneName}.zebra.engineering.\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "jumphostname=\"${jumphostname}\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "sonar_node_pool=\"$sonarNodePoolName\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "sonar_node_pool_m_type=\"$sonarNodePoolMType\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "sonar_node_pool_min=$sonarNodePoolMin" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "sonar_node_pool_max=$sonarNodePoolMax" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "nexus_node_pool=\"$nexusNodePoolName\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "nexus_node_pool_m_type=\"$nexusNodePoolMType\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "nexus_node_pool_min=$nexusNodePoolMin" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "nexus_node_pool_max=$nexusNodePoolMax" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "jenkins_node_pool=\"$jenkinsNodePoolName\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "jenkins_master_node_pool=\"$jenkinsMasterNodePoolName\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "jenkins_node_pool_m_type=\"$jenkinsNodePoolMType\"" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "jenkins_node_pool_min=$jenkinsNodePoolMin" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
  echo "jenkins_node_pool_max=$jenkinsNodePoolMax" >> terraform.tfvars || errExit "buildcluster: could not create terraform.tfvar" 15
fi

###################################
# exit here to test before terraform creates infrastructure
# echo "exiting before any terraform plan/apply "
# exit 0
###################################

# not sure how else to do this. We need the GCR bucket to exist to grant perms for GKE SA in TF.
#    BUT, GCR doesn't look like it creates the bucket until something is added to GCR:
errInfo "Initializing GCR"
# Authorize docker to use gcr
gcloud auth configure-docker
docker pull busybox || errExit "could not prep gcr with dummy docker image" 20
docker tag busybox ${artifact_reg_region}-docker.pkg.dev/$project/phoenix-images/busybox || errExit "could not prep gcr with dummy docker image" 20
docker push ${artifact_reg_region}-docker.pkg.dev/$project/phoenix-images/busybox || errExit "could not prep gcr with dummy docker image" 20

# Authorize docker to use AR and creating repo
gcloud auth configure-docker ${artifact_reg_region}-docker.pkg.dev
gcloud auth list
[[ $? -eq 0 ]] || errExit "gcloud auth check failed" 2

# Repo creation
repo="$(gcloud --project=$project artifacts repositories list --location=${artifact_reg_region}|grep -o phoenix-images)"
echo "$repo"

if [[ $repo == "phoenix-images" ]];
then
        echo "repo already exist"
    
else
        echo "creating the repository"
              
        gcloud --project=$project artifacts repositories create phoenix-images \
                    --repository-format=Docker \
                        --location=${artifact_reg_region} \
                            --description=" gcr repositories" \
                                --async
fi

# Apply shared infrastructure:
errInfo "Applying Terraform"
terraform init -backend-config="bucket=$terraformStateBucket"  || errExit "could not terraform init" 25
terraform plan  || errExit "buildcluster: could not terraform plan" 25
terraform apply || errExit "buildcluster: could not terraform apply" 25

# Need to grant the SA the GKE cluster is running as (buildtools-gke-sa) access to the restore bucket
gsutil iam ch serviceAccount:buildtools-gke-sa@${project}.iam.gserviceaccount.com:legacyBucketWriter,legacyBucketReader,legacyObjectReader gs://$importBucket || errExit "could not grant buildtools-gke-sa to $importBucket" 27

# jumphost and GKE cluster should be available now.
# Setting up IAP here to allow access to private GKE
errInfo "Setting up host for IAP ssh tunnel"
export KUBECONFIG=~/.kube/$cluster
gcloud container clusters get-credentials "$cluster" --region "$region" --project ${project} || errExit "could not get GKE credentials" 30
endpoint=$(gcloud container clusters describe ${cluster} --project ${project} --region ${region} --format="value(endpoint)") || errExit "could not get GKE endpoint" 30

# check if kubernetes host is present in /etc/hosts file
grep "kubernetes kubernetes.default" /etc/hosts >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "Configuring /etc/hosts. Adding entry"
  echo "127.0.0.1 kubernetes kubernetes.default" | sudo tee -a /etc/hosts || errExit "could not update /etc/hosts" 30
else
  echo "/etc/hosts already configured"
fi
# Replace cluster endpoint IP with a host:port
if [[ $(uname -s) == "Darwin" ]]; then
  /usr/bin/sed -i '' "s/${endpoint}/kubernetes.default:8443/g" $KUBECONFIG
else
  sed -i "s/${endpoint}/kubernetes.default:8443/g" $KUBECONFIG
fi || errExit "could not update GKE IAP tunnel" 30

# Check if the tunnel is already running
if [[ $(uname -s) == "Darwin" ]]; then
  sudo netstat -an | grep LISTEN |grep 127.0.0.1.8443 >/dev/null 2>&1
else
  netstat -tulpn | grep LISTEN |grep 127.0.0.1:8443 >/dev/null 2>&1
fi

if [[ $? -ne 0 ]]; then
  errInfo "Starting IAP tunnel"
  gcloud beta compute ssh $jumphostname --zone ${zone} --project ${project} --tunnel-through-iap --ssh-flag="-f -N -L 8443:${endpoint}:443" || errExit "could not start iap tunnel" 30
else
  errWarn "Port is in use. Tunnel is already running?"
fi
# test
kubectl get nodes || errExit "could not connect to GKE cluster over IAP ssh tunnel" 30

#*********************
# nexus level
if [[ ! -z "$installNexus" ]]; then
  errInfo "Installing Nexus"
  cd ../nexus
  errInfo "Applying Nexus Terraform"
  # create terraform.tfvars unless doNotGenTfvars is set
  if [[ -z "$doNotGenTfvars" ]]; then
    nexushGcsBkpBucket="gs://${project}-nexus-backup"
    nexusMainImageVersion="${artifact_reg_region}-docker.pkg.dev/$project/phoenix-images/docker-nexus-main:${nexusMainVersion}"
    nexusBackupImageVersion="${artifact_reg_region}-docker.pkg.dev/$project/phoenix-images/docker-nexus-backup:${nexusBackupVersion}"
    nexusHostName="${nexusMasterDNSName%?}"
    echo "# WARNING: This will be replaced by the build scripts by default. check script options." > terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "project=\"$project\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "region=\"$region\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "zone=\"$zone\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "cluster=\"$cluster\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "nexus_gcp_zone=\"${nexusMasterGCPZone}-zebra-engineering\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "nexus_dns_zone_name=\"${nexusMasterDNSZoneName}.zebra.engineering.\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "nexus_dns_name=\"$nexusMasterDNSName\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "nexus_namespace=\"nexus\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
    echo "iap_brand_name=\"$iapBrandName\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 35
  fi
  terraform init -backend-config="bucket=$project-terraform-state"  || errExit "could not terraform init" 35
  terraform import google_iap_brand.iap_brand "projects/${projectNumber}/brands/${projectNumber}" || errWarn "nexus: could not import IAP Brand Name"
  terraform apply || errExit "buildNexus: could not terraform apply" 35

  errInfo "Build Nexus images"
  # build nexus images:
  gcloud container images describe  ${nexusMainImageVersion} > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    cd docker-nexus-main
    cat Dockerfile.template | sed -e "s%SED_MAIN_VERSION%$nexusMainVersion%" > Dockerfile || errExit "nexus: failed to replace values in Dockerfile" 40
    docker build -t ${nexusMainImageVersion} . || errExit "nexus main image: could not build main docker image" 40
    docker push ${nexusMainImageVersion} || errExit "nexus main image: could not push main docker image" 40
    cd ..
  else
    errInfo "Skipping $nexusMainImageVersion image"
  fi
  gcloud container images describe  ${nexusBackupImageVersion} > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    cd docker-nexus-backup
    # no changes needed yet.
    cat Dockerfile.template  > Dockerfile || errExit "nexus backup image: could not populate Dockerfile template"
    docker build -t ${nexusBackupImageVersion} . || errExit "nexus backup image: could not build backup docker image" 40
    docker push ${nexusBackupImageVersion} || errExit "nexus backup image: could not push backup docker image" 40
    cd ..
  else
    errInfo "Skipping $nexusBackupImageVersion image"
  fi
  # Restore from backup command
  if [ ! -z $nexusGcsRestoreBucket ]; then
    errInfo "Nexus restore bucket is set to ${nexusGcsRestoreBucket}"
    errInfo "Will try to restore from latest backup"
    nexusInitCommand='latestFolder=$(gsutil ls gs://'${nexusGcsRestoreBucket}'/ |sort -k 2| tail -n 1); gsutil cp $latestFolder* /tmp; mkdir -p /tmp/db; tar -x -f /tmp/blobstore.tar -C /; tar -x -f databases.tar -C /tmp/db; cp /tmp/db/nexus-data/backup/*.bak /nexus-data/restore-from-backup/; rm -rf /tmp/db'
  else
    errInfo "Nexus: No restore bucket set. Bypassing restore"
    nexusInitCommand="echo"
  fi
  # create the deployment.yaml from the template and  apply
  cat deployment.yaml.template | sed -e "s%SED_HOST%$nexusHostName%;s%SED_TARGET_BUCKET%$nexushGcsBkpBucket%;s%SED_MAIN_VERSION%$nexusMainImageVersion%;s%SED_BACKUP_VERSION%$nexusBackupImageVersion%;s%SED_NODE_POOL%$nexusNodePoolName%;s%SED_NEXUS_INIT_COMMAND%$nexusInitCommand%" > deployment.yaml || errExit "nexus: failed to replace values in deployment.yaml" 40
  cat nexus-ingress.yaml.template | sed -e "s%SED_HOST%$nexusHostName%g" > nexus-ingress.yaml || errExit "nexus: failed to replace values in nexus-ingress.yaml" 40
  kubectl apply -n $nexusNameSpace -f . || errExit "nexus: could not apply deployment, etc" 40
# end of nexus section
fi

#*********************
#sonar level
if [[ ! -z "$installSonar" ]]; then
  cd ../sonar
  # create terraform.tfvars unless doNotGenTfvars is set
  if [[ -z "$doNotGenTfvars" ]]; then
    echo "# WARNING: This will be replaced by the build scripts by default. check script options." > terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 45
    sonarHostName="${sonarMasterDNSName%?}"
    echo "project=\"$project\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "region=\"$region\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "zone=\"$zone\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "cluster=\"$cluster\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "sonar_gcp_zone=\"$sonarMasterGCPZone-zebra-engineering\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "sonar_dns_zone_name=\"$sonarMasterDNSZoneName\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "sonar_dns_name=\"$sonarMasterDNSName\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "postgres_sonar_instance=\"$sonarPostgresInstance\"">> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "sonar_namespace=\"$sonarNameSpace\"" >> terraform.tfvars || errExit "sonar: could not create terraform.tfvar" 45
    echo "iap_brand_name=\"$iapBrandName\"" >> terraform.tfvars || errExit "nexus: could not create terraform.tfvar" 45
  fi
  terraform init -backend-config="bucket=$project-terraform-state" -upgrade || errExit "sonar: could not terraform init" 50
  terraform import google_iap_brand.iap_brand "projects/${projectNumber}/brands/${projectNumber}" || errWarn "buildcluster: could not import IAP Brand Name"
  terraform plan  || errExit "sonar: could not terraform plan" 50
  terraform apply || errExit "sonar: could not terraform apply" 50

  gsutil -m cp -R gs://$project-terraform-state/system/sonar/state/default.tfstate file1.txt
  sonarPostgresServer=$(cat file1.txt | grep "first"* | awk -F':' '{print$2}' |grep -oP '"\K[^"\047]+(?=["\047])') || errExit "sonar: could not get postgres server" 55
  if [[ ! -z "$takeBackupSonarID" ]]; then
    gcloud sql backups restore  $takeBackupSonarID --restore-instance=$sonarPostgresInstance --backup-instance=$sonarBackupInstance || errExit "sonar: could not restore from backup"  55
  fi
  rm file1.txt

  if [[ ! -z "$takeBackupSonarID" ]]; then
    gcloud sql backups restore  $takeBackupSonarID --restore-instance=$sonarPostgresInstance --backup-instance=$sonarBackupInstance || errExit "sonar: could not restore from backup"  55
  fi
  gcloud sql users set-password $sonarPostgresUser --instance=$sonarPostgresInstance --password=$sonarPostgresPassword || errExit "sonar: could not set postgres password" 55

  kubectl apply -f backend.yaml -n $sonarNameSpace || errExit "sonar: could not apply backend"  60
  cat values1.yaml.template | sed -e "s%SONAR_DNS%$sonarHostName%;s%SONAR_IP_ADDR%$sonarPostgresServer%;s%SONAR_USER%$sonarPostgresUser%;s%SONAR_PASS%$sonarPostgresPassword%;s%SONAR_DATABASE%$sonarPostgresDatabase%;s%SONAR_NODE_POOL%$sonarNodePoolName%" > values1.yaml || errExit "sonar: failed to replace values in values1.yaml" 60
  helm repo add oteemocharts https://oteemo.github.io/charts/ || errExit "sonar: could not add repo" 60
  helm repo update
  helm upgrade --install sonar --namespace $sonarNameSpace -f values1.yaml oteemocharts/sonarqube --version ${sonarVersion} || errExit "sonar: could not install sonar" 60
  rm values1.yaml
fi

#*********************
# jenkins level:
if [[ ! -z "$installJenkins" ]] ; then
  cd ../jenkins || errExit "jenkins: could not cd to jenkins directory" 65
  # this is used by kubernetes initContainer
  gsutil cp jenkins-init.sh $buildScriptsPath/jenkins-init.sh || errExit "jenkins: could not copy jenkins-init.sh to $buildScriptPath" 65
  # create terraform.tfvars unless doNotGenTfvars is set
  if [[ -z "$doNotGenTfvars" ]]; then
    echo "# WARNING: This will be replaced by the build scripts by default. check script options." > terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "project=\"$project\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "region=\"$region\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "zone=\"$zone\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "cluster=\"$cluster\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "jenkins_master_gcp_zone=\"$jenkinsMasterGCPZone-zebra-engineering\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "control_project=$control_project" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "jenkins_master_dns_zone_name=\"$jenkinsMasterDNSZoneName\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "jenkins_master_dns_name=\"$jenkinsMasterDNSName\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "jenkins_master_build_dns_name=\"$jenkinsMasterBuildDNSName\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "iap_brand_name=\"$iapBrandName\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
    echo "backup_bucket_name=\"$jenkinsBackupBucket\"" >> terraform.tfvars || errExit "jenkins: could not create terraform.tfvar" 70
  fi

  # apply jenkins specific terraform
  terraform init -backend-config="bucket=$project-terraform-state"  || errExit "could not terraform init" 75
  terraform plan  || errExit "jenkins: could not terraform plan" 75
  terraform import google_iap_brand.iap_brand "projects/${projectNumber}/brands/${projectNumber}" || errWarn "jenkins: could not import IAP Brand Name"
  terraform apply || errExit "jenkins: could not terraform apply" 75

  # Create docker image
  errInfo "Building Jenkins images"
  # fix up the version to include the suffix, like "-centos" if not provided
  echo "$jenkinsVersion" | grep '-' >/dev/null 1>&2 || jenkinsVersion="$jenkinsVersion"
  jenkinsGCRImageVersion="${artifact_reg_region}-docker.pkg.dev/$project/phoenix-images/jenkins:$jenkinsVersion"
  jenkinsGCRInitVersion="${artifact_reg_region}-docker.pkg.dev/$project/phoenix-images/cloud-sdk:latest"
  # set the jenkins version in Dockerfile
  cat ./image/Dockerfile.template | sed -e "s%SED_JENKINS_VERSION%$jenkinsVersion%;s%SED_INIT_VERSION%$jenkinsGCRInitVersion%"  > ./image/Dockerfile  || errExit "jenkins: could not set version in Dockerfile" 80
  cp -f ./image/plugins.txt.$jenkinsVersion ./image/plugins.txt || errExit "jenkins: could not cp ./image/plugins.txt.$jenkinsVersion"
  # build custom jenkins and gcloud for initContainer, push to project's GCR
  gcloud container images describe  ${jenkinsGCRImageVersion} > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    cd image || errExit "jenkins image: could not cd to image dir"
    docker build -t ${jenkinsGCRImageVersion} . || errExit "jenkins image: could not build jenkins image" 80
    docker push ${jenkinsGCRImageVersion}  || errExit "jenkins image: could not push jenkins image" 80
    cd ..
  else
    errInfo "Skipping $jenkinsGCRImageVersion image"
  fi

  # initContainer:
  gcloud container images describe  ${jenkinsGCRInitVersion} > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    cd image || errExit "jenkins init image: could not cd to image dir"
    docker pull google/cloud-sdk:latest || errExit "jenkins init image: could not pull initContainer" 85
    docker tag google/cloud-sdk:latest $jenkinsGCRInitVersion || errExit "jenkins init image: could not tag initContainer " 85
    docker push $jenkinsGCRInitVersion || errExit "jenkins init image: could not push initContainer image" 85
    cd ..
  else
    errInfo "Skipping $jenkinsGCRInitVersion image"
  fi
  # did we get a key file on command line? if not, create.
  if [[ -z "$buildToolsInstallerSAFile" ]]; then
    [[ ! -d keyfile ]] && mkdir keyfile
    gcloud iam service-accounts keys create ./keyfile/$project-buildtools.json --iam-account ${buildToolsInstallerSA}@${project}.iam.gserviceaccount.com || errExit "jenkins: could not generate service account key. May have hit limit for SA." 90
  else
    # normalize the filename IF provided as parameter. for predictable use later by jenkins-init in init Container
    if [[ "$buildToolsInstallerSAFile" != "./$project-buildtools.json" ]]; then
      cp -f $buildToolsInstallerSAFile ./keyfile/$project-buildtools.json || errExit "jenkins: error setting up SA file"  90
    fi
  fi
  buildToolsInstallerSAFile="./keyfile/$project-buildtools.json"
  [[ -f $buildToolsInstallerSAFile ]] || errExit "jenkins: SA key file does not exist" 90

  #  if secret exists, error out only if ignoreSecrets option was not given
  kubectl get secrets -n jenkins | awk '{print $1}' | grep "^build-tools-installer-sa$" > /dev/null 2>&1
  if [[ $? -eq 0  && ! -z "$ignoreSecrets" ]]; then
    # exists already
     errInfo "jenkins: service account secret exists."
  else
      kubectl create secret generic build-tools-installer-sa -n $jenkinsNameSpace --from-file="$buildToolsInstallerSAFile" || errExit "jenkins: could not add service account file to k8s secret" 90
  fi

  # use init container to call jenkins-init.sh to restore from a backup if needed
  [[ -z "$jenkinsInitContainerCmd" ]] && jenkinsInitContainerCmd="gcloud auth activate-service-account --key-file=/run/secrets/build-tools-installer-sa/$jenkinsProject-buildtools.json; gcloud config set project $jenkinsProject; mkdir -p /var/jenkins_home/buildtools.zebra; cd /var/jenkins_home/buildtools.zebra; gsutil cp $buildScriptsPath/jenkins-init.sh ./; chmod u+x  ./jenkins-init.sh; ./jenkins-init.sh -b $importBucket > log 2>\&1 ; exit 0"
  [[ -z "$jenkinsPostStartCmd" ]] || jenkinsPostStartCmd="echo"

  # remove the . off the jenkins hostname for the cert
  replaceHostName=`echo $jenkinsMasterDNSName | sed 's/\.$//'`
  replaceBuildHostName=`echo $jenkinsMasterBuildDNSName | sed 's/\.$//'`
  # generate the jenkins/deployment.yaml to dynamically construct the initContainer and postStart commands
  # replace everything at once and keep a copy of the original template
  cat deployment.yaml.template | sed -e "s%JENKINS_IMAGE%$jenkinsGCRImageVersion%;s%INITSCRIPTSEDREPLACE%$jenkinsInitContainerCmd%;s%POSTSCRIPTSEDREPLACE%$jenkinsPostStartCmd%;s%SED_INIT_VERSION%$jenkinsGCRInitVersion%;s%SED_JENKINS_VERSION%$jenkinsGCRImageVersion%;s%JENKINS_NODE_POOL%$jenkinsNodePoolName%;s%JENKINS_MASTER_NODE_POOL%$jenkinsMasterNodePoolName%;s%SED_JENKINS_HOST%$replaceHostName%;s%SED_JENKINS_BUILD_HOST%$replaceBuildHostName%" > deployment.yaml || errExit "jenkins: failed to replace values in deployment.yaml" 90
  cat ingress.yaml.template | sed -e "s%SED_JENKINS_HOST%$replaceHostName%;s%SED_JENKINS_BUILD_HOST%$replaceBuildHostName%" > ingress.yaml || errExit "jenkins: failed to replace values in ingress.yaml" 90


  # warn the user the SA key exists instead of deleting.
  errInfo "jenkins: you may need to preserve and/or SA key file: $buildToolsInstallerSAFile"

  # check if already exists. give a warning. Might want to exit? if so here is the place:
  kubectl get deployments.apps -n jenkins  | awk '{print $1}' | grep "^jenkins-master$" > /dev/null 2>&1
  if [[ $? -eq 0 ]];  then
    errWarn "jenkins: jenkins-master deployment exists"
  fi
  kubectl apply -n $jenkinsNameSpace -f . || errExit "jenkins: could not apply deployment, etc" 100
  cd ..
# end of jenkins section
fi

errInfo "****************"
errInfo "Confirm the IAP proxy for the service(s) that were installed is enabled at"
errInfo "  https://console.cloud.google.com/security/iap?cloudshell=false&project=${project} "
errInfo " Otherwise services will not be accessible "
errInfo "****************"

#*********************
# Sec Agents level:

sakey=$( basename $buildToolsInstallerSAFile )

# gcloud iam service-accounts keys create --iam-account=${buildToolsInstallerSA}@${project}.iam.gserviceaccount.com app-creds.json

if [[ -n $(gcloud --project=${project} compute instances list --format="value(name)" | sort | grep hop) ]]; then
  gcloud beta compute scp ./sec-agents/agents.sh hop:~/ --tunnel-through-iap --zone=${zone} --project=${project}
  gcloud beta compute scp ./jenkins/$buildToolsInstallerSAFile  hop:~/ --tunnel-through-iap --zone=${zone} --project=${project}
  gcloud beta compute ssh hop --tunnel-through-iap \
    --zone=${zone} \
    --project=${project} \
    --ssh-flag="-tt" \
    --command="gcloud auth activate-service-account --key-file=${sakey} --project=${project}; sudo apt-get update -y; bash agents.sh; rm -fv $sakey"
fi

# all done
exit 0

