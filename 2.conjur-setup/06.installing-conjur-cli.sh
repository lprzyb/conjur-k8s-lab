#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
curl -s -Lo /usr/local/bin/conjur https://github.com/cyberark/conjur-cli-go/releases/latest/download/conjur_linux_amd64
chmod 755 /usr/local/bin/conjur
conjur init self-hosted -u https://$CONJUR_LEADER_HOST -a $LAB_CONJUR_ACCOUNT -s
conjur login -i admin
set +x
conjur whoami
