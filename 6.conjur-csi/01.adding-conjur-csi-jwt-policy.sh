#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./yaml/01.conjur-csi-jwt-policy.yaml -b root
RC1=$?

PUBLIC_KEYS="$(kubectl get --raw $(kubectl get --raw /.well-known/openid-configuration | jq -r '.jwks_uri'))"
ISSUER="$(kubectl get --raw /.well-known/openid-configuration | jq -r '.issuer')"
conjur variable set -i conjur/authn-jwt/k8s-csi/public-keys -v "{\"type\":\"jwks\", \"value\":$PUBLIC_KEYS}"
RC2=$?
conjur variable set -i conjur/authn-jwt/k8s-csi/issuer -v $ISSUER
RC3=$?
conjur variable set -i conjur/authn-jwt/k8s-csi/audience -v $CSI_JWT_AUDIENCE
RC4=$?

set +x
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ] && [ $RC3 -eq 0 ] && [ $RC4 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m CSI JWT policy loaded and authn-jwt/k8s-csi configured in Secrets Manager.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./02.redeploy-follower-with-k8s-csi.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m CSI JWT policy load or variable set failed - check the output above.\n'
fi
