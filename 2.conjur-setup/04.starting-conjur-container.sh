#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

log_dir=/var/log/conjur/$node_name
set -x
mkdir -p $log_dir
podman stop $node_name
podman container rm $(podman ps -a | grep $node_name | awk '{print $1}')
podman run --name $node_name \
  -d --restart=always \
  -p "443:443" -p "636:636" -p "5432:5432" -p "1999:1999" \
  --security-opt seccomp:unconfined \
  --cap-add AUDIT_WRITE \
  -v $log_dir:/var/log/conjur/:Z \
  --log-driver json-file \
  --log-opt max-size=1000m \
  --log-opt max-file=3 \
  registry.tld/conjur-appliance:$conjur_version
RUN_RC=$?

grep -q "$CONJUR_LEADER_HOST" /etc/hosts || echo "$CONJUR_IP conjur1.$LAB_DOMAIN $CONJUR_LEADER_HOST" >> /etc/hosts

#Give the container a few seconds to crash-loop if it's going to (e.g. missing capabilities)
sleep 5
podman ps --filter name=$node_name --filter status=running -q | grep -q .
RUNNING_RC=$?

set +x
if [ $RUN_RC -eq 0 ] && [ $RUNNING_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m Conjur container started.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./05.configuring-conjur-leader.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m Conjur container is not running - run "podman logs %s" to see why.\n' "$node_name"
fi
