#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

OBJ_TYPE="HelmChart"
OBJ_NAME="conjur-csi-provider"
OBJ_NS="kube-system"
set -x

helm list -n $OBJ_NS  | grep -q $OBJ_NAME
if [ $? -eq 0 ]; then
    helm -n $OBJ_NS delete $OBJ_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
	helm list -n $OBJ_NS | grep -q $OBJ_NAME
        ret=$?
        echo "Waiting $OBJ_TYPE is deleted..."
        sleep 1
    done

fi

helm repo add cyberark \
    https://cyberark.github.io/helm-charts
helm install conjur-csi-provider \
    cyberark/conjur-k8s-csi-provider \
    --wait \
    --namespace kube-system \
    --version 0.2.5

kubectl -n $OBJ_NS get pods 
set +x
