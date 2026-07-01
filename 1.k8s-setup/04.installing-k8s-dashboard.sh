#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
APP_NAME="dashboard-metrics-scraper"
kubectl -n kubernetes-dashboard get deployments | grep -q $APP_NAME
if [ $? -eq 0 ]; then
    kubectl -n kubernetes-dashboard delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n kubernetes-dashboard get deployments | grep -q $APP_NAME
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done

fi

APP_NAME="kubernetes-dashboard"
kubectl -n kubernetes-dashboard get deployments | grep -q $APP_NAME
if [ $? -eq 0 ]; then
    kubectl -n kubernetes-dashboard delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n kubernetes-dashboard get deployments | grep -q $APP_NAME
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done

fi

kubectl apply -f yaml/kube-dashboard.yaml

kubectl apply -f yaml/dashboard-serviceaccount.yaml

kubectl -n kubernetes-dashboard describe secrets dashboard-admin-secret
echo "Please copy above token value for dashboard login. Press enter when done..."
read
set +x
