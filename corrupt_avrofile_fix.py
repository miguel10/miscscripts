#!/usr/bin/env python
#
#  One-off script for handling corrupt avro files
#

import os
import sys
from subprocess import call, Popen, PIPE, STDOUT

if (len(sys.argv) == 3):
        userAccount = sys.argv[1]
        avroFileName = sys.argv[2]
else:
        print "Usage: avromove <useracct> <avrofilename>"
        sys.exit(1)

logTypeList = 'list'

baseLogDirectory = '/user/' + userAccount + '/landing/'
corruptAvroDir = '/tmp/corruptavrofiles/'
hdfsCorruptDir = '/user/' + userAccount + '/corrupt/'

# Split filename and determine HDFS directory
splitFileName = avroFileName.split('_')
logTypeDir = splitFileName[0]

# Determining date/time directories
dateTimeExtensionStr = splitFileName[len(splitFileName)-1]
dateTimeStr = dateTimeExtensionStr.rstrip('.avro.gz')
splitDateTimeStr = dateTimeStr.split('-')

# Contain Date and Time for file upload in HDFS
dateStr = splitDateTimeStr[0]
timeStr = splitDateTimeStr[1]

# Check for midnight >:-|
intTime = int(timeStr[0:2])

if intTime == 23:
    intTime = 0
    dayOfMonth = int(dateStr[6:])+1
else:
    intTime = intTime+1
    dayOfMonth = int(dateStr[6:])

# Formatting actual hdfs path from date/time strings
timeDirStr = str(intTime).zfill(2)
timePath = timeDirStr + '/00/' # currently theres only seems to be a '00' directory underneath the time directory
datePath = dateStr[:4] + '/' + dateStr[4:-2] + '/' + str(dayOfMonth)

# Determine project directory from filename
for logStr in logTypeList:
    if logStr in logTypeDir.lower():
        logDir = logStr

pathToAvroFile = baseLogDirectory + datePath + '/' + timePath + logDir + '/' + avroFileName

# Check if file exists - if exists, download it.
if call(['/usr/bin/hadoop','fs','-ls',pathToAvroFile],stdout=PIPE, stderr=PIPE) != 0:
    print "Could not locate file in HDFS. Please check the filename and try again."
    sys.exit(1)

print "Retrieving:" + pathToAvroFile
# Download file - hadoop fs -get FILENAME /tmp/corruptavrofiles
if call(['/usr/bin/hadoop','fs','-get',pathToAvroFile,corruptAvroDir+avroFileName],stdout=PIPE, stderr=PIPE) !=0:
    if os.path.isfile(corruptAvroDir+avroFileName):
        print "The file already exists in " + corruptAvroDir + ". Please remove it and run again."
    else:
        print "There was an error retrieving file. Please check that user has correct permissions and that the file exists."

    sys.exit(1)
print ""
print "Running avrototext utility against file..."
# unzip and run avro2text against file
# Appears to hang if previous .avro file exists
if call(['gunzip','-f',corruptAvroDir+avroFileName]) !=0:
    print "Unable to unzip avro file for avrototext verification."
    sys.exit(1)
else:
    if call(['avrototext.sh',corruptAvroDir+avroFileName[:-3]]) !=0:
        print ""
        print "The file appears to be corrupt. Moving it to the corrupted directory in HDFS..."
        print ""

        # Checking for duplicate avro header bug
        print "Checking for duplicate avro header bug... "
        shStringsCall = Popen(['strings',corruptAvroDir+avroFileName[:-3]],stdout=PIPE)
        shGrepCall = Popen(['grep','avro.schema'],stdin=shStringsCall.stdout,stdout=PIPE)
        shWclCall = Popen(['wc','-l'],stdin=shGrepCall.stdout,stdout=PIPE,stderr=PIPE)
        headerCount = shWclCall.stdout.read()
        if int(headerCount) > 1:
            print "Bug found - Avro Headers: " + headerCount
        else:
            print "Single Header found. Bug does not appear to be present..."
        print ""

        # Move the file in HDFS to corrupted directory
        if call(['/usr/bin/hadoop','fs','-mv',pathToAvroFile,hdfsCorruptDir],stdout=PIPE, stderr=PIPE) !=0: # Output of move command will be dumped to console for user
            print "There was a problem moving the file. Please check that a file of the same name doesn't already exist."
            sys.exit(1)
        else:
            print "File was successfully moved to " + hdfsCorruptDir
            print "You can now rerun the failed actions..."

# Re-run failed oozie jobs
# To be added.
