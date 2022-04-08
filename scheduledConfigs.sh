#!/bin/bash

## haim.lichaa 2022
## will only push configs to sensors which have previously reported and never received configs in the past

echo "Starting scheduled LoRaWAN sensors device configurations" | ts
echo "========================================================" | ts
TRAKFILE=configs.deveui
PUSHFILE=sensors.push
>$PUSHFILE
[ ! -f $TRAKFILE ] && touch $TRAKFILE

grep -v ^# getKeys.current| while read line;do
  DEVEUI=`echo $line|cut -f2 -d";"`
  LASTSEEN=`echo $line|cut -f5 -d";"`
  if [ `grep -ic $DEVEUI $TRAKFILE` -eq 0 ];then
     if [ ! -z $LASTSEEN ];then
        echo setting up $DEVEUI for configuration | ts
        echo $DEVEUI >> $TRAKFILE
        echo "$line" >> $PUSHFILE
     else
        echo $DEVEUI  never seen, will try later | ts
     fi
  else
     echo $DEVEUI already configured, skipping | ts
  fi
done

echo pushing configs | ts
./pushConfig.sh $PUSHFILE -f
./pushConfig.sh $PUSHFILE -f
