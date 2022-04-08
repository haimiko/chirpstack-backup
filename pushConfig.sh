#!/bin/bash
#haim.lichaa 2021 initial

CONFIGFILE=device.config
FILE=$1
RUN=$2

if [ -z $FILE ] || [ ! -f $FILE ];then
   echo "Usage: $0 <FILE> -f"
   echo "FILE in getKeys format,skips first line"
   echo "-f force run, otherwise will dry run to stdout"
   exit 1
fi

cat $FILE|tail -n +2|while read line;do
  APPID=$(echo $line|cut -f4 -d";")
  DEVEUI=$(echo $line|cut -f2 -d";")
  MODEL=$(echo $line|cut -f9 -d";"|jq -r ".Model")
  CONFIGS=`grep -v ^# $CONFIGFILE|grep "^$APPID,.*,$MODEL,.*" |cut -f5 -d","`
  FPORT=`grep -v ^# $CONFIGFILE|grep "^$APPID,.*,$MODEL,.*" |tail -n 1| cut -f4 -d","`
  if [ -z "$CONFIGS" ];then
    echo "NO configs found for appId=[$APPID] with model=[$MODEL]"
    continue
  fi
  echo "Found $CONFIGS for $APPID"
  for config in $CONFIGS;do 
    out="mosquitto_pub  -h $MQTTBROKER -p $MQTTPORT -t 'application/'$APPID'/device/'$DEVEUI'/command/down' -m '{\"confirmed\": true, \"fPort\": $FPORT, \"data\": \"'$config'\" }'"
    if [ ! -z $RUN ];then 
       echo "Sending $CONFIG to $DEVEUI"
       bash -c "$out"
    else
       echo $out
    fi
 sleep 0.2
  done
done

