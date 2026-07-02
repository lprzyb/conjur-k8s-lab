#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
FOLLOWER_HOSTNAME=follower.conjur.svc.cluster.local
FOLLOWER_CLUSTERIP=$(kubectl -n conjur get svc follower -o jsonpath='{.spec.clusterIP}')

if [ -n "$FOLLOWER_CLUSTERIP" ]; then
    podman exec $node_name sh -c "sed -i '/$FOLLOWER_HOSTNAME/d' /etc/hosts; echo '$FOLLOWER_CLUSTERIP $FOLLOWER_HOSTNAME' >> /etc/hosts"
fi

HTTP_CODE=$(podman exec $node_name curl -sk -m 5 -o /dev/null -w '%{http_code}' https://$FOLLOWER_HOSTNAME/health)

set +x
if [ -n "$FOLLOWER_CLUSTERIP" ] && [ "$HTTP_CODE" = "200" ]; then
    printf '\033[1;32m✅ Done:\033[0m Leader can now reach the Follower health API - refresh Settings > Conjur Cluster in the Leader GUI.\n'
    printf '\033[1;33m➡️  Next:\033[0m cd ../3.cityapp-setup and review 00.config.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m Leader still cannot reach the Follower health API (ClusterIP=%s, http_code=%s) - check the output above.\n' "$FOLLOWER_CLUSTERIP" "$HTTP_CODE"
fi
