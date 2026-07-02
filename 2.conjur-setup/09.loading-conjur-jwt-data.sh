#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x

PUBLIC_KEYS="$(kubectl get --raw $(kubectl get --raw /.well-known/openid-configuration | jq -r '.jwks_uri'))"
ISSUER="$(kubectl get --raw /.well-known/openid-configuration | jq -r '.issuer')"
conjur variable set -i conjur/authn-jwt/k8s/public-keys -v "{\"type\":\"jwks\", \"value\":$PUBLIC_KEYS}"
RC1=$?
conjur variable set -i conjur/authn-jwt/k8s/issuer -v $ISSUER
RC2=$?
conjur variable set -i conjur/authn-jwt/k8s/token-app-property -v sub
RC3=$?
conjur variable set -i conjur/authn-jwt/k8s/identity-path -v jwt-apps/k8s
RC4=$?
conjur variable set -i conjur/authn-jwt/k8s/audience -v $JWT_AUDIENCE
RC5=$?

set +x
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ] && [ $RC3 -eq 0 ] && [ $RC4 -eq 0 ] && [ $RC5 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m JWT authenticator data loaded into Secrets Manager.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./10.loading-k8s-follower-configmap.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m JWT authenticator data load failed - check the output above.\n'
fi
