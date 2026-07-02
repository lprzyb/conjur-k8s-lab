#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
yum -y install podman jq
sudo systemctl enable podman-restart.service
sudo systemctl start podman-restart.service
RC=$?

set +x
if [ $RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m podman installed.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./02.running-mysql-db.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m podman install/enable failed (exit %s) - check the output above.\n' "$RC"
fi
