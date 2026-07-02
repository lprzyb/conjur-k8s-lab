#/bin/sh
source 00.config.sh

if [[ "$READY" != true ]]; then
    echo "Your configuration are not ready. Set READY=true in 00.config.sh when you are done"
    exit
fi

# Deliberately only updates test/host1/pass, not test/host2/pass - this is
# the demo story: cityapp-conjurtok8sfile, cityapp-conjurtok8ssecret,
# cityapp-springboot-sidecar, cityapp-springboot-native and cityapp-csi all
# read test/host1/* and keep working (live, or after a redeploy - see
# README.md PART IV for exactly which apps need which). cityapp-eso reads
# the separate test/host2/* copy (see
# 5.conjur-eso/01.adding-conjur-eso-policy.sh) and is intentionally left
# behind here, right alongside cityapp-hardcode which never talks to Conjur
# at all - both go stale, everything else survives the rotation.

# The full "watch it rotate" story only makes sense once all 7 demo
# variants are actually deployed - warn and confirm if some are missing,
# rather than silently rotating against a partial lab.
DEMO_DEPLOYMENTS="cityapp:cityapp-hardcode cityapp:cityapp-conjurtok8sfile cityapp:cityapp-conjurtok8ssecret cityapp:cityapp-springboot-sidecar cityapp:cityapp-springboot-native external-secrets:cityapp-eso cityapp:cityapp-csi"
FOUND_COUNT=0
MISSING=""
for entry in $DEMO_DEPLOYMENTS; do
    ns=${entry%%:*}
    name=${entry#*:}
    if kubectl -n $ns get deployment $name >/dev/null 2>&1; then
        FOUND_COUNT=$((FOUND_COUNT + 1))
    else
        MISSING="$MISSING $name"
    fi
done

if [ $FOUND_COUNT -lt 7 ]; then
    printf '\033[1;33m⚠️  Warning:\033[0m only %s/7 cityapp demo deployments found. Missing:%s\n' "$FOUND_COUNT" "$MISSING"
    printf 'Rotating now means those missing variants will not be part of the "watch it rotate" comparison until you deploy them. Rotate anyway? [y/N] '
    read CONFIRM
    case "$CONFIRM" in
        y|Y|yes|YES) ;;
        *) echo "Aborted - no changes made."; exit 0 ;;
    esac
fi

NEW_PASSWORD=$(openssl rand -base64 18 | tr -d '=+/')

set -x
podman exec mysqldb mysql -uroot -p$DB_ROOT_PASSWORD -e "ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$NEW_PASSWORD'; FLUSH PRIVILEGES;"
MYSQL_RC=$?

conjur variable set -i test/host1/pass -v "$NEW_PASSWORD"
HOST1_RC=$?

set +x
if [ $MYSQL_RC -eq 0 ] && [ $HOST1_RC -eq 0 ]; then
    printf '\033[1;32m✅ Done:\033[0m %s password rotated in MySQL and updated in Conjur (test/host1/pass only - test/host2/pass left untouched on purpose).\n' "$DB_USER"
    printf '\033[1;33m➡️  Next:\033[0m cityapp-conjurtok8sfile and cityapp-conjurtok8ssecret refresh live within their secrets-refresh-interval, no redeploy needed. cityapp-springboot-sidecar (secret wired up as an env var, frozen at pod start), cityapp-springboot-native (fetches once via the Conjur SDK at startup) and cityapp-csi (rotation is not enabled on this lab'"'"'s CSI driver install) all need a redeploy to pick it up. cityapp-hardcode and cityapp-eso are now both stuck on the old password: hardcode because it never talks to Conjur at all, eso because it reads test/host2/* which this script left alone - a live illustration of what rotation actually costs you with each method.\n'
else
    printf '\033[1;31m❌ Failed:\033[0m password rotation failed partway through - check the output above. MySQL and Conjur may now be out of sync; do not leave it in this state, re-run once you have fixed the cause.\n'
fi
