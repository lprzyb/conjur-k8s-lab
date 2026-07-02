#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x

kubeadm config images pull
kubeadm init --pod-network-cidr 10.244.0.0/16
RC=$?

#Configure kubectl admin login and allow pods to run on master (single-node Kubernetes)
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

#Install Flannel networking (pinned to latest release, not the moving master branch)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

#Wait until cni0 up and runing
ret=1
until [ $ret -eq 0 ]
do
    echo "Waiting cni0 up and running..."
    ip address | grep -q cni0
    ret=$?
    sleep 1
done

#Wait until flannel.1 up and runing
ret=1
until [ $ret -eq 0 ]
do
    echo "Waiting flannel.1 up and running..."
    ip address | grep -q flannel.1
    ret=$?
    sleep 1
done

#Refresh cni0 until getting correct IP at 10.244.0.0
ip address show dev cni0 | grep 10.244
ret=$?
until [ $ret -eq 0 ]
do
    echo "Refreshing cni0 to get correct IP..."
    ip link del cni0
    ip link del flannel.1
    kubectl delete pod --selector=app=flannel -n kube-flannel
    kubectl delete pod --selector=k8s-app=kube-dns -n kube-system
    sleep 10
    ip address show dev cni0 | grep 10.244
    ret=$?
done
set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m standalone K8s cluster up with Flannel networking.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./04.installing-k8s-dashboard.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m kubeadm init failed (exit %s) - check the output above.\n' "$RC"
fi