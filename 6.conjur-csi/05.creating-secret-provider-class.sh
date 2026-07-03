#!/bin/bash

source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

CONJUR_FOLLOWER_URL="https://follower.conjur.svc.cluster.local"
CONJUR_CERT="$(openssl s_client -showcerts -connect  $CONJUR_LEADER_HOST:443 </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p')"

YML_FILE="./yaml/05.conjur-csi-provider-class-config.yaml"
YML_TEMP="/tmp/$(date +%s).yaml"

OBJ_TYPE=" SecretProviderClass"
OBJ_NAME="conjur-credentials"
OBJ_NS="cityapp"

set -x

kubectl -n $OBJ_NS get $OBJ_TYPE | grep -q $OBJ_NAME
if [ $? -eq 0 ]; then
    kubectl -n $OBJ_NS delete $OBJ_TYPE $OBJ_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n $OBJ_NS get $OBJ_TYPE | grep -q $OBJ_NAME
        ret=$?
        echo "Waiting $OBJ_TYPE is deleted..."
        sleep 1
    done

fi

#Prepare manifest
cp $YML_FILE $YML_TEMP
sed -i "s#{CONJUR_URL}#$CONJUR_FOLLOWER_URL#g" $YML_TEMP
sed -i "s#{CONJUR_ACCOUNT}#$LAB_CONJUR_ACCOUNT#g" $YML_TEMP

set +x
while read -r line; do
    echo "      $line" >> $YML_TEMP
done <<< "$CONJUR_CERT"
set -x

kubectl -n $OBJ_NS apply -f $YML_TEMP
RC=$?

rm -rf $YML_TEMP

kubectl -n $OBJ_NS describe $OBJ_TYPE $OBJ_NAME

set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m %s created in namespace %s.\n' "$OBJ_NAME" "$OBJ_NS"
    printf '\033[1;33m➡️  Next:\033[0m run ./06.running-cityapp-csi-test.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m SecretProviderClass creation failed (exit %s) - check the output above.\n' "$RC"
fi
