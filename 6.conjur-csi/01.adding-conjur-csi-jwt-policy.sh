#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./yaml/01.conjur-csi-jwt-policy.yaml -b root

PUBLIC_KEYS="$(kubectl get --raw $(kubectl get --raw /.well-known/openid-configuration | jq -r '.jwks_uri'))"
ISSUER="$(kubectl get --raw /.well-known/openid-configuration | jq -r '.issuer')"
conjur variable set -i conjur/authn-jwt/k8s-csi/public-keys -v "{\"type\":\"jwks\", \"value\":$PUBLIC_KEYS}"
conjur variable set -i conjur/authn-jwt/k8s-csi/issuer -v $ISSUER
conjur variable set -i conjur/authn-jwt/k8s-csi/audience -v $CSI_JWT_AUDIENCE

set +x
