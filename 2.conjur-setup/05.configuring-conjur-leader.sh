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
RC=$?
set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m Conjur Leader configured - browse https://%s/\n' "$CONJUR_IP"
    printf '\033[1;33m➡️  Next:\033[0m run ./06.installing-conjur-cli.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m evoke configure %s failed (exit %s) - run "podman logs %s" to see why.\n' "$serverType" "$RC" "$leaderContainer"
fi
