#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

# This deployment reuses localhost/cityapp-springboot:latest, built by
# 01.building-cityapp-springboot-image.sh - run that first if it hasn't
# been built yet.
podman image exists localhost/cityapp-springboot:latest
IMAGE_EXISTS_RC=$?

if [ $IMAGE_EXISTS_RC -ne 0 ]; then
    printf '\033[1;31m❌ Cannot deploy:\033[0m localhost/cityapp-springboot:latest image not found.\n'
    printf '\033[1;33m➡️  Fix:\033[0m run ./01.building-cityapp-springboot-image.sh before retrying this script.\n'
    exit 1
fi

APP_NAME="cityapp-springboot-sidecar"
YML_FILE="yaml/$APP_NAME.yaml"
YML_TEMP="/tmp/$APP_NAME.yaml"
CONJUR_FOLLOWER_URL="https://follower.conjur.svc.cluster.local"
CONJUR_CERT="$(openssl s_client -showcerts -connect  $CONJUR_LEADER_HOST:443 </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p')"

CONJUR_AUTHN_URL=$CONJUR_FOLLOWER_URL/authn-jwt/k8s
set -x
kubectl get namespace | grep -q cityapp || kubectl create namespace cityapp
#Reset config map
kubectl -n cityapp get configmap | grep -q apps-cm && kubectl -n cityapp delete configmap apps-cm
kubectl -n cityapp create configmap apps-cm \
    --from-literal CONJUR_ACCOUNT=$LAB_CONJUR_ACCOUNT \
    --from-literal CONJUR_APPLIANCE_URL=$CONJUR_FOLLOWER_URL \
    --from-literal CONJUR_AUTHN_URL=$CONJUR_AUTHN_URL \
    --from-literal "CONJUR_SSL_CERTIFICATE=${CONJUR_CERT}"

#Update RBAC (shared Role/RoleBinding also used by folder 3's
#cityapp-conjurtok8ssecret/-init - all three write to the same db-creds
#Secret in the cityapp namespace, so this stays a single source of truth
#in folder 3 rather than a duplicated copy here)
kubectl -n cityapp apply -f ../3.cityapp-setup/yaml/conjurtok8ssecret-rbac.yaml

#Delete current deployment
kubectl -n cityapp get deployment $APP_NAME >/dev/null 2>&1
if [ $? -eq 0 ]; then
    kubectl -n cityapp delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n cityapp get deployment $APP_NAME >/dev/null 2>&1
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done
    
fi

#Prepare manifest
cp $YML_FILE $YML_TEMP
sed -i "s/{LAB_IP}/$LAB_IP/g" $YML_TEMP
sed -i "s/{LAB_DOMAIN}/$LAB_DOMAIN/g" $YML_TEMP
sed -i "s/{DB_HOST}/$DB_HOST/g" $YML_TEMP
sed -i "s/{JWT_AUDIENCE}/$JWT_AUDIENCE/g" $YML_TEMP

#Deploy pod
kubectl -n cityapp apply -f $YML_TEMP

rm $YML_TEMP
set +x