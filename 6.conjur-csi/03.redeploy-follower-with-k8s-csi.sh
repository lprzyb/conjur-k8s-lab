
#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x

#Delete current deployment
kubectl -n conjur get deployment follower >/dev/null 2>&1
if [ $? -eq 0 ]; then
    kubectl -n conjur delete deployment follower
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n conjur get deployment follower >/dev/null 2>&1
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done
    
fi

cp yaml/03.follower-with-csi.yaml /tmp/follower.yaml
sed -i "s/CONJUR_IP/$CONJUR_IP/g" /tmp/follower.yaml
sed -i "s/LAB_DOMAIN/$LAB_DOMAIN/g" /tmp/follower.yaml
sed -i "s/CONJUR_VERSION/$conjur_version/g" /tmp/follower.yaml
sed -i "s/JWT_AUDIENCE/$JWT_AUDIENCE/g" /tmp/follower.yaml

kubectl -n conjur apply -f /tmp/follower.yaml
RC=$?

rm /tmp/follower.yaml
set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m Secrets Manager Follower redeployed with authn-jwt/k8s-csi enabled.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./04.installing-conjur-csi-provider.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m Follower redeployment failed (exit %s) - check the output above.\n' "$RC"
fi
