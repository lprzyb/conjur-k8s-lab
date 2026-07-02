#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

# Deliberately only updates test/host1/pass, not test/host2/pass - this is
# the demo story: cityapp-conjurtok8sfile, cityapp-conjurtok8ssecret,
# cityapp-springboot-sidecar, cityapp-springboot-native and cityapp-csi all
# read test/host1/* and keep working (live or after redeploy, depending on
# the method). cityapp-eso reads the separate test/host2/* copy (see
# 5.conjur-eso/01.adding-conjur-eso-policy.sh) and is intentionally left
# behind here, right alongside cityapp-hardcode which never talks to Conjur
# at all - both go stale, everything else survives the rotation.
NEW_PASSWORD=$(openssl rand -base64 18 | tr -d '=+/')

set -x
podman exec mysqldb mysql -uroot -p$DB_ROOT_PASSWORD -e "ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$NEW_PASSWORD'; FLUSH PRIVILEGES;"
MYSQL_RC=$?

conjur variable set -i test/host1/pass -v "$NEW_PASSWORD"
HOST1_RC=$?

set +x
if [ $MYSQL_RC -eq 0 ] && [ $HOST1_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m %s password rotated in MySQL and updated in Conjur (test/host1/pass only - test/host2/pass left untouched on purpose).\n' "$DB_USER"
    printf '\033[1;33m➡️  Next:\033[0m cityapp-conjurtok8ssecret and cityapp-csi refresh live and will pick up the new password on their own. cityapp-conjurtok8sfile, cityapp-springboot-sidecar and cityapp-springboot-native only fetch the secret at pod startup - redeploy those to pick it up. cityapp-hardcode and cityapp-eso are now both stuck on the old password: hardcode because it never talks to Conjur at all, eso because it reads test/host2/* which this script left alone - a live illustration of what rotation actually costs you with the methods that are not Conjur-integrated, or are pointed at the wrong variable.\n'
else
    printf '\033[1;31m❌ Failed:\033[0m password rotation failed partway through - check the output above. MySQL and Conjur may now be out of sync; do not leave it in this state, re-run once you have fixed the cause.\n'
fi
