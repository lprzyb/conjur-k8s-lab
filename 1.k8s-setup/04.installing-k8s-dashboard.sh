#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
APP_NAME="dashboard-metrics-scraper"
kubectl -n kubernetes-dashboard get deployment $APP_NAME >/dev/null 2>&1
if [ $? -eq 0 ]; then
    kubectl -n kubernetes-dashboard delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n kubernetes-dashboard get deployment $APP_NAME >/dev/null 2>&1
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done

fi

APP_NAME="kubernetes-dashboard"
kubectl -n kubernetes-dashboard get deployment $APP_NAME >/dev/null 2>&1
if [ $? -eq 0 ]; then
    kubectl -n kubernetes-dashboard delete deployment $APP_NAME
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl -n kubernetes-dashboard get deployment $APP_NAME >/dev/null 2>&1
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done

fi

kubectl apply -f yaml/kube-dashboard.yaml
RC1=$?

kubectl apply -f yaml/dashboard-serviceaccount.yaml
RC2=$?

kubectl -n kubernetes-dashboard describe secrets dashboard-admin-secret
echo "Please copy above token value for dashboard login. Press enter when done..."
read
set +x
VM_IP=$(hostname -I | awk '{print $1}')
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m K8s Dashboard deployed - browse https://%s:30443\n' "$VM_IP"
    printf '\033[1;33m➡️  Next:\033[0m run ./05.deploying-landing-page.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m dashboard manifests failed to apply - check the output above.\n'
fi
