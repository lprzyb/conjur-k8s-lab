#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./policies/root-policy.yaml -b root
conjur -d policy load -f ./policies/demo-data.yaml -b root
conjur variable set -i test/host1/host -v $DB_HOST
conjur variable set -i test/host1/user -v $DB_USER
conjur variable set -i test/host1/pass -v $DB_PASSWORD
set +x
printf '\033[1;32m✅ Done:\033[0m demo data loaded into Conjur.\n'
printf '\033[1;33m➡️  Next:\033[0m run ./08.enable-k8s-jwt-authenticator.sh\n'

