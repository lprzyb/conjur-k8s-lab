#/bin/sh

source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

APP_NAME="cityapp-csi"
YML_FILE="yaml/06.$APP_NAME.yaml"
YML_TEMP="/tmp/05.$APP_NAME.yaml"

set -x
kubectl get namespace | grep -q cityapp || kubectl create namespace cityapp
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

kubectl -n cityapp apply -f $YML_TEMP

rm $YML_TEMP

set +x
