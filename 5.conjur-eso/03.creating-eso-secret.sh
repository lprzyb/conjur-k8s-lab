#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

ESO_NS="external-secrets"

set -x
kubectl get namespace | grep -q $ESO_NS || kubectl create namespace $ESO_NS
kubectl -n $ESO_NS get externalsecret | grep -q conjur  && kubectl -n $ESO_NS delete externalsecret conjur

kubectl apply -n $ESO_NS -f yaml/conjur-external-secret.yaml

sleep 1
kubectl -n external-secrets describe externalsecret conjur
set +x
