#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$K8S_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$K8S_VERSION/rpm/repodata/repomd.xml.key
EOF

yum -y install cri-o
systemctl enable --now crio

set +x
printf '\033[1;32m✅ Done:\033[0m CRI-O installed and running.\n'
printf '\033[1;33m➡️  Next:\033[0m run ./02.installing-k8s-and-tools.sh\n'
