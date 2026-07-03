#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./yaml/conjur-summon-jwt-policy.yaml -b root
RC1=$?
set +x

if [ $RC1 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m cityapp-summon host loaded into Secrets Manager, granted read/execute on test/CityApp/DBAccount/*.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./02.building-cityapp-summon-image.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m policy load failed - check the output above.\n'
fi
