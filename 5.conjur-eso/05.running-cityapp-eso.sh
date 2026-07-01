#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

ESO_NS="external-secrets"
APP_NAME="cityapp-eso"
YML_FILE="yaml/$APP_NAME.yaml"
YML_TEMP="/tmp/$APP_NAME.yaml"

set -x

#Delete current deployment
kubectl -n $ESO_NS get deployments | grep -q $APP_NAME
if [ $? -eq 0 ]; then
    kubectl -n $ESO_NS delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n $ESO_NS get deployments | grep -q $APP_NAME
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done

fi

#Prepare manifest
cp $YML_FILE $YML_TEMP
sed -i "s/{LAB_IP}/$LAB_IP/g" $YML_TEMP
sed -i "s/{DB_HOST}/$DB_HOST/g" $YML_TEMP

#Deploy pod
kubectl -n $ESO_NS apply -f $YML_TEMP

rm $YML_TEMP
set +x
