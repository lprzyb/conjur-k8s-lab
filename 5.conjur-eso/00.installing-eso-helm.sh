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

echo "Installing external-secrets helm chart if not available"
helm get metadata  external-secrets --namespace external-secrets >/dev/null 2>&1
if [ $? -ne 0 ]; then 
    helm repo add external-secrets https://charts.external-secrets.io

    helm install external-secrets \
	external-secrets/external-secrets \
	-n external-secrets \
	--create-namespace \
	--version 2.7.0 \
	#--set installCRDs=false
else
    echo "Helm chart for external-secrets has been installed"
fi

helm get metadata external-secrets --namespace external-secrets >/dev/null 2>&1
CHART_RC=$?

set +x
if [ $CHART_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m external-secrets Helm chart installed.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./01.adding-conjur-eso-policy.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m external-secrets Helm chart is not installed - check the output above.\n'
fi
