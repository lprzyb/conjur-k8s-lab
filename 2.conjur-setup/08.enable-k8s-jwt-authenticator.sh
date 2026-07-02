#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./policies/authn-jwt-k8s.yaml -b root
RC1=$?

# TODO: check this command to see if can be removed: below possum rake command is for cert-based authn method, not related to jwt here
#podman exec $node_name chpst -u conjur conjur-plugin-service possum rake authn_k8s:ca_init["conjur/authn-jwt/k8s"]
podman exec -it $node_name sh -c 'grep -q "authn,authn-jwt/k8s" /opt/conjur/etc/conjur.conf || echo "CONJUR_AUTHENTICATORS=\"authn,authn-jwt/k8s\"\n">>/opt/conjur/etc/conjur.conf'
podman exec $node_name sv restart conjur
RC2=$?
set +x
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m authn-jwt/k8s authenticator enabled.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./09.loading-conjur-jwt-data.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m authn-jwt/k8s authenticator setup failed - check the output above.\n'
fi
