#!/bin/bash 
##haim.lichaa 2021
## Backup all devices and Keys
##



cd $HOMEDIR

. ./CONFIG
OUTFILE=$HOMEDIR/backup.out.`date +%d%b%y`

### get the list of applications
rm -f apps
echo -n "Retrieving Applications..."
curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/applications?limit=$LIMIT"|jq -r '.result | map([.id,.name] | join(",")) | join("\n")' > apps

if [ `wc -l apps|awk '{print$1}'` -lt 2 ];then
   echo "ERROR..."
   exit 1
else
   echo OK
fi

echo -n "Retrieving devices.."
#echo "#======"
#echo "devEUI,AppKey"
keyout=""
for line in `cat apps`;do
   app=`echo $line|cut -f1 -d"," `
   devices=`curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices?limit=$LIMIT&applicationID=$app"`
   #get devEUI
   DEVS=`echo $devices|jq -r '.result[].devEUI'`
   for dev in $DEVS;do
      key=`curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices/$dev/keys"|jq -r '.deviceKeys.nwkKey'`
      keyout="$keyout `echo  "$dev,$key"`"
      echo -n "x" 
   done
   echo -n "." 
done
echo "Done"

echo -n "Retrieving AppIDs.."
#echo "#======"
#echo "devEUI,Name,AppId"
rm -f devout
for line in `cat apps`;do
   app=`echo $line|cut -f1 -d"," `
   devices=`curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices?limit=$LIMIT&applicationID=$app"`
   echo $devices|jq -r '.result | map([.devEUI,.name,.applicationID,.lastSeenAt,.deviceProfileName] | join(";")) | join("\n")' >> devout
   echo -n "." 
done

echo "Done"

echo -n "Retrieving device details.."
echo "AppName;devEUI;devName;AppId;devProfileName;lastSeenAt;ApKey;Description;Tags" > $OUTFILE
for key in $keyout;do
   dev=`echo $key|cut -f1 -d,` 
   cmd=`curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices/$dev"`
   description=`echo $cmd |jq -r '.device.description'|sed "s/;/,/g" `
   tags=`echo $cmd |jq -cr '.device.tags'`
   key=`echo $key|cut -f2 -d,` 
   line=`grep $dev devout`
   appid=`echo $line|cut -f3 -d";"`
   appname=`grep "^$appid," apps|cut -f2 -d,`
   echo "$appname;$line;$key;$description;$tags" >> $OUTFILE
   echo -n "." 
done

echo "Done"

ln -f  $OUTFILE backup.current

##cleanup
#rm -f $HOMEDIR/devout $HOMEDIR/apps
find $HOMEDIR/backup.out.* -type f -mtime +10 -exec rm -f {} \;
