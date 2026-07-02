#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x

kubectl get configmap | grep -q landing-page-html && kubectl delete configmap landing-page-html
kubectl create configmap landing-page-html --from-file=index.html=yaml/landing-page.html

kubectl get deployments | grep -q landing-page
if [ $? -eq 0 ]; then
    kubectl delete deployment landing-page
    ret=0
    until [ $ret -ne 0 ]
    do
        kubectl get deployments | grep -q landing-page
        ret=$?
        echo "Waiting deployment is deleted..."
        sleep 1
    done

fi

kubectl apply -f yaml/landing-page.yaml

set +x
VM_IP=$(hostname -I | awk '{print $1}')
printf '\033[1;32m✅ Done:\033[0m landing page deployed - browse http://%s:30001\n' "$VM_IP"
printf '\033[1;33m➡️  Next:\033[0m cd ../2.conjur-setup and review 00.config.sh\n'
