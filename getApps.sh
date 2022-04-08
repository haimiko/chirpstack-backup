#!/bin/bash 
##haim.lichaa 2021
## Backup all Apps only
##

cd $HOMEDIR

mkdir -p backup
cp apps.current backup/apps.`date +%d%b%y` >/dev/null 2>&1

### get the list of applications
curl -skX GET --header 'Accept: application/json' --header "Grpc-Metadata-Authorization: Bearer $KEY" "$URL/applications?limit=$LIMIT"|jq -r '.result | map([.id,.name,.description,.serviceProfileName,.serviceProfileID,.organizationID] | join(",")) | join("\n")' > apps.current

