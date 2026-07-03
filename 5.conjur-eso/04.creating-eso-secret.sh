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
RC=$?

sleep 1
kubectl -n external-secrets describe externalsecret conjur
set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m conjur ExternalSecret created in namespace %s.\n' "$ESO_NS"
    printf '\033[1;33m➡️  Next:\033[0m run ./05.getting-eso-secret.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m ExternalSecret creation failed (exit %s) - check the output above.\n' "$RC"
fi
