#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
leaderContainer=$node_name
serverType="leader"
leaderDNS="$CONJUR_LEADER_HOST"
clusterDNS="$CONJUR_LEADER_HOST"
standby1DNS="$node_name.$LAB_DOMAIN"
adminPass=$LAB_CONJUR_ADMIN_PW
accountName=$LAB_CONJUR_ACCOUNT
podman exec $leaderContainer evoke configure $serverType \
    --accept-eula -h $leaderDNS \
    --leader-altnames "$clusterDNS,$standby1DNS" \
    -p $adminPass $accountName
set +x
printf '\033[1;32m✅ Done:\033[0m Conjur Leader configured - browse https://%s/\n' "$CONJUR_IP"
printf '\033[1;33m➡️  Next:\033[0m run ./06.installing-conjur-cli.sh\n'
