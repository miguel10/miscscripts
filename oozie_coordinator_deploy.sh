#/bin/sh
#
# Script to deploy oozie coordinator jobs
# Apache oozie: http://oozie.apache.org/
#

# Define Environmental Vars
timeZone='America/Phoenix'
jobEndTime='2112-01-01T00:00Z' # Add option to set end time at command line
jobTrackerPort='8021'
# QA Host Entries
nameNodeQA='hdfs://hdfs.hadoop.qa'
jobTrackerQA='mapred.hadoop.qa'
# Staging Host Entries
nameNodeStaging='hdfs://hdfs.hadoop.staging'
jobTrackerStaging='mapred.hadoop.staging'
# Prod Host Entries
nameNodeProd='hdfs://hdfs.hadoop.prod'
jobTrackerProd='mapred.hadoop.prod'
oozieDeployDir="$HOME/oozie_installs/"
oozieHDFSDir="/user/$USER/oozie/apps/"

function errorFound() {
        echo
        echo -e "$1"
        echo
        exit 1
}

if [ $# == 3 ]
then
        # Handle command line arguments
        # Cluster Environment:
        if [ "$1" == "qa" ]
        then
                envNameNode=$nameNodeQA
                envJobTracker=$jobTrackerQA
                envState='qa'
        elif [ "$1" == "staging" ]
        then
                envNameNode=$nameNodeStaging
                envJobTracker=$jobTrackerStaging
                envState='stage'
        elif [ "$1" == "prod" ]
        then
                envNameNode=$nameNodeProd
                envJobTracker=$jobTrackerProd
                envState='prod'
        else
                errorFound "Unrecognized Cluster Name - Please verify the cluster name and retry"
        fi

else
        errorFound "Usage: ooziedeploy <environment> <svnurl> <startdate>"
fi

appLocation=$2
jobStartTime=$3

#
# SVN Checkout of Tag/Branch
if [ "${appLocation:0:4}" == "http" ]
then
    cd $oozieDeployDir
    appLocation=`echo $appLocation | sed -e "s/\/*$//"` #Strip trailing slash
    svn export $appLocation || errorFound "Unable to check out code from SVN. Please verify and try again"
    appName=`echo $appLocation | awk -F/ '{ print $NF }'`
    cd $appName || errorFound "Unable to find application directory. Please verify and try again"
else
    appLocation=`echo $appLocation | sed -e "s/\/*$//"` # Strip trailing slash
    appName=`echo $appLocation | awk -F/ '{ print $NF }'`
    cd $appLocation || errorFound "Unable to find application directory. Please verify and try again"
fi

echo "Oozie Application Name: " $appName
echo
echo "Looking for application coordinator jobs..."
echo


# Check for coordinator config directory & update properties file
for coordDir in `ls -d ./*-coord/`
do
        cd $coordDir
        #
        # Change to correct hostname in all job.properties
        # nameNode
        find . -type f  | grep -v .svn | grep "job.properties" | xargs sed -i "s#^nameNode=.*#nameNode=$envNameNode#g"
        # jobTracker
        find . -type f  | grep -v .svn | grep "job.properties" | xargs sed -i "s#^jobTracker=.*#jobTracker=$envJobTracker\:jobTrackerPort#g"

        #
        # Change start/endtimes for all job.properties.
        # start time
        find . -type f  | grep -v .svn | grep "job.properties" | xargs sed -i "s#^start=[0-9].*#start=$jobStartTime#g"
        # end time
        find . -type f  | grep -v .svn | grep "job.properties" | xargs sed -i "s#^end=[0-9].*#end=$jobEndTime#g"

        echo
        echo "Successfully updated existing job.properties file for $coordDir"
        echo
        cd ..
done

# Prompt user for job execution
for coordDir in `ls -d *-coord/`
do

    configFile="job.properties"

    echo
    echo "Printing job.properties file for review "$coordDir$configFile": "
    echo "------------------------------------------"
    echo
    cat $oozieDeployDir$appName"/"$coordDir$configFile
    echo
    echo "------------------------------------------"
    echo

    echo "Do you wish to upload to HDFS and run an Oozie job with "$coordDir$configFile"? "
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo
                  echo "Uploading application to HDFS..."
                  echo "----------------------------------"
                  echo
                  hadoop fs -put ../$appName $oozieHDFSDir || errorFound "There was a problem putting files into HDFS. Aborting..."
                  echo
                  echo "----------------------------------"
                  echo
                  echo "Deploying job in Oozie..."
                  echo
                  oozie job -config $coordDir$configFile -run
                  echo
                  echo "----------------------------------"
                  echo
                  break
                  ;;
            No ) break;;
        esac
    done

done
