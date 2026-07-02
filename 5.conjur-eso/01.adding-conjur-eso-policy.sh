#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./yaml/conjur-eso-jwt-policy.yaml -b root
RC1=$?

conjur variable set -i test/host2/host -v $DB_HOST
RC2=$?
conjur variable set -i test/host2/user -v $DB_USER
RC3=$?
conjur variable set -i test/host2/pass -v $DB_PASSWORD
RC4=$?

set +x
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ] && [ $RC3 -eq 0 ] && [ $RC4 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m ESO JWT policy loaded and test/host2/* set in Secrets Manager.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./02.creating-ext-secret-store.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m ESO policy load or variable set failed - check the output above.\n'
fi
