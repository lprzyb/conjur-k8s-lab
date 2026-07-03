#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x

echo "Installing helm if not available..."
which helm > /dev/null 2>&1
if [ $? -ne 0 ]; then 
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    HELM_INSTALL_DIR=/usr/bin bash ./get_helm.sh
    rm ./get_helm.sh
else
    echo "Helm has been already installed!!!"
fi

echo "Installing Secrets Store CSI Driver using Helm..."
helm list -n kube-system | grep -q csi-secrets-store
if [ $? -ne 0 ]; then 
    helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
    helm install csi-secrets-store \
	secrets-store-csi-driver/secrets-store-csi-driver \
	--wait \
	--namespace kube-system \
	--version 1.6.0 \
	--set syncSecret.enabled="false" \
	--set "tokenRequests[0].audience=$CSI_JWT_AUDIENCE"
else
    echo "Helm chart for csi-secrets-store has been installed"
    echo "Delete it with command: helm delete -n kube-system csi-secrets-store"
fi


kubectl --namespace=kube-system get pods -l "app=secrets-store-csi-driver"

helm list -n kube-system | grep -q csi-secrets-store
CHART_RC=$?

set +x
if [ $CHART_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m Secrets Store CSI Driver Helm chart installed.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./02.adding-conjur-csi-jwt-policy.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m Secrets Store CSI Driver Helm chart is not installed - check the output above.\n'
fi
