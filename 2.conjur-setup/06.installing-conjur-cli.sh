#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
curl -s -Lo /usr/bin/conjur https://github.com/cyberark/conjur-cli-go/releases/latest/download/conjur_linux_amd64
CURL_RC=$?
chmod 755 /usr/bin/conjur
conjur init self-hosted -u https://$CONJUR_LEADER_HOST -a $LAB_CONJUR_ACCOUNT -s
conjur login -i admin
LOGIN_RC=$?
set +x
conjur whoami
WHOAMI_RC=$?
if [ $CURL_RC -eq 0 ] && [ $LOGIN_RC -eq 0 ] && [ $WHOAMI_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m Conjur CLI installed and logged in.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./07.loading-demo-data.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m Conjur CLI install/login failed - check the output above.\n'
fi
