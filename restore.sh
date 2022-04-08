#!/bin/bash 
##haim.lichaa 2021
## Restore devices from backup
## 1.0 - 9/13/21 initial
##

. ./CONFIG
cd $HOMEDIR

FILE=$1

if [ ! -f $FILE ] || [ -z $FILE ];then
   echo "usage: $0 <RESTOREFILE>"
   exit 1
fi




### get the updated list of applications
echo -n "Retrieving updated list of apps..."
curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/applications?limit=$LIMIT"|jq -r '.result | map([.id,.name] | join(",")) | join("\n")' > .apps


if [ `wc -l .apps|awk '{print$1}'` -lt 2 ];then
   echo "ERROR..."
   exit 1
else
   echo OK
fi


### get the updated list of device profiles
curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/device-profiles?limit=$LIMIT"|jq -r '.result | map([.id,.name] | join(",")) | join("\n")' > .devProfiles


cat $FILE|tail -n +2|while read line;do
  appName=$(echo $line|cut -f1 -d";")
  appId=$(grep -w ".*,$appName$" .apps|cut -f1 -d",")
  desc=$(echo $line|cut -f8 -d";")
  tags=$(echo $line|cut -f9 -d";")
  name=$(echo $line|cut -f3 -d";")
  devEUI=$(echo $line|cut -f2 -d";")
  appKey=$(echo $line|cut -f7 -d";")
  devProfId=$(grep -w ".*,`echo $line|cut -f6 -d";"`$" .devProfiles|cut -f1 -d",")
  payload='{ "device": {"applicationID": "'$appId'", "description": "'$desc'", "devEUI": "'$devEUI'", "deviceProfileID": "'$devProfId'", "name": "'$name'", "isDisabled": false, "referenceAltitude": 0 , "skipFCntCheck": false, "tags": '$tags', "variables": {}}}'
  echo "creating: $payload"
  #if app doesn't exist create it
  if [ -z $appId ];then
    desc=$(grep -w ".*,$appName,.*" apps.current|cut -f3 -d",")
    serviceProfileId=$(grep -w ".*,$appName,.*" apps.current|cut -f5 -d",")
    orgId=$(grep -w ".*,$appName,.*" apps.current|cut -f6 -d",")
    if [ -z $serviceProfileId ];then
        echo "Error: No app $appName found in apps.current" >/dev/stderr
        continue
    fi
    if [ -z $orgId ];then
        echo "Error: No orgId for $appName found in apps.current" >/dev/stderr
        continue
    fi
    apppayload='{ "application": {"description": "'$desc'", "serviceProfileID": "'$serviceProfileId'", "organizationID": "'$orgId'", "name":  "'$appName'"}}'
    echo $apppayload
    echo "Creating App $appName"
    curl -kX POST --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/applications" -d "$apppayload";stat=$?
    curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/applications?limit=$LIMIT"|jq -r '.result | map([.id,.name] | join(",")) | join("\n")' > .apps
    appId=$(grep -w ".*;`echo $line|cut -f1 -d";"`" .apps|cut -f1 -d",")
    payload='{ "device": {"applicationID": "'$appId'", "description": "'$desc'", "devEUI": "'$devEUI'", "deviceProfileID": "'$devProfId'", "name": "'$name'", "isDisabled": false, "referenceAltitude": 0 , "skipFCntCheck": false, "tags": {}, "variables": {}}}'
  fi
   
  if [ -z $appId ] || [ -z $devEUI ] || [ -z $devProfId ] || [ -z $name ];then
     echo "Error: missing attributes" >/dev/stderr
     continue
  fi

  ##create device
  curl -kX POST --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices" -d "$payload";stat=$?
  curl -kX PUT --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices/$devEUI" -d "$payload";stat=$?
  if [ $stat -ne 0 ];then
    echo "Failed $stat" > /dev/stderr
    continue
  else
    echo "$name, created"
  fi

  payload='{ "deviceKeys": {"devEUI": "'$devEUI'", "nwkKey": "'$appKey'"}}'
    
  curl -skX POST --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/devices/$devEUI/keys" -d "$payload";stat=$?
  if [ $stat -ne 0 ];then
    echo "Failed $stat" > /dev/stderr
    continue
  else
    echo "$name, authorized"
  fi

done
