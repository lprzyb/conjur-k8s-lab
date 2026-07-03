#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

set -x
conjur -d policy load -f ./policies/root-policy.yaml -b root
RC1=$?
conjur -d policy load -f ./policies/demo-data.yaml -b root
RC2=$?
conjur variable set -i test/CityApp/DBAccount/address -v $DB_HOST
RC3=$?
conjur variable set -i test/CityApp/DBAccount/username -v $DB_USER
RC4=$?
conjur variable set -i test/CityApp/DBAccount/password -v $DB_PASSWORD
RC5=$?
set +x
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ] && [ $RC3 -eq 0 ] && [ $RC4 -eq 0 ] && [ $RC5 -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m demo data loaded into Secrets Manager.\n'
    printf '\033[1;33m➡️  Next:\033[0m run ./08.enable-k8s-jwt-authenticator.sh\n'
else
    printf '\033[1;31m❌ Failed:\033[0m demo data load failed - check the output above.\n'
fi

