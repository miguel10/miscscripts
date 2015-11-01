#!/bin/sh
#
# Script to backup postgres db
#

for dbString in `cat pgbackup.list`
do
        dbHost=`echo $dbString | cut -d'|' -f1`
        dbPort=`echo $dbString | cut -d'|' -f2`
        dbUser=`echo $dbString | cut -d'|' -f3`
        dbPass=`echo $dbString | cut -d'|' -f4`
done

currDate=$(date +"%Y%m%d")
purgeDate=$(date --date="5 days ago" +"%Y%m%d")
backupDir=~/backups

oldDir="$backupDir/$dbHost$dbPort/$purgeDate"
currDir="$backupDir/$dbHost$dbPort/$currDate"

# Remove db backups from 5 days ago in backupdir
echo "Purging Backup Directory if exists - $oldDir"
[ -d $oldDir ] && rm -fR $oldDir

export PGPASSWORD="$dbPass"
# Backup all databases individually
[ ! -d $currDir ] && mkdir -p $currDir || :
LIST=$(psql -h $dbHost -p $dbPort -U $dbUser -lt | awk '{print $1}' | grep -vE 'template[0|1]|\:|^$')

for d in $LIST
do
          echo "pg_dump -p $dbPort -U $dbUser $d | gzip -c >  $currDir/$d.$currDate.gz"
done
export PGPASSWORD=""
