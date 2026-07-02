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

helm list -n $OBJ_NS | grep -q $OBJ_NAME
CHART_RC=$?

set +x
if [ $CHART_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m conjur-csi-provider Helm chart installed.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./04.creating-secret-provider-class.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m conjur-csi-provider Helm chart is not installed - check the output above.\n'
fi
