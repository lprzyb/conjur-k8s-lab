#!/bin/bash
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./yaml/conjur-eso-jwt-policy.yaml -b root

conjur variable set -i test/host2/host -v $DB_HOST
conjur variable set -i test/host2/user -v $DB_USER
conjur variable set -i test/host2/pass -v $DB_PASSWORD

set +x
