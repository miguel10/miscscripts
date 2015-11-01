#!/bin/sh
#
# This script generates hadoop service account keytabs using vastool and ktutil.
#
# Requirements:
#  hadoop_krb.conf - configuration file
#  hadoop_svcaccount.list - file containing list of service accounts to create
#  hadoop_node.list - list of FQDN hosts to generate keytabs for
#  Dell QAS - vastool

# Check for vastool
command -v vastool >/dev/null 2>&1 || { echo "Can't find vastool... Aborting." >&2; exit 1; }

# Check for configuration file
if [ -f 'hadoop_krb.config' ]
then
        source ./hadoop_krb.config
        keytabOutputDir=$KEYTABOUTPUTDIR
        adUser=$ADUSER
        OU=$OU
        DOMAIN=$DOMAIN
        adUserPass=$ADUSERPASS
else
        echo "Could not find hadoop_krb.config. Exiting..."
        exit 2
fi

if [ ! -f 'hadoop_svcaccount.list' ]; then
  echo "Missing hadoop_svcaccount.list. Exiting..." >&2
  exit 3
fi
if [ ! -f 'hadoop_node.list' ]; then
  echo "Missing hadoop_node.list. Exiting..." >&2
  exit 4
fi

for svcacct in `cat hadoop_svcaccount.list`
do
    for nodefqdn in `cat hadoop_node.list`
    do
        #rpasswd="`< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c12`" # cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1
        #rpasswd="`dd if=/dev/urandom count=12 2> /dev/null | LC_ALL=C tr -cd '[:alnum:]' | head -c 12 2>/dev/null`"
        rpasswd="`apg -m 13 -x 13 -a 1 -M NLC -n 1`"

        node=`echo $nodefqdn | cut -f1 -d'.'`
        adLogin="$node-$svcacct"

        echo "Creating '$svcacct/$nodefqdn' in AD..."
        vastool -u $adUser -w $adUserPass create -p $rpasswd -x -c "$OU" user $svcacct/$nodefqdn
        sleep 1

        if [ $svcacct == 'zookpr' ]
        then
                svcacct='zookeeper'
                # Reset Account AD Login for Zookeeper name length constraint
                echo "Updating Zookeeper User Principal Name to address AD 20-char limit..."
                #realm=${DOMAIN,,}
                vastool -u $adUser -w $adUserPass setattrs $adLogin userPrincipalName "$svcacct/$nodefqdn@$DOMAIN"
        fi

        echo "Updating Active Directory SPN..."
        vastool -u $adUser -w $adUserPass setattrs $adLogin servicePrincipalName $svcacct/$nodefqdn
        sleep 1

        echo "Updating Password to not expire..."
        vastool -u $adUser -w $adUserPass setattrs $adLogin userAccountControl '66048'

echo "Generating Keytab(ktutil)..."
/usr/bin/ktutil << EOF
addent -password -p $svcacct/$nodefqdn -k 0 -e arcfour-hmac
$rpasswd
wkt $keytabOutputDir/$svcacct-$node.keytab
q
EOF

        # set ownership to cloudera manager
        chown cloudera-scm.cloudera-scm $keytabOutputDir/$svcacct-$node.keytab

        echo "Logging generated credentials..."
        echo "$svcacct/$nodefqdn.keytab = $rpasswd" >> svcacct.auth
        sleep 2
        
		# reset zookpr
        if [ $svcacct == 'zookeeper' ]
        then
                svcacct='zookpr'
        fi
    done
done
